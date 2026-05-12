classdef REMO_new2_TrueSR < ALGORITHM
% <2025> <multi/many> <real> <expensive>
% REMO_new2_TrueSR：基于真实软成对排序的代理辅助多目标优化算法
%
% 算法名称由来：
%   REMO = Relation-based Evolutionary Multi-objective Optimization
%   new2 = 改进版本 2
%   TrueSR = True Soft Ranking（真实软排序）
%
% 算法核心思想：
%   1. 用"软排序对"替代传统的"硬分类标签"，让模型学习"解 A 比解 B 好多少"，
%      而不只是"解 A 好不好"
%   2. 用神经网络作为代理模型（surrogate model），预测任意两个解的相对优劣
%   3. 由于真实评估（调用目标函数）很昂贵，用训练好的神经网络来辅助选择
%      下一批要真实评估的解
%
% 算法流程概述：
%   ① 初始化种群 → 真实评估
%   ② 计算混合 PBI 分数（HybridPBI_Classification）
%   ③ 生成软排序训练对（GetSoftRelationPairsFromScore）
%   ④ 训练神经网络 → 学会预测"谁比谁好"
%   ⑤ 用神经网络做代理辅助选择（RSurrogateAssistedSelection_TrueSR）
%   ⑥ 真实评估选出的新解 → 更新种群 → 回到步骤②，循环直到评估资源用尽
%
% 算法参数：
%   k         ---  6    --- 参考解的数量（用于 PBI 分类）
%   gmax      --- 3000  --- 每代代理辅助搜索的最大尝试次数
%   pairMax   --- 12000 --- 训练配对的最大数量（控制训练数据规模）
%   alphaSoft ---  6    --- Sigmoid 函数的陡峭系数（alpha 越大，输出越接近 0/1）
%   anchorNum ---  20   --- 模型选择时的锚点数量

    methods
        function main(Algorithm, Problem)
            %% ========== 步骤1：参数设置 ==========
            % ParameterSet 会检查用户是否在调用时覆写了参数值
            % 如果没覆写，使用括号中的默认值
            [k, gmax, pairMax, alphaSoft, anchorNum] = Algorithm.ParameterSet(6, 3000, 12000, 6, 20);

            %% ========== 步骤2：初始化种群 ==========
            % 种群大小 N 根据决策变量维度 D 自动确定
            if Problem.D <= 10
                % 低维问题（D ≤ 10）：N = 11*D - 1
                % 例如 D=5 → N=54，D=10 → N=109
                N = 11 * Problem.D - 1;
            else
                % 高维问题（D > 10）：固定 N = 100
                N = 100;
            end

            % 用拉丁超立方采样生成初始决策向量（保证均匀覆盖搜索空间）
            % UniformPoint 生成 [0,1] 范围的采样点
            PopDec = UniformPoint(N, Problem.D, 'Latin');

            % 将 [0,1] 的采样点映射到实际的搜索空间
            % 公式：采样点 × (上界-下界) + 下界
            % 例如：搜索空间 [-5, 5]，采样点 0.3 → 0.3*(5-(-5))+(-5) = -2
            Population = Problem.Evaluation(...
                repmat(Problem.upper - Problem.lower, N, 1) .* PopDec + ...
                repmat(Problem.lower, N, 1));

            % Archive（归档集）：保存所有被真实评估过的解
            % 初始时 Archive = Population（第一次评估的所有解）
            Archive = Population;

            %% ========== 步骤3：主优化循环 ==========
            % NotTerminated 检查：评估次数是否用完？
            % 如果条件满足（还有剩余评估次数），继续循环
            while Algorithm.NotTerminated(Archive)

                % ratio：进化进度，0（刚开始）→ 1（评估次数用完）
                % 用于控制探索-收敛的平衡
                ratio = Problem.FE / Problem.maxFE;

                %% ========== 步骤3.1：计算混合 PBI 分数 ==========
                % 这是整个算法的关键步骤：
                %   scoreHybrid 是一个连续分数，表示每个解的优劣程度
                %   分数越高 → 解越好
                %
                % HybridPBI_Classification 内部做了三件事：
                %   ① 用参考向量计算 PBI 连续分数（score_v）
                %   ② 用参考点做自适应分类得到二值标签（label_dyn）
                %   ③ 将两者按进化进度加权混合得到 scoreHybrid
                [~, ~, ~, ~, Ref, scoreHybrid] = HybridPBI_Classification(...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);

                % 提取当前种群中所有解的决策变量矩阵
                Input = Population.decs;

                %% ========== 步骤3.2：生成软排序训练对 ==========
                % 将 scoreHybrid 分数转化为"解 i vs 解 j 的成对比较数据"
                %
                % XXs：每行是 [解i的特征, 解j的特征]，即把两个解的输入拼接
                % Ps ：每行是 P(i 比 j 好) 的概率值（0~1 之间的连续值）
                %
                % Sigmoid 函数：P = 1/(1+exp(-alpha*(score_i - score_j)))
                %   - 当 score_i 远大于 score_j → P ≈ 1（i 确实更好）
                %   - 当 score_i 远小于 score_j → P ≈ 0（j 更好）
                %   - 当两者接近 → P ≈ 0.5（差不多，不确定）
                [XXs, Ps] = GetSoftRelationPairsFromScore(Input, scoreHybrid, ...
                    'Alpha', alphaSoft, 'MaxPairs', pairMax);

                %% ========== 步骤3.3：划分训练集和测试集 ==========
                % 75% 的数据用于训练神经网络，25% 用于验证泛化能力
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcessSoft(XXs, Ps, 0.75);
                xDim = size(TrainIn, 2);  % 输入维度 = 2 × 决策变量数（拼接了两个解）

                %% ========== 步骤3.4：数据归一化 ==========
                % mapminmax 将数据缩放到 [-1, 1] 或用户指定范围
                % 这能加速神经网络训练并提高数值稳定性
                %   TrainInNor：归一化后的训练输入
                %   TrainInStruct：归一化的结构信息（保存了映射参数，测试时复用）
                [TrainInNor, TrainInStruct] = mapminmax(TrainIn');
                TrainInNor = TrainInNor';

                %% ========== 步骤3.5：构建和训练神经网络 ==========
                % 网络结构：输入层 → 隐藏层1 → 隐藏层2 → 隐藏层3 → 输出层
                %   - 隐藏层1：ceil(xDim*1.5) 个神经元（比输入略大，捕捉特征）
                %   - 隐藏层2：xDim 个神经元（与输入同维度，瓶颈层）
                %   - 隐藏层3：ceil(xDim/2)  个神经元（压缩层，逐步降维）
                net = feedforwardnet([ceil(xDim*1.5), xDim, ceil(xDim/2)]);

                % 输出层使用 logsig（对数 S 型函数），将输出限制在 (0, 1)
                % 因为我们要预测的是"概率值"，必须在 0~1 之间
                net.layers{end}.transferFcn = 'logsig';

                % trainscg：缩放共轭梯度法，收敛快，适合小批量数据
                net.trainFcn = 'trainscg';

                % 损失函数用 MSE（均方误差）：对概率值做回归
                net.performFcn = 'mse';

                % dividetrain：所有数据都用于训练（我们已经手动划分好了训练/测试集）
                net.divideFcn = 'dividetrain';

                % 关闭训练进度窗口（MATLAB 的 GUI 窗口），静默训练
                net.trainParam.showWindow = 0;

                % 训练神经网络
                %   TrainInNor' 是输入（转置为列优先格式）
                %   TrainOut'  是目标输出
                net = train(net, TrainInNor', TrainOut');

                %% ========== 步骤3.6：测试集评估 ==========
                if isempty(TestIn)
                    % 没有测试数据（样本太少），测试误差设为 NaN
                    pErr = NaN;
                else
                    % 用训练时的归一化参数对测试数据做同样的归一化
                    TestInNor = mapminmax('apply', TestIn', TrainInStruct)';
                    % 用训练好的网络对测试数据做预测
                    TestPred  = net(TestInNor')';
                    % 计算测试集的均方误差
                    pErr = mean((TestPred - TestOut).^2);
                end

                %% ========== 步骤3.7：封装代理模型 ==========
                % 将训练好的模型及其相关信息打包到一个结构体 Smodel 中
                Smodel.X         = Input;            % 种群决策变量
                Smodel.score     = scoreHybrid(:);   % 种群混合分数
                Smodel.mp_struct = TrainInStruct;    % 归一化映射参数（测试时需要复用）
                Smodel.net       = net;              % 训练好的神经网络
                Smodel.p_err     = pErr;             % 测试误差（用于诊断）
                Smodel.anchorNum = anchorNum;        % 锚点数量（模型选择时用）

                %% ========== 步骤3.8：代理辅助选择 ==========
                % 利用训练好的神经网络生成并筛选新的候选解
                % 神经网络负责"猜想"哪些解更好，省去昂贵的真实评估
                Next = RSurrogateAssistedSelection_TrueSR(Problem, Ref, Population.decs, gmax, Smodel);

                %% ========== 步骤3.9：真实评估新解并更新存档 ==========
                if ~isempty(Next)
                    % 对筛选出的候选解进行真实的昂贵评估
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                %% ========== 步骤3.10：环境选择，更新种群 ==========
                % 从归档集中选择 N 个最好的解作为下一代种群
                % 这保证了种群大小保持恒定
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
