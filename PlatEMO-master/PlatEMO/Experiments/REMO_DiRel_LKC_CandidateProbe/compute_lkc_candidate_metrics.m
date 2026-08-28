function rec = compute_lkc_candidate_metrics(Problem, Population, Candidates, ...
    Smodel, scores, info, selectedMask, evaluatedMask, gen, FE)
% compute_lkc_candidate_metrics - Candidate-level LKC dual-net diagnostics.
%
% The true objectives are computed through Problem.CalObj as a side-channel
% probe. This does not call Problem.Evaluation and does not change FE.

    nCand = size(Candidates, 1);
    PopObj = Population.objs;
    PopDec = Population.decs;

    rec = struct();
    rec.gen = gen;
    rec.FE = FE;
    rec.nCand = nCand;
    rec.N = size(PopObj, 1);
    rec.M = size(PopObj, 2);
    rec.D = size(PopDec, 2);
    rec.Candidates = Candidates;
    rec.selectedMask = logicalColumn(selectedMask, nCand);
    rec.evaluatedMask = logicalColumn(evaluatedMask, nCand);
    rec.scores = numericColumn(scores, nCand);

    rec.S_easy_raw = Smodel.S_easy_raw;
    rec.S_easy_group = Smodel.S_easy_group;
    rec.groupCount = numel(Smodel.StructState.Groups);
    rec.easyRawCount = numel(Smodel.S_easy_raw);
    rec.easyGroupCount = numel(Smodel.S_easy_group);

    if nCand == 0
        rec.stat_full_acc_full = NaN;
        rec.stat_sub_acc_full = NaN;
        rec.stat_full_acc_agg = NaN;
        rec.stat_sub_acc_agg = NaN;
        rec.stat_sub_acc_agg_triggered = NaN;
        rec.stat_sub_usage_rate = NaN;
        rec.stat_full_uncertain_rate = NaN;
        rec.stat_highF_rate = NaN;
        rec.stat_highS_rate = NaN;
        rec.stat_disagreement_rate = NaN;
        rec.stat_selected_rate = NaN;
        rec.stat_evaluated_rate = NaN;
        return;
    end

    rec.mu_F = numericColumn(info.mu_F, nCand);
    rec.sigma2_F = numericColumn(info.sigma2_F, nCand);
    rec.confidence_F = numericColumn(info.confidence_F, nCand);
    rec.mu_S = numericColumn(info.mu_S, nCand);
    rec.sigma2_S = numericColumn(info.sigma2_S, nCand);
    rec.confidence_S = numericColumn(info.confidence_S, nCand);
    rec.fullUncertain = logicalColumn(info.fullUncertain, nCand);
    rec.subTriggered = logicalColumn(info.subTriggered, nCand);
    rec.disagreement = logicalColumn(info.disagreement, nCand);
    rec.fullDominatedByScore = logicalColumn(info.fullDominated, nCand);
    rec.subTieBreakDominated = logicalColumn(info.subTieBreakDominated, nCand);

    rec.pred_F = sign(rec.mu_F);
    rec.pred_S = sign(rec.mu_S);

    [CandObjReal, hasRealObj] = evaluateCandidatesBypass(Problem, Candidates);
    CandObjNN = estimateCandidateObj(Candidates, PopDec, PopObj);
    if ~hasRealObj
        CandObjReal = CandObjNN;
    end
    rec.hasRealObj = hasRealObj;
    rec.CandObj_real = CandObjReal;
    rec.CandObj_nn = CandObjNN;

    [rec.dominatedByPopFull, rec.dominatesPopFull, ...
        rec.trueQualityFull, rec.trueRelationFull] = ...
        computePopDominanceLabels(CandObjReal, PopObj);

    [rec.dominatedByPopNN, rec.dominatesPopNN, ...
        rec.trueQualityNN, rec.trueRelationNN] = ...
        computePopDominanceLabels(CandObjNN, PopObj);

    [CandAggObj, PopAggObj, aggNote] = projectToLkcSubspace(CandObjReal, PopObj, Smodel);
    rec.CandAggObj = CandAggObj;
    rec.PopAggObj = PopAggObj;
    rec.aggTruthNote = aggNote;
    [rec.dominatedByPopAgg, rec.dominatesPopAgg, ...
        rec.trueQualityAgg, rec.trueRelationAgg] = ...
        computePopDominanceLabels(CandAggObj, PopAggObj);

    rec.correctF_full = rec.pred_F == rec.trueQualityFull;
    rec.correctS_full = rec.pred_S == rec.trueQualityFull;
    rec.correctF_agg = rec.pred_F == rec.trueQualityAgg;
    rec.correctS_agg = rec.pred_S == rec.trueQualityAgg;
    rec.correctF_nn = rec.pred_F == rec.trueQualityNN;
    rec.correctS_nn = rec.pred_S == rec.trueQualityNN;

    rec.stat_full_acc_full = mean(rec.correctF_full);
    rec.stat_sub_acc_full = mean(rec.correctS_full);
    rec.stat_full_acc_agg = mean(rec.correctF_agg);
    rec.stat_sub_acc_agg = mean(rec.correctS_agg);
    rec.stat_full_acc_nn = mean(rec.correctF_nn);
    rec.stat_sub_acc_nn = mean(rec.correctS_nn);
    rec.stat_sub_usage_rate = mean(rec.subTriggered);
    rec.stat_full_uncertain_rate = mean(rec.fullUncertain);
    rec.stat_highF_rate = mean(~rec.fullUncertain);
    rec.stat_highS_rate = mean(abs(rec.mu_S) >= getField(Smodel, 'margin_S', 0.15) & ...
                               rec.sigma2_S <= getField(Smodel, 'uncertainty_S', Smodel.tau_conf.^2));
    rec.stat_disagreement_rate = mean(rec.disagreement);
    rec.stat_selected_rate = mean(rec.selectedMask);
    rec.stat_evaluated_rate = mean(rec.evaluatedMask);
    rec.stat_label_agree_full_agg = mean(rec.trueQualityFull == rec.trueQualityAgg);
    rec.stat_label_agree_real_nn = mean(rec.trueQualityFull == rec.trueQualityNN);

    trig = rec.subTriggered;
    if any(trig)
        rec.stat_sub_acc_full_triggered = mean(rec.correctS_full(trig));
        rec.stat_sub_acc_agg_triggered = mean(rec.correctS_agg(trig));
        rec.stat_full_acc_full_triggered = mean(rec.correctF_full(trig));
        rec.stat_full_acc_agg_triggered = mean(rec.correctF_agg(trig));
    else
        rec.stat_sub_acc_full_triggered = NaN;
        rec.stat_sub_acc_agg_triggered = NaN;
        rec.stat_full_acc_full_triggered = NaN;
        rec.stat_full_acc_agg_triggered = NaN;
    end

    sel = rec.selectedMask;
    if any(sel)
        rec.stat_full_acc_full_selected = mean(rec.correctF_full(sel));
        rec.stat_sub_acc_agg_selected = mean(rec.correctS_agg(sel));
        rec.stat_selected_mean_true_full = mean(rec.trueQualityFull(sel));
    else
        rec.stat_full_acc_full_selected = NaN;
        rec.stat_sub_acc_agg_selected = NaN;
        rec.stat_selected_mean_true_full = NaN;
    end
