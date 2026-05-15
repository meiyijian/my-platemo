classdef REMO_DiRel < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Difficulty-aware dual-scale relation learning for expensive MOO.
%
% Public parameters are kept compatible with the original implementation:
% k_easy   --- -1   --- size of the easy-objective subset (-1 = auto)
% tau_conf --- 0.3  --- uncertainty threshold for arbitration
% alpha    --- 0.6  --- difficulty weight for model difficulty
% k        --- 6    --- number of reference solutions
% gmax     --- 1000 --- surrogate-screened candidate budget per generation
% K_ens    --- 3    --- bagging ensemble size
% win_K    --- 3    --- difficulty smoothing window

    methods
        function main(Algorithm,Problem)
            [k_easy_user,tau_conf,alpha,k,gmax,K_ens,win_K] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 1000, 3, 3);

            pairMax   = 6000;
            anchorMax = 30;

            if Problem.M <= 2
                k_easy = 1;
            elseif k_easy_user <= 0
                k_easy = max(2, min(Problem.M-1, ceil(Problem.M/2)));
            else
                k_easy = max(2, min(Problem.M-1, k_easy_user));
            end

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive    = Population;

            H.d_score = nan(Problem.M, win_K);
            H.model   = nan(Problem.M, win_K);
            H.improve = nan(Problem.M, win_K);
            H.conf    = nan(Problem.M, win_K);
            H.best    = nan(Problem.M, 1);
            gen       = 0;

            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                Ref = RefSelect(Population, k);
                [d_score, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy);

                Input  = Population.decs;
                PopObj = Population.objs;
                RefObj = Ref.objs;

                Catalog_F   = GetOutput_PBI(PopObj, RefObj);
                [XX_F,YY_F] = GetRelationPairsBudgeted(Input, Catalog_F, pairMax);

                S_easy    = double(S_easy(:)');
                M_sub     = numel(S_easy);
                PopObjSub = PopObj(:, S_easy);
                Ref_S_obj = UniformPoint(size(RefObj,1), M_sub, 'ILD');
                P_min     = min(PopObjSub, [], 1);
                P_span    = max(max(PopObjSub, [], 1) - P_min, 1e-12);
                Ref_S_obj = Ref_S_obj .* P_span + P_min;
                Catalog_S = GetOutput_PBI(PopObjSub, Ref_S_obj);
                [XX_S,YY_S] = GetRelationPairsBudgeted(Input, Catalog_S, pairMax);

                Next = [];
                if ~isempty(XX_F) && ~isempty(XX_S)
                    DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens);

                    Smodel = struct();
                    Smodel.X              = Input;
                    Smodel.Y_F            = Catalog_F;
                    Smodel.Y_S            = Catalog_S;
                    Smodel.DualNet        = DualNet;
                    Smodel.S_easy         = S_easy;
                    Smodel.tau_conf       = tau_conf;
                    Smodel.anchorMax      = anchorMax;
                    Smodel.easyDifficulty = mean(d_score(S_easy));

                    Next = ArbitratedSelection(Problem, Ref, Input, gmax, Smodel);
                end

                if isempty(Next)
                    Next = fallbackOffspring(Problem, Ref, Input);
                end

                remain = Problem.maxFE - Problem.FE;
                if remain > 0
                    Next = sanitizeCandidates(Next, Problem, Archive, remain);
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end

function Next = fallbackOffspring(Problem, Ref, Input)
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 20, 1, 20});
end

function Next = sanitizeCandidates(Next, Problem, Archive, remain)
    if isempty(Next)
        Next = randomFill(Problem, min(4, remain));
        return;
    end

    Lower = repmat(Problem.lower, size(Next,1), 1);
    Upper = repmat(Problem.upper, size(Next,1), 1);
    Next  = min(max(Next, Lower), Upper);
    Next  = unique(Next, 'rows', 'stable');

    if ~isempty(Archive)
        old  = ismember(Next, Archive.decs, 'rows');
        Next = Next(~old, :);
    end

    if isempty(Next)
        Next = randomFill(Problem, min(4, remain));
    elseif size(Next,1) > remain
        Next = Next(1:remain, :);
    end
end

function X = randomFill(Problem, n)
    if n <= 0
        X = zeros(0, Problem.D);
        return;
    end
    U = UniformPoint(n, Problem.D, 'Latin');
    X = repmat(Problem.upper-Problem.lower,n,1).*U + repmat(Problem.lower,n,1);
end
