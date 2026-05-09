classdef REMO < ALGORITHM
% <2022> <multi/many> <real> <expensive>
% Expensive multiobjective optimization by relation learning and prediction
% k    ---    6 --- Number of reference solutions（参考解的数量）
% gmax --- 3000 --- Number of solutions evaluated by surrogate model（代理模型评估的解的数量）

%------------------------------- Reference --------------------------------
% H. Hao, A. Zhou, H. Qian, and H. Zhang. Expensive multiobjective
% optimization by relation learning and prediction. IEEE Transactions on
% Evolutionary Computation, 2022, 26(5): 1157-1170.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Parameterr setting（参数设置）
            % k = 参考解的数量，gmax = 代理模型最多评估多少次新解
            [k,gmax] = Algorithm.ParameterSet(6,3000);

            %% Initalize the population by Latin hypercube sampling（拉丁超立方采样初始化种群）
            % 如果决策变量维度 <= 10，初始种群大小 = 11*维度 - 1，否则固定为100
            if Problem.D <= 10
                N = 11*Problem.D-1;
            else
                N = 100;
            end
            % Latin = 拉丁超立方采样（一种均匀的空间采样方法）
            % PopDec = 采样得到的决策变量（解的位置），范围在[0,1]之间
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            % 将[0,1]范围的样本映射到问题的真实变量范围 [lower, upper]
            % repmat 的作用是把上下界复制成 N 行，方便做矩阵加减法
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec+repmat(Problem.lower,N,1));
            % Archive = 存档，保存所有真实评估过的解
            Archive    = Population;

            %% Optimization（主优化循环）
            while Algorithm.NotTerminated(Archive)
                % Step 1: 选择参考解（参考解是种群中具有代表性的优秀解）
                Ref       = RefSelect(Population,k);
                % 获取当前种群所有解的决策变量（即它们的坐标位置）
                Input     = Population.decs;
                % 用PBI方法给每个解分类：与参考解相比"好"还是"不好"
                % Catalog = 1 表示好，Catalog ~= 1 表示不好
                Catalog   = GetOutput_PBI(Population.objs,Ref.objs);
                % Step 2: 构建关系对——把两个解配对，让模型学习它们之间的优劣关系
                % XXs = 所有配对（两个解拼接在一起），YYs = 这对的关系标签（1/0/-1）
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                % Step 3: 划分训练集和测试集（3/4训练，1/4测试）
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
                % 每个训练样本的特征维度（两个解的决策变量拼接，所以是2倍）
                xDim = size(TrainIn,2);

                % Step 4: 训练关系预测模型（神经网络）
                % mapminmax = 将数据归一化到[-1,1]范围，有利于神经网络训练
                % ' 是转置操作，因为mapminmax要求每列是一个样本
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor     = TrainIn_nor';
                % onehotconv = 将类别标签(1/0/-1)转换成"独热编码"(one-hot)
                % 例如：1 -> [1,0,0], 0 -> [0,1,0], -1 -> [0,0,1]
                % 神经网络更适合输出这种形式的编码
                TrainOut_onehot = onehotconv(TrainOut,1);
                % patternnet = MATLAB的神经网络分类器
                % [ceil(xDim*1.5), xDim*1, ceil(xDim/2)] 是三个隐藏层的神经元数量
                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
                net.trainParam.showWindow = 0;  % 不显示训练窗口
                net        = train(net,TrainIn_nor',TrainOut_onehot');
                % 用训练好的归一化参数"apply"到测试集上
                TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                % 用神经网络预测测试集，再把独热编码转回类别标签(1/0/-1)
                TestPre    = onehotconv(net(TestIn_nor')',2);
                % 计算测试集上的预测错误率
                p_err      = sum(TestPre ~= TestOut)/size(TestPre,1);

                % Step 5: 把训练好的模型打包成结构体 Smodel，供后续使用
                Smodel.X   = Input;       % 训练用的决策变量
                Smodel.Y   = Catalog;     % 训练用的类别标签
                Smodel.mp_struct = TrainIn_struct;  % 归一化参数（给新数据归一化用）
                Smodel.net       = net;    % 训练好的神经网络
                Smodel.p_err     = p_err;  % 预测错误率

                % Step 6: 用代理模型辅助生成新解（遗传算法+模型筛选）
                Next = RSurrogateAssistedSelection(Problem,Ref,Population.decs,gmax,Smodel);
                if ~isempty(Next)
                    % 对筛选出的新解进行真实的函数评估（这是昂贵的操作！）
                    Archive = [Archive,Problem.Evaluation(Next)];
                end
                % 从存档中重新选择 N 个个体作为下一代种群
                Population = RefSelect(Archive,Problem.N);
            end
        end
	end
end
