classdef R2AEA < ALGORITHM
% <multi> <real/integer> <large/none><expensive>
% R2AEA算法：回归与关系辅助的进化算法
% 用于解决高维昂贵多目标优化问题
%
% 参数说明：
% wD       --- 10 --- 权重优化中DE的种群规模（用于第一阶段RWO）
% tr       --- 0.5--- 两阶段切换阈值（占总评估预算的比例）
% operator ---  1 --- 原始进化算子类型：1=GA（遗传算法），2=DE（差分进化）
% k        ---  6 --- 参考解的数量（用于第二阶段RMO）
% gmax     ---300 --- 使用代理模型的最大评估次数

% 参考文献：
% Zhu S, Zhang Y, Fang W, et al. Regression and relation-assisted evolutionary algorithm for high-dimensional
% expensive multi-objective optimization[J]. Swarm and Evolutionary Computation, 2025, 97: 101978.

%------------------------------- Copyright --------------------------------
% Copyright (c) 2023 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------
    methods
        function main(Algorithm,Problem)
            %% ==================== 第一部分：参数设置 ====================
            % Algorithm.ParameterSet()：获取算法参数，如果用户未指定则使用默认值
            % 参数顺序：wD, tr, Operator, k, gmax
            [wD,tr,Operator,k,gmax] = Algorithm.ParameterSet(10,0.5,2,6,300);

            % SubN：子种群大小，用于DE进化过程中的种群规模
            SubN=5;

            % Problem.Initialization()：初始化种群，随机生成Problem.N个个体
            % Population：当前种群，包含多个个体（解）
            Population = Problem.Initialization();

            % G：第一阶段RWO中DE进化的代数计算
            % ceil()：向上取整函数
            % Problem.maxFE：最大函数评估次数
            % 0.05：使用5%的评估预算用于DE进化
            G = ceil(Problem.maxFE*0.05/(SubN*2*wD));

            % A：存档（Archive），用于存储所有已评估的非支配解
            A = Population;

            %% ==================== 第二部分：第一阶段RWO优化 ====================
            % 第一阶段：回归辅助的径向权重优化（RWO）
            % 时间范围：从开始到评估次数达到总预算的tr比例（默认50%）
            % 核心思想：使用RBF代理模型，在目标空间中沿径向方向搜索

            % while循环：当评估次数FE < tr*maxFE时持续执行
            while Problem.FE < tr*Problem.maxFE
                % Algorithm.NotTerminated(A)：检查算法是否应该终止
                % 同时更新算法状态（如评估次数等）
                Algorithm.NotTerminated(A);

                % RWO函数：执行第一阶段的径向权重优化
                % 返回值：
                %   Archive - 本轮RWO产生的非支配解
                %   A - 更新后的存档（包含所有历史解）
                % 参数：
                %   Algorithm - 算法对象
                %   Problem - 问题对象
                %   30 - DE进化的代数
                %   Population - 当前种群
                %   wD - 权重优化中DE的种群规模
                %   SubN - 子种群大小
                %   A - 当前存档
                [Archive,A] = RWO(Algorithm,Problem,30,Population,wD,SubN,A);

                % EnvironmentalSelection：环境选择算子
                % 从当前种群和新产生的存档中选出50个个体作为下一代种群
                % 使用非支配排序+拥挤距离选择策略
                Population = EnvironmentalSelection([Population,Archive],50);
            end

            %% ==================== 第三部分：第二阶段RMO优化 ====================
            % 第二阶段：关系辅助的进化优化（RMO）
            % 时间范围：从评估次数达到tr*maxFE到评估预算用尽
            % 核心思想：训练关系分类模型，学习解对之间的优劣关系

            % UniformPoint：生成均匀分布的参考点
            % Z：参考方向矩阵，大小为 Problem.N x Problem.M
            % Problem.N：种群大小，Problem.M：目标数量
            [Z,~] = UniformPoint(Problem.N,Problem.M);

            % while循环：Algorithm.NotTerminated(A) 持续运行直到评估预算用尽
            while Algorithm.NotTerminated(A)

                %% ========== 步骤1：选择参考解 ==========
                % Zmin：当前存档中所有目标的最小值，用于归一化
                % min(A.objs,[],1)：对存档的目标值矩阵按列取最小值
                % A.objs：存档中所有个体的目标值矩阵，大小为 N x M
                Zmin = min(A.objs,[],1);

                % Refselect：从存档A中选择k个参考解
                % 基于NSGA-III的参考点关联机制选择
                % 返回值Ref：包含k个参考解的种群
                Ref = Refselect(A,k,Z,Zmin);

                %% ========== 步骤2：生成训练数据 ==========
                % Input：当前种群的决策变量（解的坐标）
                % Population.decs：获取种群中所有个体的决策变量
                % 大小为 N x D，N是个体数，D是变量维度
                Input = Population.decs;

                % GetOutput_PBI：基于PBI函数对种群进行分类
                % 返回值Catalog：分类标签，1=好解（在前沿区域内），0/-1=差解
                % Population.objs：当前种群的目标值
                % Ref.objs：参考解的目标值
                Catalog = GetOutput_PBI(Population.objs,Ref.objs);

                % GetRelationPairs：生成关系对训练数据
                % 将解对按照优劣关系分为4类：
                %   C1-C1（好-好）：标签=0
                %   C2-C2（差-差）：标签=0
                %   C1-C2（好-差）：标签=1
                %   C2-C1（差-好）：标签=-1
                % XXs：关系对的决策变量，每行是两个解的拼接 [x_i, x_j]
                % YYs：关系对的标签（0, 1, -1）
                [XXs,YYs] = GetRelationPairs(Input,Catalog);

                % DataProcess：将数据划分为训练集和测试集
                % 按1:3比例划分，保证各类别平衡
                % TrainIn/TrainOut：训练集输入和输出
                % TestIn/TestOut：测试集输入和输出
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);

                % xDim：训练数据的维度（2*D，因为是两个解的拼接）
                xDim = size(TrainIn,2);

                %% ========== 步骤3：训练关系分类神经网络 ==========
                % mapminmax：数据归一化函数，将数据映射到[-1,1]区间
                % TrainIn'：转置，因为mapminmax按行处理
                % TrainIn_nor：归一化后的训练输入
                % TrainIn_struct：归一化结构，用于后续对新数据应用相同的归一化
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';  % 转置回来

                % onehotconv：将标签转换为one-hot编码
                % 参数1：标签向量，参数2：1=编码模式
                % 例如：标签1 -> [1,0,0]，标签0 -> [0,1,0]，标签-1 -> [0,0,1]
                TrainOut_onehot = onehotconv(TrainOut,1);

                % patternnet：创建前馈神经网络（模式识别网络）
                % 网络结构：三层隐藏层，神经元数分别为 1.5*D, D, D/2
                % ceil()：向上取整
                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);

                % net.trainParam.showWindow = 0：关闭训练过程的图形窗口显示
                net.trainParam.showWindow = 0;

                % train()：训练神经网络
                % 输入：TrainIn_nor'（归一化后的训练输入）
                % 输出：TrainOut_onehot'（one-hot编码的训练输出）
                net = train(net,TrainIn_nor',TrainOut_onehot');

                % Smodel：存储训练好的关系模型
                % Smodel.X：原始决策变量（用于后续生成关系对）
                % Smodel.Y：分类标签（1=好解，0/-1=差解）
                % Smodel.mp_struct：归一化结构（用于对新数据归一化）
                % Smodel.net：训练好的神经网络
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;

                %% ========== 步骤4：关系模型引导选择 ==========
                % RMOselect：使用关系模型选择高质量的解
                % 参数：
                %   Problem - 问题对象
                %   Ref - 参考解
                %   Population.decs - 当前种群的决策变量
                %   gmax - 代理模型最大评估次数
                %   Smodel - 训练好的关系模型
                % 返回值Next：选出的高质量解的决策变量
                Next = RMOselect(Problem,Ref,Population.decs,gmax,Smodel);

                %% ========== 步骤5：评估新解并更新种群 ==========
                % 如果选出了新解，则进行真实函数评估
                if ~isempty(Next)
                    % Problem.Evaluation(Next)：对新解进行真实函数评估
                    % 将评估后的新解加入存档A
                    A = [A,Problem.Evaluation(Next)];
                end

                % EnvironmentalSelection3：NSGA-III风格的环境选择
                % 使用参考点关联机制选择下一代种群
                % 保证解在各参考方向上的均匀分布
                Population = EnvironmentalSelection3(A,Problem.N,Z,Zmin);
            end
        end
    end
end