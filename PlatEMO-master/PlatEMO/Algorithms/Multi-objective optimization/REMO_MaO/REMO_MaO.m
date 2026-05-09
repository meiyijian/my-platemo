classdef REMO_MaO < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Many-objective Relation-learning surrogate-assisted EA
% k    ---    6 --- 参考解数量
% gmax --- 3000 --- 代理模型评估上限
% K    ---    5 --- Dropout 集成网络数
%
%------------------------------- 设计要点 ---------------------------------
% 在 REMO_new2_clean 基础上的温和重构，针对超多目标 M=5~20 + D=30 改进：
%   1. AdaptiveAPD_Classification 替代 HybridPBI_Classification
%      - 用 RVEA APD 替代 PBI（自适应 θ_t）
%      - 用 UniformPoint NBI 直接生成参考向量，舍弃 K-means
%      - 加入 SDE 多样性信号，弥补 NDSort 在 M≥5 失效
%   2. BinaryRelationPairs 替代 CleanRelationPairs
%      - 标签从 ±1 改为 0/1，与新版 onehotconv2（2 类）一致
%      - 修复原 onehot 三类与训练数据不一致的隐藏 bug
%   3. DropoutEnsemble 替代单网络
%      - 5 个 patternnet 集成，网络结构缩小到 [xDim, ⌈xDim/2⌉]
%      - 提供不确定性估计，缓解高维欠拟合
%   4. RSurrogateAssistedSelection_v2
%      - scores>3.9 改为 quantile(scores, 0.9)
%      - 不确定性引导真实评估，每代选 5~8 个解
%   5. RefSelect_APD 替代雷达图 RefSelect
%      - t-DEA 鲁棒归一化
%      - RVEA APD niching 替代 2D 雷达投影
%
%------------------------------- 参考文献 ---------------------------------
% [1] H. Hao, A. Zhou, H. Qian, and H. Zhang. Expensive multiobjective
%     optimization by relation learning and prediction. IEEE TEVC, 2022.
% [2] R. Cheng, Y. Jin, M. Olhofer, and B. Sendhoff. A reference vector
%     guided evolutionary algorithm for many-objective optimization.
%     IEEE TEVC, 2016.
% [3] M. Li, S. Yang, and X. Liu. Shift-based density estimation for
%     Pareto-based algorithms in many-objective optimization. IEEE TEVC, 2014.
% [4] D. Guo et al. Evolutionary optimization of high-dimensional
%     multiobjective and many-objective expensive problems assisted by a
%     dropout neural network. IEEE TSMC: Systems, 2022.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            %% 参数设置
            [k, gmax, K] = Algorithm.ParameterSet(6, 3000, 5);

            %% 拉丁超立方初始化
            if Problem.D <= 10
                N = 11 * Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper - Problem.lower, N, 1) .* PopDec ...
                + repmat(Problem.lower, N, 1));
            Archive = Population;

            %% 主优化循环
            while Algorithm.NotTerminated(Archive)
                ratio = Problem.FE / Problem.maxFE;

                % Step 1: 自适应 APD + SDE 分类（二元）
                [Catalog, Ref] = AdaptiveAPD_Classification( ...
                    Population, ratio, N, k);

                % Step 2: 构造二元关系对（0/1）
                Input = Population.decs;
                [XXs, YYs] = BinaryRelationPairs(Input, Catalog);

                % 极端情况兜底：好/差类有空时跳过本代代理训练
                if isempty(XXs)
                    Archive = updateArchiveByGA(Problem, Archive, Population, Ref);
                    Population = RefSelect_APD(Archive, Problem.N);
                    continue;
                end

                % Step 3: 划分训练/测试集
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs);
                xDim = size(TrainIn, 2);

                % Step 4: 归一化
                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv2(TrainOut, 1);

                % Step 5: 训练 Dropout 集成
                nets = DropoutEnsemble(TrainIn_nor, TrainOut_onehot, xDim, K);

                % Step 6: 在测试集上估计平均错误率（用于诊断/可视化）
                if ~isempty(TestIn)
                    TestIn_nor = mapminmax('apply', TestIn', TrainIn_struct)';
                    pre_avg = zeros(size(TestIn_nor, 1), 2);
                    for ki = 1 : length(nets)
                        pre_avg = pre_avg + nets{ki}(TestIn_nor')';
                    end
                    pre_avg = pre_avg / length(nets);
                    TestPre = onehotconv2(pre_avg, 2);
                    p_err = sum(TestPre ~= TestOut) / size(TestPre, 1);
                else
                    p_err = NaN;
                end

                % Step 7: 打包代理模型
                Smodel = struct();
                Smodel.X         = Input;
                Smodel.Y         = double(Catalog);   % logical → double（0/1）
                Smodel.mp_struct = TrainIn_struct;
                Smodel.nets      = nets;
                Smodel.p_err     = p_err;

                % Step 8: 代理辅助选择（分位数 + 不确定性引导）
                Next = RSurrogateAssistedSelection_v2( ...
                    Problem, Ref, Population.decs, gmax, Smodel);

                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % Step 9: 环境选择（t-DEA 归一化 + RVEA APD niching）
                Population = RefSelect_APD(Archive, Problem.N);
            end
        end
    end
end


function Archive = updateArchiveByGA(Problem, Archive, Population, Ref)
% 兜底：当代理无法训练时，用 GA 直接生成几个解加入 archive
    fallback = OperatorGA(Problem, [Population.decs; Ref.decs], {1, 15, 1, 5});
    n_fallback = min(4, size(fallback, 1));
    if n_fallback > 0
        Archive = [Archive, Problem.Evaluation(fallback(1 : n_fallback, :))];
    end
end
