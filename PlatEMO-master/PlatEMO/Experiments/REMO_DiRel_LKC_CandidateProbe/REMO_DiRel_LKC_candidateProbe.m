classdef REMO_DiRel_LKC_candidateProbe < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_DiRel_LKC with candidate-level full/sub network probe.

    methods
        function main(Algorithm, Problem)
            [k_easy_user, tau_conf, alpha, k, gmax, K_ens, win_K, nCells, minRel, scalarGap, probe_out_path] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 1000, 3, 3, 5, 0.65, 0.05, '');

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

            probe_data = {};
            gen_data = {};
            config = struct('k_easy_user', k_easy_user, 'tau_conf', tau_conf, ...
                'alpha', alpha, 'k', k, 'gmax', gmax, 'K_ens', K_ens, ...
                'win_K', win_K, 'nCells', nCells, 'minRel', minRel, ...
                'scalarGap', scalarGap, 'pairMax', pairMax, 'anchorMax', anchorMax);

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
                CandidatePool = [];
                PoolScores = [];
                PoolInfo = [];
                selectedMask = [];
                Smodel = [];
                usedFallback = true;

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
                    Smodel.EasyAggObj = EasyAggObj;
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

                    [Next, SelectInfo, CandidatePool, PoolScores, PoolInfo, selectedMask] = ...
                        ArbitratedSelection_LKC_probe(Problem, Ref, Input, gmax, Smodel);
                    usedFallback = isempty(Next);
                end

                if isempty(Next)
                    Next = fallbackOffspring(Problem, Ref, Input);
                end

                remain = Problem.maxFE - Problem.FE;
                if remain > 0
                    NextEval = sanitizeCandidates(Next, Problem, Archive, remain);

                    gen_rec = makeGenerationRecord(Problem, gen, Population, Smodel, ...
                        d_score, groupDifficulty, S_easy_group, EasyInfo, SelectInfo, ...
                        usedFallback, size(CandidatePool, 1), size(NextEval, 1));

                    if ~isempty(CandidatePool) && isstruct(PoolInfo) && ~isempty(Smodel)
                        evaluatedMask = ismember(CandidatePool, NextEval, 'rows');
                        try
                            rec = compute_lkc_candidate_metrics(Problem, Population, CandidatePool, ...
                                Smodel, PoolScores, PoolInfo, selectedMask, evaluatedMask, gen, Problem.FE);
                            rec.usedFallback = usedFallback;
                            probe_data{end+1} = rec; %#ok<AGROW>
                            gen_rec = mergeProbeStats(gen_rec, rec);
                        catch ME
                            warning('LKC candidate probe failed at gen %d: %s', gen, ME.message);
                            gen_rec.probe_error = ME.message;
                        end
                    end

                    gen_data{end+1} = gen_rec; %#ok<AGROW>
                    saveProbe(probe_out_path, probe_data, gen_data, config, Problem);

                    Archive = [Archive, Problem.Evaluation(NextEval)];
                end

                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end


function [Next, SelectInfo, CandidatePool, scores, info, selectedMask] = ...
    ArbitratedSelection_LKC_probe(Problem, Ref, Input, wmax, Smodel)
    gaParam = difficultyAwareGAParam(Smodel);
    Next = OperatorGA(Problem, [Input; Ref.decs], gaParam);
    CandidatePool = zeros(0, size(Input, 2));
    scores = zeros(0, 1);
    info = emptyTraceInfo();

    i = 0;
    while i < wmax
        [sorted_idx, iterScores, iterInfo] = scoreAndSort(Smodel, Next);
        [CandidatePool, scores, info] = appendTrace(CandidatePool, scores, info, ...
            Next, iterScores, iterInfo);
        nKeep = min(length(Ref), size(Next, 1));
        if nKeep <= 0
            break;
        end
        Selected = Next(sorted_idx(1:nKeep), :);
        Next = OperatorGA(Problem, [Selected; Ref.decs], gaParam);
        i = i + size(Next, 1);
    end

    finalStart = size(CandidatePool, 1) + 1;
    [~, finalScores, finalInfo] = scoreAndSort(Smodel, Next);
    [CandidatePool, scores, info] = appendTrace(CandidatePool, scores, info, ...
        Next, finalScores, finalInfo);
    SelectInfo = finalInfo;

    threshold = getField(Smodel, 'scoreThreshold', 3.4);
    selectedMask = false(size(CandidatePool, 1), 1);
    finalSelected = false(size(Next, 1), 1);
    if sum(finalScores > threshold) < 4
        [~, ind] = sort(finalScores, 'descend');
        keep = ind(1:min(4, size(Next, 1)));
        finalSelected(keep) = true;
    else
        finalSelected = finalScores > threshold;
    end
    selectedMask(finalStart:finalStart + numel(finalSelected) - 1) = finalSelected;
    Next = Next(finalSelected, :);
end


function [ind, scores, info] = scoreAndSort(Smodel, Candidates)
    [scores, info] = ArbitratorScore_LKC(Smodel, Candidates);
    [~, ind] = sort(scores, 'descend');
end


