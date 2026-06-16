classdef REMO_DiRel_LKC < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Structure-aware objective grouping + REMO_DiRel dual relation learning.

    methods
        function main(Algorithm, Problem)
            [k_easy_user, tau_conf, alpha, k, gmax, K_ens, win_K, nCells, minRel, scalarGap] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 1000, 3, 3, 5, 0.65, 0.05);

            pairMax = 6000;
            anchorMax = 30;

            if Problem.M <= 2
                k_easy = 1;
            elseif k_easy_user <= 0
                k_easy = max(2, min(Problem.M - 1, ceil(Problem.M / 2)));
            else
                k_easy = max(2, min(Problem.M - 1, k_easy_user));
            end

            if Problem.D <= 10
                N = 11 * Problem.D - 1;
            else
                N = 100;
            end

            PopDec = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper - Problem.lower, N, 1) .* PopDec + ...
                repmat(Problem.lower, N, 1));
            Archive = Population;

            H.d_score = nan(Problem.M, win_K);
            H.model   = nan(Problem.M, win_K);
            H.improve = nan(Problem.M, win_K);
            H.conf    = nan(Problem.M, win_K);
            H.best    = nan(Problem.M, 1);
            gen = 0;

            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                Ref = RefSelect(Population, k);
                Input  = Population.decs;
                PopObj = Population.objs;
                RefObj = Ref.objs;

                structCfg = struct();
                structCfg.nCells = nCells;
                structCfg.minGroupReliability = minRel;
                StructState = BuildObjectiveStructure_LKC(Input, PopObj, structCfg);

                easyCfg = struct();
                easyCfg.eta = 0.5;
                easyCfg.minGroupReliability = minRel;
                [S_easy_raw, S_easy_group, EasyAggObj, d_score, groupDifficulty, H, EasyInfo] = ...
                    BuildStructureAwareEasySet(Population, H, gen, alpha, k_easy, StructState, easyCfg);

                [XX_F, YY_F, Catalog_F] = GetRelationPairsBudgeted_LKC(Input, PopObj, pairMax, RefObj, scalarGap);
                Ref_S_obj = makeReferenceObjectives(size(RefObj, 1), size(EasyAggObj, 2), EasyAggObj);
                [XX_S, YY_S, Catalog_S] = GetRelationPairsBudgeted_LKC(Input, EasyAggObj, pairMax, Ref_S_obj, scalarGap);

                Next = [];
                SelectInfo = [];
                if ~isempty(XX_F) && ~isempty(XX_S)
                    DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens);

                    Smodel = struct();
                    Smodel.X = Input;
                    Smodel.Y_F = Catalog_F;
                    Smodel.Y_S = Catalog_S;
                    Smodel.DualNet = DualNet;
                    Smodel.S_easy_raw = S_easy_raw;
                    Smodel.S_easy_group = S_easy_group;
                    Smodel.StructState = StructState;
                    Smodel.tau_conf = tau_conf;
                    Smodel.anchorMax = anchorMax;
                    Smodel.easyDifficulty = mean(d_score(S_easy_raw));
                    Smodel.margin_F = 0.15;
                    Smodel.margin_S = 0.15;
                    Smodel.uncertainty_F = tau_conf.^2;
                    Smodel.uncertainty_S = tau_conf.^2;
                    Smodel.tieWeight = 0.5;
                    Smodel.betaUncertainty = 0.25;
                    Smodel.lambdaDisagreement = 0.75;
                    Smodel.gammaNovelty = 0.25;
                    Smodel.scoreThreshold = 3.4;

                    [Next, SelectInfo] = ArbitratedSelection_LKC(Problem, Ref, Input, gmax, Smodel);
                end

                if isempty(Next)
                    Next = fallbackOffspring(Problem, Ref, Input);
                end

                Algorithm.metric.lkcDiag{gen, 1} = makeDiagnostic( ...
                    d_score, StructState, groupDifficulty, S_easy_group, EasyInfo, SelectInfo);

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


function RefObj = makeReferenceObjectives(nRef, M, Obj)
    if M <= 0
        RefObj = [];
        return;
    end
    nRef = max(1, nRef);
    P_min = min(Obj, [], 1);
    P_span = max(max(Obj, [], 1) - P_min, 1e-12);
    if M == 1
        RefObj = linspace(P_min, P_min + P_span, nRef)';
    else
        RefObj = UniformPoint(nRef, M, 'ILD');
        RefObj = RefObj .* P_span + P_min;
    end
end


function Diag = makeDiagnostic(d_score, StructState, groupDifficulty, S_easy_group, EasyInfo, SelectInfo)
    Diag = struct();
    Diag.d_score = d_score;
    Diag.Sim = StructState.Sim;
    Diag.Groups = StructState.Groups;
    Diag.GroupReliability = StructState.GroupReliability;
    Diag.groupDifficulty = groupDifficulty;
    Diag.easyGroups = S_easy_group;
    Diag.easyInfo = EasyInfo;

    Diag.fullUncertainRatio = 1;
    Diag.subTriggeredRatio = 0;
    Diag.disagreementRatio = 0;
    Diag.fullDominatedRatio = 0;
    Diag.subTieBreakDominatedRatio = 0;
    if isstruct(SelectInfo) && isfield(SelectInfo, 'fullUncertainRatio')
        Diag.fullUncertainRatio = SelectInfo.fullUncertainRatio;
        Diag.subTriggeredRatio = SelectInfo.subTriggeredRatio;
        Diag.disagreementRatio = SelectInfo.disagreementRatio;
        Diag.fullDominatedRatio = SelectInfo.fullDominatedRatio;
        Diag.subTieBreakDominatedRatio = SelectInfo.subTieBreakDominatedRatio;
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

    Lower = repmat(Problem.lower, size(Next, 1), 1);
    Upper = repmat(Problem.upper, size(Next, 1), 1);
    Next = min(max(Next, Lower), Upper);
    Next = unique(Next, 'rows', 'stable');

    if ~isempty(Archive)
        old = ismember(Next, Archive.decs, 'rows');
        Next = Next(~old, :);
    end

    if isempty(Next)
        Next = randomFill(Problem, min(4, remain));
    elseif size(Next, 1) > remain
        Next = Next(1:remain, :);
    end
end


function X = randomFill(Problem, n)
    if n <= 0
        X = zeros(0, Problem.D);
        return;
    end
    U = UniformPoint(n, Problem.D, 'Latin');
    X = repmat(Problem.upper - Problem.lower, n, 1) .* U + repmat(Problem.lower, n, 1);
end
