function [scores, dbg] = ScoreCandidates_SGDA(Candidates, Anchors, Experts, ArchiveDec, cfg)
% ScoreCandidates_SGDA - Full-first structure-guided relation arbitration.
%
% The last expert is the full-objective expert. Group experts are consulted
% only when the full expert is uncertain. Group outputs are local auxiliary
% preferences and never overwrite a confident full-objective judgment.

    if nargin < 5 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'fullMargin', 0.20);
    cfg = setIfMissing(cfg, 'fullConfThr', 0.55);
    cfg = setIfMissing(cfg, 'fullWeight', 1.00);
    cfg = setIfMissing(cfg, 'tieWeight', 0.50);
    cfg = setIfMissing(cfg, 'groupMargin', 0.15);
    cfg = setIfMissing(cfg, 'groupConfThr', 0.60);
    cfg = setIfMissing(cfg, 'minGroupReliability', 0.30);
    cfg = setIfMissing(cfg, 'easyBoost', 0.25);
    cfg = setIfMissing(cfg, 'beta', 0.10);
    cfg = setIfMissing(cfg, 'lambda', 0.25);
    cfg = setIfMissing(cfg, 'gamma', 0.15);
    cfg = setIfMissing(cfg, 'Lower', []);
    cfg = setIfMissing(cfg, 'Upper', []);
    cfg = setIfMissing(cfg, 'pairFeatureType', 'concat');

    nC = size(Candidates, 1);
    K = numel(Experts);
    if nC == 0
        scores = zeros(0, 1);
        dbg = emptyDbg(K, 0);
        return;
    end
    if K == 0
        scores = zeros(nC, 1);
        dbg = emptyDbg(0, nC);
        dbg.Nov = archiveNovelty(Candidates, ArchiveDec, cfg.Lower, cfg.Upper);
        dbg.fusedScore = cfg.gamma * dbg.Nov;
        scores = dbg.fusedScore;
        return;
    end

    fullIdx = K;
    anchorDec = [getAnchorField(Anchors, 'elite'); getAnchorField(Anchors, 'diverse')];
    eliteFlag = [true(size(getAnchorField(Anchors, 'elite'), 1), 1); ...
                 false(size(getAnchorField(Anchors, 'diverse'), 1), 1)];

    R = zeros(nC, K);
    Uper = ones(nC, K);
    Conf = zeros(nC, K);
    globalRel = zeros(1, K);
    validMask = false(1, K);

    for k = 1:K
        validMask(k) = getFieldDefault(Experts(k), 'valid', false);
        if ~validMask(k)
            continue;
        end
        globalRel(k) = max(0, 1 - getFieldDefault(Experts(k), 'valError', 1));
        [R(:, k), Uper(:, k), Conf(:, k)] = expertScoreSGDA( ...
            Candidates, anchorDec, eliteFlag, Experts(k), cfg);
    end

    if validMask(fullIdx)
        Rfull = R(:, fullIdx);
        Ufull = Uper(:, fullIdx);
        Cfull = Conf(:, fullIdx);
    else
        Rfull = zeros(nC, 1);
        Ufull = ones(nC, 1);
        Cfull = zeros(nC, 1);
    end

    fullCertain = validMask(fullIdx) & ...
        abs(Rfull) >= cfg.fullMargin & Cfull >= cfg.fullConfThr;
    tieTriggered = ~fullCertain;

    [Raux, Uaux, groupConflict, groupAccepted, groupWeight] = ...
        auxiliaryGroupPreference(R, Uper, Conf, Experts, validMask, fullIdx, globalRel, cfg);

    hasAux = any(groupAccepted, 2) & ~groupConflict;
    fullAuxOppose = hasAux & sign(Rfull) .* sign(Raux) < 0;
    disagreement = double(groupConflict);
    disagreement = disagreement + 0.5 * double(fullAuxOppose) .* min(abs(Rfull), abs(Raux));
    disagreement = min(1, disagreement);

    Nov = archiveNovelty(Candidates, ArchiveDec, cfg.Lower, cfg.Upper);
    uncertainty = Ufull;
    uncertainty(tieTriggered) = 0.7*Ufull(tieTriggered) + 0.3*Uaux(tieTriggered);

    fullOnly = cfg.fullWeight * Rfull - cfg.beta * Ufull + cfg.gamma * Nov;
    groupOnly = cfg.tieWeight * Raux - cfg.beta * Uaux - cfg.lambda * disagreement + cfg.gamma * Nov;

    scores = cfg.fullWeight * Rfull - cfg.beta * uncertainty + cfg.gamma * Nov;
    scores(tieTriggered) = scores(tieTriggered) + ...
        cfg.tieWeight * Raux(tieTriggered) - cfg.lambda * disagreement(tieTriggered);

    mode = zeros(nC, 1);       % 0 = uncertainty/novelty, 1 = full, 2 = group tie-break
    mode(fullCertain) = 1;
    mode(tieTriggered & hasAux) = 2;

    dbg = struct();
    dbg.R = R;
    dbg.U_perExp = Uper;
    dbg.localConf = Conf;
    dbg.globalRel = globalRel;
    dbg.validMask = validMask;
    dbg.R_full = Rfull;
    dbg.Conf_full = Cfull;
    dbg.U_full = Ufull;
    dbg.fullCertain = fullCertain;
    dbg.fullUncertain = ~fullCertain;
    dbg.tieTriggered = tieTriggered;
    dbg.tieActive = tieTriggered & hasAux;
    dbg.R_aux = Raux;
    dbg.U_aux = Uaux;
    dbg.groupAccepted = groupAccepted;
    dbg.groupWeight = groupWeight;
    dbg.groupConflict = groupConflict;
    dbg.Disagreement = disagreement;
    dbg.Nov = Nov;
    dbg.uncertainty = uncertainty;
    dbg.mode = mode;
    dbg.fullOnlyScore = fullOnly;
    dbg.groupOnlyScore = groupOnly;
    dbg.fusedScore = scores;
