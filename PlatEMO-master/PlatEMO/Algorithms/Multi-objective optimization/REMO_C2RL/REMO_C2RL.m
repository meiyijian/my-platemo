classdef REMO_C2RL < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_C2RL: Confidence-aware Curriculum Relation Learning
% k        ---     6  --- 参考解数量
% gmax     ---  3000  --- 代理评估上限
% tau_err  ---  0.30  --- 课程切换阈值（p_err < tau_err 时切到阶段 2）
% lambda0  ---  0.50  --- UCB 初始权重（lambda = lambda0*(1-ratio)）
% q_keep   ---  0.70  --- 末尾筛选分位数
%
%------------------------------- 设计要点 ---------------------------------
%   在 REMO_new2（HybridPBI 分类 + 关系学习 + RefSelect）的基础上，
%   针对 M ≥ 5 时关系学习的三大痛点引入三个一体化创新：
%
%   ① 课程化训练（Curriculum Learning）
%      - 阶段 1：只用 top-25% 与决策空间最远 25% 构造极端关系对
%      - 阶段 2：恢复使用全部解（与 REMO_new2 一致）
%      - 切换由上一代 p_err 自适应判断，避免硬编码节奏
%
%   ② 置信度感知聚合（Confidence-aware Aggregation）
%      - patternnet softmax max prob 作为天然置信度信号
%      - C_SCORE 聚合改为置信度加权平均（替代简单算术平均）
%      - 零额外计算开销（softmax 是 patternnet 原生输出）
%
%   ③ UCB 探索 + 分位数阈值（Uncertainty-aware Selection）
%      - 末尾打分：score_aug = score + lambda * uncertainty
%      - lambda = lambda0 * (1 - ratio)，早探索后利用
%      - 阈值由死值 ">3.9" 改为 quantile(0.7) 自适应分位数
%
%------------------------------- 与已有版本对比 ---------------------------
%   REMO_new2          : 基础关系学习 + HybridPBI
%   REMO_new2_PIEA3    : 加 PIEA 性能指标体系（搬运较多，故事性弱）
%   REMO_C2RL（本算法）: 课程化 + 置信度 + UCB（自洽故事）
%
%------------------------------- 参考文献 ---------------------------------
% [1] H. Hao et al. REMO. IEEE TEVC, 2022, 26(5): 1157-1170.
% [2] Bengio et al. Curriculum Learning. ICML 2009.
% [3] Auer et al. UCB1. Machine Learning, 2002.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            warning off
            %% 参数设置
            [k, gmax, tau_err, lambda0, q_keep] = ...
                Algorithm.ParameterSet(6, 3000, 0.30, 0.50, 0.70);

            %% 拉丁超立方初始化（与 REMO_new2 一致）
            if Problem.D <= 10
                N = 11 * Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper - Problem.lower, N, 1) .* PopDec ...
                + repmat(Problem.lower, N, 1));
            Archive    = Population;

            %% 课程阶段状态变量
            stage      = 1;     % 初始阶段：1 = 易（极端对）, 2 = 难（全部对）
            p_err_prev = 1.0;   % 第一代默认 p_err 高 → 强制走阶段 1

            %% 主优化循环
            while Algorithm.NotTerminated(Archive)
                ratio = Problem.FE / Problem.maxFE;

                %% Step 1: HPC 混合分类（保留 REMO_new2 核心创新）
                [~, ~, Catalog, ~, Ref] = HybridPBI_Classification( ...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);

                %% Step 2: 课程阶段切换（基于上一代 p_err 自适应）
                if p_err_prev <= tau_err
                    stage = 2;     % 模型已学懂简单样本，挑战难样本
                else
                    stage = 1;     % 继续在简单样本上巩固
                end

                %% Step 3: 课程化关系对构造
                Input = Population.decs;
                [XXs, YYs] = GetRelationPairs_Curriculum(Input, Catalog, stage);

                if isempty(XXs)
                    % 兜底：关系对为空时跳过本代
                    Population = RefSelect(Archive, Problem.N);
                    continue;
                end

                %% Step 4: 训练关系网络（patternnet 结构与 REMO_new2 一致）
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs);
                xDim = size(TrainIn, 2);

                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor      = TrainIn_nor';
                TrainOut_onehot  = onehotconv(TrainOut, 1);

                net = patternnet([ceil(xDim*1.5), xDim*1, ceil(xDim/2)]);
                net.trainParam.showWindow = 0;
                net = train(net, TrainIn_nor', TrainOut_onehot');

                TestIn_nor  = mapminmax('apply', TestIn', TrainIn_struct)';
                TestPre     = onehotconv(net(TestIn_nor')', 2);
                p_err       = sum(TestPre ~= TestOut) / size(TestPre, 1);
                p_err_prev  = p_err;     % 留给下一代做课程切换决策

                %% Step 5: 打包代理模型（含 UCB 所需的 lambda）
                Smodel = struct();
                Smodel.X         = Input;
                Smodel.Y         = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net       = net;
                Smodel.p_err     = p_err;
                Smodel.stage     = stage;
                Smodel.lambda    = lambda0 * (1 - ratio);     % UCB 衰减权重

                %% Step 6: 置信度感知聚合 + UCB 探索 + 分位数阈值
                Next = RSurrogateAssistedSelection_C2RL( ...
                    Problem, Ref, Population.decs, gmax, Smodel, q_keep);

                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                %% Step 7: 环境选择（保留 REMO_new2 的 RefSelect）
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
