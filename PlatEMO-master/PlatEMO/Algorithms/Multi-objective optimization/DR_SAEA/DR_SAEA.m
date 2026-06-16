classdef DR_SAEA < ALGORITHM
% <2026> <multi/many> <real/integer> <expensive>
% Dimension Reduction based Surrogate-Assisted Evolutionary Algorithm
% K                   ---      2 --- Number of reduced objectives
% ReductionStrategy   --- 'random' --- 'random' or 'correlation'
% SurrogateType       --- 'Kriging' --- 'Kriging' or 'RBF' or 'Relation'
% AcquisitionFunc     --- 'balanced' --- 'balanced' or 'exploitation' or 'exploration'
% BatchSize           ---      1 --- Number of infill points per iteration
% InitialSampleRate   ---     10 --- Initial sample size = rate * D

%------------------------------- Reference --------------------------------
% DR_SAEA: a modular surrogate-assisted evolutionary algorithm for
% expensive many-objective optimization built on the PlatEMO platform. The
% algorithm is composed of three pluggable modules: objective reduction,
% surrogate modeling, and infill sampling. The reduction module is used
% only as an intermediate representation for the surrogate and the
% acquisition; the original M-dimensional objectives are always preserved
% for true evaluation and metric calculation.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026. You are free to use DR_SAEA for research purposes.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            %% Parameter setting
            [K, ReductionStrategy, SurrogateType, AcquisitionFunc, ...
                BatchSize, InitialSampleRate] = Algorithm.ParameterSet( ...
                2, 'random', 'Kriging', 'balanced', 1, 10);

            D = Problem.D;   % 决策变量维数
            M = Problem.M;   % 原始目标维数
            % K 必须严格小于 M，否则降维失去意义
            if K >= M
                warning('DR_SAEA:BadK', ...
                    'Reduced dimension K (%d) must be < original M (%d). Clamping to %d.', ...
                    K, M, max(1, M - 1));
                K = max(1, M - 1);
            end
            if K < 1
                K = 1;
            end
            BatchSize = max(1, round(BatchSize));
            InitialSampleRate = max(2, round(InitialSampleRate));

            %% Generate the initial population via LHS
            % NI = max(2*D, rate*D) 保证初始样本至少覆盖决策空间的基本维度
            NI = max(2 * D, InitialSampleRate * D);
            PopDec0     = UniformPoint(NI, D, 'Latin');
            % 注意：昂贵真实评估，NI 次调用计入 Problem.FE
            Archive     = Problem.Evaluation(repmat(Problem.upper - Problem.lower, NI, 1) ...
                .* PopDec0 + repmat(Problem.lower, NI, 1));
            % Archive 中的每个 SOLUTION 保留原始 M 维 .objs；
            % 降维目标仅存储在 .add 字段中，不修改 PROBLEM 基类

            %% Establish the objective reduction plan
            % 第一调用（计划模式）：返回 GroupMap, Fmin, Fmax
            [GroupMap, Fmin, Fmax] = reduceObjectives(Archive.objs, K, ...
                ReductionStrategy, 1);
            % 第二调用（应用模式）：对 Archive 计算降维目标 Zall
            % 注意：Fmin/Fmax 基于初始样本计算，后续保持不变。
            % 若优化后期 Archive 目标值远超初始范围，归一化会被裁剪到 [0,1] 边界，
            % 可能丢失区分度。可考虑周期性更新 Fmin/Fmax。
            Zall = reduceObjectives(Archive.objs, K, ReductionStrategy, 1, ...
                GroupMap, Fmin, Fmax);
            for i = 1 : length(Archive)
                Archive(i).add = Zall(i, :);
            end
            ZallStore = Zall;   % 本地副本，每轮迭代追加新样本的降维目标

            %% Train the initial surrogate(s)
            % 在降维后的 K 维目标上训练代理模型（而非原始 M 维）
            [Models, TrainDec] = buildSurrogate(Archive.decs, Zall, ...
                SurrogateType, D, K);

            %% Optimization loop
            while Algorithm.NotTerminated(Archive)
                % --- a) Generate candidate solutions via the GA operator -----
                PoolSize = max(50 * D, 100);
                BaseDec  = Archive.decs;
                if size(BaseDec, 1) < 2
                    BaseDec = repmat(BaseDec, 2, 1);
                end
                % 候选解全部来自 Archive 的遗传操作（SBX + PM），无随机注入。
                % 随着 Archive 收敛，候选池多样性会自然下降；
                % 可考虑混入少量 LHS 随机候选以维持探索能力。
                OffDec = OperatorGA(Problem, BaseDec);
                while size(OffDec, 1) < PoolSize
                    More = OperatorGA(Problem, BaseDec);
                    OffDec = [OffDec; More];
                end
                CandDec = OffDec(1:min(PoolSize, size(OffDec, 1)), :);
                % CalDec 将越界值钳制到边界内（不消耗 FE）
                CandDec = Problem.CalDec(CandDec);

                % --- b) Surrogate prediction in the reduced space ----------
                % 重要：预测是对降维后的 K 维目标，不是原始 M 维
                [Mu, Sigma] = buildSurrogate(Models, CandDec, ...
                    SurrogateType, TrainDec);

                % --- c) Surrogate-assisted infill selection ---------------
                % Zref = 当前 ZallStore 中的非支配前沿（在降维空间中）
                Zref = ZallStore(NDSort(ZallStore, 1) == 1, :);
                [NewDec, ~] = infillSelect(CandDec, Mu, Sigma, Zref, ...
                    Archive.decs, K, AcquisitionFunc, BatchSize, ...
                    Problem.FE / max(Problem.maxFE, 1), D);
                if isempty(NewDec)
                    % 回退：当采集函数无法选出有效点时（如所有候选均被去重），
                    % 使用 farthest-point 采样从 Archive 中选 BatchSize 个最分散的点。
                    % 注：farthestPoint 使用未设种子的 randi，可能影响可复现性。
                    if size(Archive.decs, 1) >= 1
                        NewDec = farthestPoint(Archive.decs, ...
                            min(BatchSize, size(Archive.decs, 1)));
                    else
                        break;
                    end
                end
                NewDec = Problem.CalDec(NewDec);

                % --- d) True evaluation ------------------------------------
                % 每次 iteration 的真实评估次数 = BatchSize（通常 = 1）
                New = Problem.Evaluation(NewDec);
                Archive = [Archive, New];

                % --- e) Update reduced objectives for the new samples only -
                % 使用与初始化相同的 GroupMap/Fmin/Fmax，保持降维一致性
                Znew = reduceObjectives(New.objs, K, ReductionStrategy, 1, ...
                    GroupMap, Fmin, Fmax);
                for i = 1 : length(New)
                    New(i).add = Znew(i, :);
                end
                ZallStore = [ZallStore; Znew];

                % --- f) Refit the surrogate(s) -----------------------------
                % 每轮全量重训练（O(N³) per Kriging target）。
                % 当 Archive 增长到 200+ 时可考虑增量更新策略以降低开销。
                [Models, TrainDec] = buildSurrogate(Archive.decs, ZallStore, ...
                    SurrogateType, D, K);
            end
        end
    end
end

function Picked = farthestPoint(ArchDec, k)
% Pick k diverse points from ArchDec using a simple farthest-point traversal.
    [N, D] = size(ArchDec);
    k = min(k, N);
    if k <= 0
        Picked = zeros(0, D);
        return;
    end
    Picked = zeros(k, D);
    Picked(1, :) = ArchDec(randi(N), :);
    for i = 2 : k
        D2 = pdist2(ArchDec, Picked(1:i-1, :));
        [~, idx] = max(min(D2, [], 2));
        Picked(i, :) = ArchDec(idx, :);
    end
end