end

function [Raux, Uaux, conflict, accepted, W] = auxiliaryGroupPreference( ...
    R, Uper, Conf, Experts, validMask, fullIdx, globalRel, cfg)

    nC = size(R, 1);
    K = size(R, 2);
    groupIdx = setdiff(1:K, fullIdx);
    accepted = false(nC, K);
    W = zeros(nC, K);

    for k = groupIdx
        if ~validMask(k), continue; end
        rel = getFieldDefault(Experts(k), 'groupReliability', 0.5);
        if rel < cfg.minGroupReliability
            continue;
        end
        isEasy = getFieldDefault(Experts(k), 'isEasyGroup', false);
        boost = 1 + cfg.easyBoost * double(isEasy);
        ok = abs(R(:, k)) >= cfg.groupMargin & Conf(:, k) >= cfg.groupConfThr;
        accepted(:, k) = ok;
        W(:, k) = ok .* globalRel(k) .* Conf(:, k) .* rel .* boost;
    end

    Raux = zeros(nC, 1);
    Uaux = ones(nC, 1);
    conflict = false(nC, 1);
    for i = 1:nC
        idx = find(accepted(i, :));
        if isempty(idx)
            continue;
        end
        pos = idx(R(i, idx) > 0);
        neg = idx(R(i, idx) < 0);
        if ~isempty(pos) && ~isempty(neg)
            conflict(i) = true;
            continue;
        end
        wi = W(i, idx);
        if sum(wi) < 1e-12
            continue;
        end
        wi = wi ./ sum(wi);
        Raux(i) = sum(wi .* R(i, idx));
        Uaux(i) = sum(wi .* Uper(i, idx));
    end
end

