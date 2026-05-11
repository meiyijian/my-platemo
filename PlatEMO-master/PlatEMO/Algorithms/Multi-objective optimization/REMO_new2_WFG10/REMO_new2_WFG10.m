classdef REMO_new2_WFG10 < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_new2 的变体，专门针对 10 目标 WFG 问题调优。
%
% 本变体保留了 REMO_new2 的混合 PBI 分类框架，并添加了三个保守改进：
% 1. 置信度加权的关系对训练（让高置信度样本对模型影响更大）
% 2. 自适应参考解数量（根据目标维度动态调整）
% 3. 不确定性/多样性感知的候选解选择（避免候选解聚集）

    methods
        function main(Algorithm,Problem)
            %% ============ 参数设置 ============
            % k: 参考解数量（用于 HPC 内部的 RefSelect）
            % gmax: 代理辅助 GA 内循环的累计样本上限
            % q_keep: 候选解筛选的分位数阈值（保留得分前 q_keep 比例的候选）
            % lambda0: 不确定性权重的基础系数
            % w_min: 样本权重的下限（防止权重过小导致训练不稳定）
            % n_min: 每轮真实评估的最少候选解数量
            % n_max: 每轮真实评估的最多候选解数量
            [k,gmax,q_keep,lambda0,w_min,n_min,n_max] = ...
                Algorithm.ParameterSet(6,3000,0.80,0.35,0.30,4,6);

            %% ============ 初始化种群 ============
            % 根据决策变量维度 D 确定种群规模 N
            % D <= 10 时用 11D-1（经验公式），否则固定为 100
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            % 拉丁超立方采样生成初始解（保证空间均匀覆盖）
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            % 将 [0,1] 映射到实际决策空间，然后真实评估
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            % Archive 累积所有真实评估过的解（最终输出）
            Archive    = Population;

            %% ============ 主优化循环 ============
            while Algorithm.NotTerminated(Archive)
                % 进化比例 = 已评估次数 / 总预算（0~1）
                % 用于 HPC 中自适应权重 alpha 的计算
                ratio = Problem.FE / Problem.maxFE;

                % 自适应参考解数量：
                % 取 k 和 1.5*M 中的较大者，但不超过种群规模
                % 高维目标需要更多参考解来覆盖 Pareto 前沿
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));

                %% ---- 混合 PBI 分类（来自 REMO_new2） ----
                % 对种群中的解进行好坏分类，同时输出置信度和参考解
                % 'Nref': 参考向量数量, 'k': 参考解数量, 'theta': PBI 惩罚系数
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                %% ---- 置信度加权的关系对训练 ----
                % 获取决策变量
                Input = Population.decs;
                % 生成关系对样本，同时返回每对的权重 WWs
                % 权重 = 两端解置信度的几何平均，体现"两端都确定则这对关系更可靠"
                [XXs,YYs,WWs] = GetRelationPairs_confidence(Input,Catalog,confidence);

                % 如果关系对为空（极端情况），跳过本轮
                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    continue;
                end

                % 按类别分层划分训练集/测试集（3:1），同时划分权重
                [TrainIn,TrainOut,TrainW,TestIn,TestOut,~] = ...
                    DataProcess_confidence(XXs,YYs,WWs);
                % 输入维度 = 2D（两个解的决策变量拼接）
                xDim = size(TrainIn,2);

                % 归一化输入到 [-1,1]（mapminmax 按行处理，所以先转置）
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor     = TrainIn_nor';
                % 将标签 {-1,0,1} 转为 one-hot 编码 [0,0,1]/[0,1,0]/[1,0,0]
                TrainOut_onehot = onehotconv(TrainOut,1);

                %% ---- 训练神经网络 ----
                % 三层前馈网络，节点数依次为 1.5*xDim, xDim, 0.5*xDim
                % patternnet 带 softmax 输出，适合多分类
                net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
                net.trainParam.showWindow = 0;  % 不弹出训练窗口

                % 计算样本权重 EW（归一化后下限截断）
                EW = TrainW(:)';
                if mean(EW) > 1e-12
                    EW = EW ./ mean(EW);  % 归一化使均值为 1
                else
                    EW = ones(size(EW));  % 防御：权重全为 0 时退化为等权
                end
                EW = max(EW,w_min);  % 下限截断，防止极小权重导致训练不稳定
                % train 函数的第 6 个参数是样本权重
                net = train(net,TrainIn_nor',TrainOut_onehot',[],[],EW);

                %% ---- 测试集评估 ----
                if isempty(TestIn)
                    p_err = 1;  % 无测试集时假设误差最大
                else
                    % 用训练集的归一化参数变换测试集
                    TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                    % 网络预测，onehotconv 模式 2 将概率转回标签
                    TestPre    = onehotconv(net(TestIn_nor')',2);
                    % 分类错误率
                    p_err      = sum(TestPre ~= TestOut)/size(TestPre,1);
                end

                %% ---- 构建代理模型结构体 ----
                % 传递给 RSurrogateAssistedSelection 使用
                Smodel.X         = Input;          % 训练数据的决策变量
                Smodel.Y         = Catalog;        % 好/坏标签
                Smodel.mp_struct = TrainIn_struct; % 归一化参数（预测时复用）
                Smodel.net       = net;            % 训练好的神经网络
                Smodel.p_err     = p_err;          % 测试集分类错误率
                Smodel.lambda0   = lambda0;        % 不确定性权重基础系数
                Smodel.ratio     = ratio;          % 当前进化比例

                %% ---- 代理模型辅助选择 ----
                % 在代理模型指导下，通过 GA 内循环筛选候选解
                % q_keep: 分位数阈值, n_min/n_max: 每轮评估数量上下限
                Next = RSurrogateAssistedSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel,q_keep,n_min,n_max);

                % 如果代理选择失败（Next 为空），用 GA 生成备选候选
                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs],{1,15,1,5});
                    Next = Next(1:min(n_min,size(Next,1)),:);
                end
                %% ---- 真实评估候选解 ----
                if ~isempty(Next) && remain > 0
                    % 截断到剩余预算内
                    Next = Next(1:min(size(Next,1),remain),:);
                    % 真实评估并加入 Archive
                    Archive = [Archive,Problem.Evaluation(Next)];
                end

                %% ---- 环境选择 ----
                % 从 Archive 中选择 N 个解作为下一代种群
                % 使用 RSEA 的雷达网格策略
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end