function [CandidatePool, scores, info] = appendTrace(CandidatePool, scores, info, ...
        NewCandidates, newScores, newInfo)
    CandidatePool = [CandidatePool; NewCandidates]; %#ok<AGROW>
    scores = [scores; newScores(:)]; %#ok<AGROW>
    info.mu_F = [info.mu_F; newInfo.mu_F(:)];
    info.sigma2_F = [info.sigma2_F; newInfo.sigma2_F(:)];
    info.confidence_F = [info.confidence_F; newInfo.confidence_F(:)];
    info.mu_S = [info.mu_S; newInfo.mu_S(:)];
    info.sigma2_S = [info.sigma2_S; newInfo.sigma2_S(:)];
    info.confidence_S = [info.confidence_S; newInfo.confidence_S(:)];
    info.fullUncertain = [info.fullUncertain; newInfo.fullUncertain(:)];
    info.subTriggered = [info.subTriggered; newInfo.subTriggered(:)];
    info.disagreement = [info.disagreement; newInfo.disagreement(:)];
    info.fullDominated = [info.fullDominated; newInfo.fullDominated(:)];
    info.subTieBreakDominated = [info.subTieBreakDominated; newInfo.subTieBreakDominated(:)];
end


function info = emptyTraceInfo()
    info = struct();
    info.mu_F = zeros(0, 1);
    info.sigma2_F = zeros(0, 1);
    info.confidence_F = zeros(0, 1);
    info.mu_S = zeros(0, 1);
    info.sigma2_S = zeros(0, 1);
    info.confidence_S = zeros(0, 1);
    info.fullUncertain = false(0, 1);
    info.subTriggered = false(0, 1);
    info.disagreement = false(0, 1);
    info.fullDominated = false(0, 1);
    info.subTieBreakDominated = false(0, 1);
end


function param = difficultyAwareGAParam(Smodel)
    diff = Smodel.easyDifficulty;
    if isempty(diff) || isnan(diff)
        diff = 0.5;
    end
    diff = min(max(diff, 0), 1);
    disC = round(10 + 20 * (1 - diff));
    disM = round(5 + 20 * (1 - diff));
    proM = 1 + 0.5 * diff;
    param = {1, disC, proM, disM};
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


function rec = makeGenerationRecord(Problem, gen, Population, Smodel, d_score, ...
        groupDifficulty, S_easy_group, EasyInfo, SelectInfo, usedFallback, nPool, nEval)
    rec = struct();
    rec.gen = gen;
    rec.FE = Problem.FE;
    rec.N = length(Population);
    rec.M = Problem.M;
    rec.D = Problem.D;
    rec.nCandidatePool = nPool;
    rec.nEvaluatedFromPool = nEval;
    rec.usedFallback = usedFallback;
    rec.d_score = d_score;
    rec.groupDifficulty = groupDifficulty;
    rec.easyGroups = S_easy_group;
    rec.easyInfo = EasyInfo;
    rec.p_err_F = NaN;
    rec.p_err_S = NaN;
    rec.groupCount = 0;
    rec.easyGroupCount = numel(S_easy_group);
    rec.easyRawCount = 0;
    rec.meanGroupReliability = NaN;
    rec.subTriggeredRatio = NaN;
    rec.fullUncertainRatio = NaN;
    rec.disagreementRatio = NaN;

    if isstruct(Smodel)
        rec.p_err_F = Smodel.DualNet.p_err_F;
        rec.p_err_S = Smodel.DualNet.p_err_S;
        rec.easyRawCount = numel(Smodel.S_easy_raw);
        if isfield(Smodel, 'StructState')
            rec.groupCount = numel(Smodel.StructState.Groups);
            if isfield(Smodel.StructState, 'GroupReliability')
                rec.meanGroupReliability = mean(Smodel.StructState.GroupReliability);
            end
        end
    end

    if isstruct(SelectInfo) && isfield(SelectInfo, 'subTriggeredRatio')
        rec.subTriggeredRatio = SelectInfo.subTriggeredRatio;
        rec.fullUncertainRatio = SelectInfo.fullUncertainRatio;
        rec.disagreementRatio = SelectInfo.disagreementRatio;
    end
end


function gen_rec = mergeProbeStats(gen_rec, rec)
    gen_rec.fullAccFull = rec.stat_full_acc_full;
    gen_rec.subAccFull = rec.stat_sub_acc_full;
    gen_rec.fullAccAgg = rec.stat_full_acc_agg;
    gen_rec.subAccAgg = rec.stat_sub_acc_agg;
    gen_rec.subAccAggTriggered = rec.stat_sub_acc_agg_triggered;
    gen_rec.fullAccAggTriggered = rec.stat_full_acc_agg_triggered;
    gen_rec.subUsageRate = rec.stat_sub_usage_rate;
    gen_rec.highFRate = rec.stat_highF_rate;
    gen_rec.highSRate = rec.stat_highS_rate;
    gen_rec.disagreementRate = rec.stat_disagreement_rate;
    gen_rec.selectedRate = rec.stat_selected_rate;
    gen_rec.evaluatedRate = rec.stat_evaluated_rate;
end


function saveProbe(probe_out_path, probe_data, gen_data, config, Problem)
    if isempty(probe_out_path)
        return;
    end
    problem_name = class(Problem); %#ok<NASGU>
    M_val = Problem.M; %#ok<NASGU>
    D_val = Problem.D; %#ok<NASGU>
    save(probe_out_path, 'probe_data', 'gen_data', 'config', ...
         'problem_name', 'M_val', 'D_val', '-v7');
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


function value = getField(S, name, defaultValue)
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        value = S.(name);
    else
        value = defaultValue;
    end
end