function [R, U, conf] = expertScoreSGDA(Cand, Anc, eliteFlag, expert, cfg)
    nC = size(Cand, 1);

    if isfield(expert, 'mockR') && ~isempty(expert.mockR)
        R = expandMock(expert.mockR, nC, 0);
        U = expandMock(getFieldDefault(expert, 'mockU', 0.2), nC, 0.2);
        conf = expandMock(getFieldDefault(expert, 'mockConf', 0.8), nC, 0.8);
        return;
    end

    nets = getFieldDefault(expert, 'nets', {});
    if isempty(nets) || isempty(Anc)
        R = zeros(nC, 1);
        U = ones(nC, 1);
        conf = zeros(nC, 1);
        return;
    end
    valid = ~cellfun(@isempty, nets);
    nets = nets(valid);
    if isempty(nets)
        R = zeros(nC, 1);
        U = ones(nC, 1);
        conf = zeros(nC, 1);
        return;
    end

    nA = size(Anc, 1);
    D = size(Cand, 2);
    pairXA = zeros(nC*nA, 2*D);
    pairAX = zeros(nC*nA, 2*D);
    for i = 1:nC
        rows = (i-1)*nA + (1:nA);
        Xi = repmat(Cand(i, :), nA, 1);
        pairXA(rows, :) = [Xi, Anc];
        pairAX(rows, :) = [Anc, Xi];
    end

    mp = getFieldDefault(expert, 'mp_struct', []);
    try
        Pxa = mapminmax('apply', pairXA', mp)';
        Pax = mapminmax('apply', pairAX', mp)';
    catch
        R = zeros(nC, 1);
        U = ones(nC, 1);
        conf = zeros(nC, 1);
        return;
    end

    avgMargin = zeros(nC*nA, 1);
    RperNet = zeros(nC, numel(nets));
    goodCols = false(1, numel(nets));
    nGood = 0;
    eliteFlag = eliteFlag(:)';
    anchorWeight = ones(1, nA);
    anchorWeight(~eliteFlag) = 0.5;
    anchorWeight = anchorWeight ./ max(sum(anchorWeight), 1e-12);

    for kk = 1:numel(nets)
        try
            outXA = normalizeProb(nets{kk}(Pxa')');
            outAX = normalizeProb(nets{kk}(Pax')');
        catch
            continue;
        end
        pXwinA = 0.5*outXA(:, 1) + 0.5*outAX(:, 3);
        pAwinX = 0.5*outXA(:, 3) + 0.5*outAX(:, 1);
        margin = pXwinA - pAwinX;
        avgMargin = avgMargin + margin;
        M = reshape(margin, nA, nC)';
        RperNet(:, kk) = M * anchorWeight(:);
        goodCols(kk) = true;
        nGood = nGood + 1;
    end

    if nGood == 0
        R = zeros(nC, 1);
        U = ones(nC, 1);
        conf = zeros(nC, 1);
        return;
    end

    avgMargin = avgMargin / nGood;
    Mavg = reshape(avgMargin, nA, nC)';
    R = Mavg * anchorWeight(:);
    conf = abs(Mavg) * anchorWeight(:);
    conf = min(1, conf);

    varAnchor = var(Mavg, 0, 2);
    if nGood >= 2
        varEns = var(RperNet(:, goodCols), 0, 2);
    else
        varEns = zeros(nC, 1);
    end
    U = 0.5*varAnchor + 0.5*varEns;
    U = U ./ max(max(U), 1e-12);
end

function P = normalizeProb(P)
    P = max(P, 0);
    s = sum(P, 2);
    s(s < 1e-12) = 1;
    P = P ./ s;
end

function Nov = archiveNovelty(Cand, Arch, Lower, Upper)
    if isempty(Arch)
        Nov = ones(size(Cand, 1), 1);
        return;
    end
    if isempty(Lower) || isempty(Upper)
        Lower = quantile(Arch, 0.05, 1);
        Upper = quantile(Arch, 0.95, 1);
    end
    span = max(Upper - Lower, 1e-12);
    Cn = (Cand - Lower) ./ span;
    An = (Arch - Lower) ./ span;
    nC = size(Cn, 1);
    Nov = zeros(nC, 1);
    block = 500;
    for s = 1:block:nC
        e = min(nC, s+block-1);
        Dmat = pdist2(Cn(s:e, :), An);
        Nov(s:e) = min(Dmat, [], 2);
    end
    Nov = Nov ./ max(max(Nov), 1e-12);
end

function A = getAnchorField(Anchors, name)
    if isstruct(Anchors) && isfield(Anchors, name) && ~isempty(Anchors.(name))
        A = Anchors.(name);
    else
        A = [];
    end
end

function val = getFieldDefault(s, name, defaultVal)
    if isstruct(s) && isfield(s, name) && ~isempty(s.(name))
        val = s.(name);
    else
        val = defaultVal;
    end
end

function v = expandMock(v, n, defaultVal)
    if isempty(v)
        v = defaultVal;
    end
    if isscalar(v)
        v = repmat(v, n, 1);
    else
        v = v(:);
        if numel(v) < n
            v = [v; repmat(v(end), n-numel(v), 1)];
        else
            v = v(1:n);
        end
    end
end

function dbg = emptyDbg(K, nC)
    dbg = struct('R', zeros(nC, K), 'U_perExp', zeros(nC, K), ...
        'localConf', zeros(nC, K), 'globalRel', zeros(1, K), ...
        'validMask', false(1, K), 'R_full', zeros(nC, 1), ...
        'Conf_full', zeros(nC, 1), 'U_full', ones(nC, 1), ...
        'fullCertain', false(nC, 1), 'fullUncertain', true(nC, 1), ...
        'tieTriggered', true(nC, 1), 'tieActive', false(nC, 1), ...
        'R_aux', zeros(nC, 1), 'U_aux', ones(nC, 1), ...
        'groupAccepted', false(nC, K), 'groupWeight', zeros(nC, K), ...
        'groupConflict', false(nC, 1), 'Disagreement', zeros(nC, 1), ...
        'Nov', zeros(nC, 1), 'uncertainty', ones(nC, 1), ...
        'mode', zeros(nC, 1), 'fullOnlyScore', zeros(nC, 1), ...
        'groupOnlyScore', zeros(nC, 1), 'fusedScore', zeros(nC, 1));
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