end


function [CandObj, ok] = evaluateCandidatesBypass(Problem, Candidates)
    try
        CandDec = Problem.CalDec(Candidates);
        CandObj = Problem.CalObj(CandDec);
        ok = true;
    catch ME
        warning('LKC candidate probe CalObj bypass failed: %s', ME.message);
        CandObj = [];
        ok = false;
    end
end


function CandObj = estimateCandidateObj(Candidates, PopDec, PopObj)
    nCand = size(Candidates, 1);
    M = size(PopObj, 2);
    CandObj = zeros(nCand, M);
    if isempty(PopDec)
        return;
    end
    for i = 1:nCand
        diff = bsxfun(@minus, PopDec, Candidates(i, :));
        dist = sum(diff.^2, 2);
        [~, idx] = min(dist);
        CandObj(i, :) = PopObj(idx, :);
    end
end


function [dominatedByPop, dominatesPop, trueQuality, trueRelation] = ...
    computePopDominanceLabels(CandObj, PopObj)
    nCand = size(CandObj, 1);
    dominatedByPop = false(nCand, 1);
    dominatesPop = false(nCand, 1);

    for i = 1:nCand
        ci = CandObj(i, :);
        for j = 1:size(PopObj, 1)
            pj = PopObj(j, :);
            if all(ci <= pj) && any(ci < pj)
                dominatesPop(i) = true;
            elseif all(pj <= ci) && any(pj < ci)
                dominatedByPop(i) = true;
            end
        end
    end

    trueQuality = ones(nCand, 1);
    trueQuality(dominatedByPop & ~dominatesPop) = -1;

    trueRelation = zeros(nCand, 1);
    trueRelation(dominatesPop & ~dominatedByPop) = 1;
    trueRelation(dominatedByPop & ~dominatesPop) = -1;
