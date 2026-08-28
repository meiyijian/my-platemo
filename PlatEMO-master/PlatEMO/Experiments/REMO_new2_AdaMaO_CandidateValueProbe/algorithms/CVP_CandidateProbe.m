classdef CVP_CandidateProbe < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Candidate-value probe host: one shared framework, five selection arms.
%
% The framework (Latin-hypercube initialization, HPC labels via
% HybridPBI_Classification with k_eff = min(N, max(6, ceil(1.5*M))),
% relation-pair construction, relation-network training, SDE indicator
% training, RefSelect environmental selection) is identical to
% REMO_new2_AdaMaO_SDEOnly_UniformMix_Original. The ONLY factor that varies
% across arms is the final candidate-selection rule inside
% CVPCandidateSelection, so arm is the single manipulated variable.
%
% Instrumentation, all off-budget:
%   Candidate Survival Rate  - fraction of the evaluated batch that survives
%                              the immediately following environmental
%                              selection, tracked by SOLUTION handle identity
%   Oracle batch overlap     - agreement between the algorithm's batch and a
%                              greedy oracle batch computed from true
%                              objective values via Problem.CalObj
%
% arm      ---    4 --- Arm identifier 0..4 (see CVPArmCatalog)
% gmax     --- 3000 --- Maximum surrogate-assisted training generations
% pMix     --- 0.50 --- Probability of indicator branch (arm 4 only)
% rGood    --- 0.25 --- Proportion assigned to the positive group
% qKeep    --- 0.80 --- Quantile retained during exploratory selection
% lambda0  --- 0.35 --- Initial exploration strength
% nMin     ---    4 --- Minimum number of candidate solutions
% nMax     ---    6 --- Maximum number of candidate solutions
% oracleEvery --- 1 --- Run the oracle diagnostic every n-th generation
% oraclePoolLimit --- 400 --- Oracle pool subsample ceiling
% oracleRefSize --- 300 --- Oracle reference-set subsample size

    properties(SetAccess = private)
        probeData = struct();
    end

    methods
        function main(Algorithm, Problem)
            [arm, gmax, pMix, rGood, qKeep, lambda0, nMin, nMax, ...
                oracleEvery, oraclePoolLimit, oracleRefSize] = ...
                Algorithm.ParameterSet(4, 3000, 0.50, 0.25, 0.80, 0.35, 4, 6, ...
                1, 400, 300);
            CVPValidateParameters(arm, gmax, pMix, rGood, qKeep, lambda0, ...
                nMin, nMax, oracleEvery, oraclePoolLimit, oracleRefSize);

            probeClock = tic();

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper - Problem.lower, N, 1) .* PopDec + ...
                repmat(Problem.lower, N, 1));
            Archive = Population;
            initialFE = Problem.FE;

            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            oracleStream = CVPOracleStream(Algorithm.run, Problem.M);
            oracleOptions = struct( ...
                'PoolLimit', oraclePoolLimit, ...
                'Stream', oracleStream, ...
                'Reference', CVPOracleReference(Problem, oracleRefSize, Algorithm.run));
            Lp = 1;

            generationRows = CVPEmptyGenerationRows();
            generation = 0;

            % ALGORITHM.NotTerminated throws PlatEMO:Termination when the FE
            % budget is spent, so nothing after this while loop ever runs.
            % probeData is therefore committed at the END of every iteration
            % rather than once at the end of main.
            Algorithm.probeData = struct( ...
                'Arm', arm, 'Generations', generationRows, ...
                'PopulationN', N, 'ProblemN', Problem.N, ...
                'InitialFE', initialFE, 'CompletedFE', Problem.FE, ...
                'OracleEvery', oracleEvery, ...
                'OraclePoolLimit', oraclePoolLimit, ...
                'OracleReferenceSize', size(oracleOptions.Reference, 1), ...
                'ProbeRuntime', toc(probeClock));

            while Algorithm.NotTerminated(Archive)
                generation = generation + 1;
                u = rand(modeStream, 1);
                ratio = Problem.FE / Problem.maxFE;
                k_eff = min(Problem.N, max(6, ceil(1.5*Problem.M)));

                [~, ~, Catalog, ~, Ref] = HybridPBI_Classification( ...
                    Population, ratio, 'Nref', N, 'k', k_eff, ...
                    'theta', 5, 'rGood', rGood);

                Input = Population.decs;
                [XXs, YYs] = GetRelationPairs(Input, Catalog);
                if isempty(XXs)
                    Population = RefSelect(Archive, Problem.N);
                    continue;
                end

                [net, TrainIn_struct, p_err] = TrainOriginalRelationModel(XXs, YYs);

                IndicatorModel = [];
                try
                    [Fitness, Lp] = IndicatorSelectorSDEOnly(Population, Lp);
                catch
                    Fitness = [];
                end
                if ~isempty(Fitness)
                    try
                        IndicatorModel = fitrsvm(Population.decs, Fitness, ...
                            'KernelFunction', 'rbf', ...
                            'KernelScale', 'auto', 'Standardize', true);
                    catch
                        IndicatorModel = [];
                    end
                end

                candidate_mode = ResolveUniformMixMode( ...
                    ~isempty(IndicatorModel), u, pMix);

                Smodel = struct();
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;
                Smodel.lambda0 = lambda0;
                Smodel.ratio = ratio;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode = candidate_mode;

                [Next, trace] = CVPCandidateSelection( ...
                    Problem, Ref, Population.decs, gmax, Smodel, ...
                    qKeep, nMin, nMax, arm);

                remain = Problem.maxFE - Problem.FE;
                usedFallback = false;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem, [Population.decs; Ref.decs], ...
                        {1, 15, 1, 5});
                    Next = Next(1:min(nMin, size(Next, 1)), :);
                    usedFallback = true;
                end

                truncatedBatch = false;
                row = CVPEmptyGenerationRows(1);
                row.Generation = generation;
                row.FEBefore = Problem.FE;
                row.Ratio = ratio;
                row.KEff = k_eff;
                row.ArchiveSizeBefore = numel(Archive);

                if ~isempty(Next) && remain > 0
                    if size(Next, 1) > remain
                        Next = Next(1:remain, :);
                        truncatedBatch = true;
                    end

                    % ---- Oracle diagnostic BEFORE the true evaluation ----
                    oracle = CVPEmptyOracle();
                    if ~usedFallback && mod(generation - 1, oracleEvery) == 0 ...
                            && isfield(trace, 'Candidates') && ~isempty(trace.Candidates)
                        selectedIndex = trace.SelectedIndex;
                        if truncatedBatch
                            selectedIndex = selectedIndex(1:size(Next, 1));
                        end
                        oracle = CVPOracleBatch(Problem, trace.Candidates, ...
                            Archive.objs, selectedIndex, size(Next, 1), oracleOptions);
                    end

                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive, NewSols]; %#ok<AGROW>
                    row = CVPFillOracleFields(row, oracle);
                    row.BatchSize = numel(NewSols);
                else
                    NewSols = [];
                    row = CVPFillOracleFields(row, CVPEmptyOracle());
                    row.BatchSize = 0;
                end

                % ---- Environmental selection, then survival by identity ----
                Population = RefSelect(Archive, Problem.N);
                if isempty(NewSols)
                    row.SurvivorCount = NaN;
                    row.SurvivalRate = NaN;
                else
                    survived = 0;
                    for index = 1:numel(NewSols)
                        if any(Population == NewSols(index))
                            survived = survived + 1;
                        end
                    end
                    row.SurvivorCount = survived;
                    row.SurvivalRate = survived / numel(NewSols);
                end

                row.FEAfter = Problem.FE;
                row.ArchiveSizeAfter = numel(Archive);
                row.PopulationSize = numel(Population);
                row.ArchiveOverN = numel(Archive) / max(1, Problem.N);
                row.UsedFallback = usedFallback;
                row.TruncatedBatch = truncatedBatch;
                row = CVPFillTraceFields(row, trace, Problem);
                generationRows(end+1, 1) = row; %#ok<AGROW>

                Algorithm.probeData.Generations = generationRows;
                Algorithm.probeData.CompletedFE = Problem.FE;
                Algorithm.probeData.ProbeRuntime = toc(probeClock);
            end
        end
    end
end
