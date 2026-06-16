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

            D = Problem.D;
            M = Problem.M;
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
            NI = max(2 * D, InitialSampleRate * D);
            PopDec0     = UniformPoint(NI, D, 'Latin');
            Archive     = Problem.Evaluation(repmat(Problem.upper - Problem.lower, NI, 1) ...
                .* PopDec0 + repmat(Problem.lower, NI, 1));
            % Ensure the Archive is a valid Population by leaving the decs/objs
            % as set by Problem.Evaluation.

            %% Establish the objective reduction plan
            [GroupMap, Fmin, Fmax] = reduceObjectives(Archive.objs, K, ...
                ReductionStrategy, 1);
            % Inject the reduced objectives into Archive(i).add
            Zall = reduceObjectives(Archive.objs, K, ReductionStrategy, 1, ...
                GroupMap, Fmin, Fmax);
            for i = 1 : length(Archive)
                Archive(i).add = Zall(i, :);
            end
            ZallStore = Zall;   % keep a local copy that grows each iteration

            %% Train the initial surrogate(s)
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
                % A mix of offspring from the archive and pure mutations
                OffDec = OperatorGA(Problem, BaseDec);
                while size(OffDec, 1) < PoolSize
                    More = OperatorGA(Problem, BaseDec);
                    OffDec = [OffDec; More];
                end
                CandDec = OffDec(1:min(PoolSize, size(OffDec, 1)), :);
                CandDec = Problem.CalDec(CandDec);

                % --- b) Surrogate prediction in the reduced space ----------
                [Mu, Sigma] = buildSurrogate(Models, CandDec, ...
                    SurrogateType, TrainDec);

                % --- c) Surrogate-assisted infill selection ---------------
                Zref = ZallStore(NDSort(ZallStore, 1) == 1, :);
                [NewDec, ~] = infillSelect(CandDec, Mu, Sigma, Zref, ...
                    Archive.decs, K, AcquisitionFunc, BatchSize, ...
                    Problem.FE / max(Problem.maxFE, 1), D);
                if isempty(NewDec)
                    % Fallback: farthest-point sampling from the archive
                    if size(Archive.decs, 1) >= 1
                        NewDec = farthestPoint(Archive.decs, ...
                            min(BatchSize, size(Archive.decs, 1)));
                    else
                        break;
                    end
                end
                NewDec = Problem.CalDec(NewDec);

                % --- d) True evaluation ------------------------------------
                New = Problem.Evaluation(NewDec);
                Archive = [Archive, New];

                % --- e) Update reduced objectives for the new samples only -
                Znew = reduceObjectives(New.objs, K, ReductionStrategy, 1, ...
                    GroupMap, Fmin, Fmax);
                for i = 1 : length(New)
                    New(i).add = Znew(i, :);
                end
                ZallStore = [ZallStore; Znew];

                % --- f) Refit the surrogate(s) -----------------------------
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