end


function [CandAggObj, PopAggObj, note] = projectToLkcSubspace(CandObj, PopObj, Smodel)
    note = 'group_aggregated';
    if isfield(Smodel, 'S_easy_group') && ~isempty(Smodel.S_easy_group) && ...
            isfield(Smodel, 'StructState') && isfield(Smodel.StructState, 'Groups')
        groups = Smodel.StructState.Groups;
        weights = Smodel.StructState.GroupWeights;
        selected = Smodel.S_easy_group(:)';

        PopNorm = applyObjectiveScale(PopObj, Smodel.StructState);
        CandNorm = applyObjectiveScale(CandObj, Smodel.StructState);
        PopAggObj = zeros(size(PopObj, 1), numel(selected));
        CandAggObj = zeros(size(CandObj, 1), numel(selected));

        for ii = 1:numel(selected)
            g = selected(ii);
            C = groups{g}(:)';
            w = weights{g};
            if isempty(w)
                w = ones(1, numel(C)) ./ max(1, numel(C));
            end
            w = w(:);
            PopAggObj(:, ii) = PopNorm(:, C) * w;
            CandAggObj(:, ii) = CandNorm(:, C) * w;
        end
        return;
    end

    note = 'raw_easy_fallback';
    raw = Smodel.S_easy_raw(:)';
    [PopAggObj, lo, span] = safeMinMaxWithParam(PopObj(:, raw));
    CandAggObj = applyMinMax(CandObj(:, raw), lo, span);
end


function Xn = applyObjectiveScale(X, StructState)
    lo = StructState.ObjMin;
    span = StructState.ObjSpan;
    Xn = applyMinMax(X, lo, span);
end


function [Xn, lo, span] = safeMinMaxWithParam(X)
    X = double(X);
    [N, D] = size(X);
    Xn = zeros(N, D);
    lo = zeros(1, D);
    span = ones(1, D);
    for d = 1:D
        col = X(:, d);
        finite = isfinite(col);
        if any(finite)
            fill = median(col(finite));
            col(~finite) = fill;
            lo(d) = min(col);
            hi = max(col);
            sp = hi - lo(d);
            if sp > 1e-12
                span(d) = sp;
                Xn(:, d) = (col - lo(d)) ./ sp;
            end
        end
    end
end


function Xn = applyMinMax(X, lo, span)
    X = double(X);
    Xn = zeros(size(X));
    for d = 1:size(X, 2)
        col = X(:, d);
        finite = isfinite(col);
        if any(finite)
            fill = median(col(finite));
            col(~finite) = fill;
        else
            col(:) = lo(d);
        end
        sp = max(span(d), 1e-12);
        Xn(:, d) = (col - lo(d)) ./ sp;
    end
    Xn = min(max(Xn, 0), 1);
end


function y = numericColumn(x, n)
    if isempty(x)
        y = zeros(n, 1);
    else
        y = double(x(:));
        if numel(y) ~= n
            y = resizeColumn(y, n, 0);
        end
    end
end


function y = logicalColumn(x, n)
    if isempty(x)
        y = false(n, 1);
    else
        y = logical(x(:));
        if numel(y) ~= n
            y = logical(resizeColumn(double(y), n, 0));
        end
    end
end


function y = resizeColumn(x, n, fillValue)
    y = fillValue .* ones(n, 1);
    m = min(numel(x), n);
    if m > 0
        y(1:m) = x(1:m);
    end
end


function value = getField(S, name, defaultValue)
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        value = S.(name);
    else
        value = defaultValue;
    end
end

