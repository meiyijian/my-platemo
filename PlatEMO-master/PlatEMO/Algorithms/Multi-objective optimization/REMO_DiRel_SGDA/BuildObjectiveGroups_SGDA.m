function [Groups, GroupInfo] = BuildObjectiveGroups_SGDA(PopDec, PopObj, d_score, cfg)
% BuildObjectiveGroups_SGDA - Structure-guided objective grouping.
%
% The function uses only already evaluated decision/objective samples. It
% estimates a local response signature Gamma for each objective and merges
% only objectives with strong positive trend similarity. Strong negative
% correlation is treated as conflict and is never used as redundancy.

    if nargin < 4 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'maxPairs', 400);
    cfg = setIfMissing(cfg, 'neighborK', 5);
    cfg = setIfMissing(cfg, 'neighborRatio', 0.70);
    cfg = setIfMissing(cfg, 'simMethod', 'Spearman');
    cfg = setIfMissing(cfg, 'simThreshold', 0.65);
    cfg = setIfMissing(cfg, 'minGroupReliability', 0.35);
    cfg = setIfMissing(cfg, 'diffStdLimit', 0.25);
    cfg = setIfMissing(cfg, 'easyQuantile', 0.50);
    cfg = setIfMissing(cfg, 'easyReliabilityThr', 0.45);

    [N, M] = size(PopObj);
    if isempty(d_score)
        d_score = zeros(M, 1);
    end
    d_score = d_score(:);
    if numel(d_score) ~= M
        d_score = resizeDifficulty(d_score, M);
    end

    if M == 0
        Groups = {};
        GroupInfo = emptyInfo(M);
        return;
    end
    if M == 1 || N < 3
        Groups = num2cell(1:M);
        GroupInfo = buildInfo(Groups, eye(M), zeros(M, 0), d_score, ones(1, M), cfg);
        return;
    end

    Xn = normalizeCols(PopDec);
    Fn = normalizeCols(PopObj);

    pairs = samplePairs(Xn, cfg);
    if isempty(pairs)
        Groups = num2cell(1:M);
        GroupInfo = buildInfo(Groups, eye(M), zeros(M, 0), d_score, ones(1, M), cfg);
        return;
    end

    Gamma = buildGamma(Xn, Fn, pairs);
    similarity = objectiveSimilarity(Gamma, cfg.simMethod);

    % Positive-only graph. Do not use abs(similarity): negative edges mean
    % objectives move in opposite local directions and should not be merged.
    A = similarity >= cfg.simThreshold;
    A(1:M+1:end) = false;

    Groups = connectedComponents(A);
    Groups = refineLowReliabilityGroups(Groups, similarity, d_score, cfg);
    if isempty(Groups)
        Groups = num2cell(1:M);
    end

    pairReliability = min(1, size(pairs, 1) / max(30, 5*M));
    GroupInfo = buildInfo(Groups, similarity, Gamma, d_score, pairReliability, cfg);
    GroupInfo.pairs = pairs;
end

function pairs = samplePairs(Xn, cfg)
    N = size(Xn, 1);
    maxPairs = min(cfg.maxPairs, N*(N-1)/2);
    if maxPairs <= 0
        pairs = zeros(0, 2);
        return;
    end

    nearBudget = round(maxPairs * cfg.neighborRatio);
    rndBudget  = maxPairs - nearBudget;

    pairs = zeros(0, 2);
    try
        Dmat = pdist2(Xn, Xn);
        Dmat(1:N+1:end) = inf;
        k = min(cfg.neighborK, N-1);
        [~, ord] = sort(Dmat, 2, 'ascend');
        cand = zeros(N*k, 2);
        t = 0;
        for i = 1:N
            for kk = 1:k
                t = t + 1;
                cand(t, :) = [i, ord(i, kk)];
            end
        end
        if size(cand, 1) > nearBudget
            cand = cand(randperm(size(cand, 1), nearBudget), :);
        end
        pairs = [pairs; cand]; %#ok<AGROW>
    catch
        % Continue with random pairs if pdist2 is unavailable.
    end

    if rndBudget > 0
        ia = randi(N, rndBudget*2, 1);
        ib = randi(N, rndBudget*2, 1);
        keep = ia ~= ib;
        rnd = [ia(keep), ib(keep)];
        if size(rnd, 1) > rndBudget
            rnd = rnd(1:rndBudget, :);
        end
        pairs = [pairs; rnd]; %#ok<AGROW>
    end

    if isempty(pairs)
        return;
    end
    pairs = unique(pairs, 'rows', 'stable');
    if size(pairs, 1) > maxPairs
        pairs = pairs(1:maxPairs, :);
    end
end

function Gamma = buildGamma(Xn, Fn, pairs)
    M = size(Fn, 2);
    P = size(pairs, 1);
    Gamma = zeros(M, P);
    for p = 1:P
        a = pairs(p, 1);
        b = pairs(p, 2);
        dx = norm(Xn(a, :) - Xn(b, :)) + eps;
        Gamma(:, p) = (Fn(a, :) - Fn(b, :))' ./ dx;
    end
end

function S = objectiveSimilarity(Gamma, method)
    M = size(Gamma, 1);
    if size(Gamma, 2) < 3
        S = eye(M);
        return;
    end

    try
        S = corr(Gamma', 'type', method, 'rows', 'pairwise');
    catch
        S = corrcoef(Gamma');
    end
    if isempty(S) || any(size(S) ~= [M, M])
        S = eye(M);
    end
    S(isnan(S)) = 0;
    S = max(min(S, 1), -1);
    S(1:M+1:end) = 1;
end

function Groups = connectedComponents(A)
    M = size(A, 1);
    seen = false(1, M);
    Groups = {};
    for s = 1:M
        if seen(s), continue; end
        queue = s;
        seen(s) = true;
        comp = s;
        while ~isempty(queue)
            v = queue(1);
            queue(1) = [];
            nb = find(A(v, :) | A(:, v)');
            for u = nb
                if ~seen(u)
                    seen(u) = true;
                    queue(end+1) = u; %#ok<AGROW>
                    comp(end+1) = u; %#ok<AGROW>
                end
            end
        end
        Groups{end+1} = sort(comp); %#ok<AGROW>
    end
end

function Groups = refineLowReliabilityGroups(Groups, S, d_score, cfg)
    refined = {};
    for g = 1:numel(Groups)
        idx = Groups{g}(:)';
        if numel(idx) <= 1
            refined{end+1} = idx; %#ok<AGROW>
            continue;
        end
        simVals = upperTriVals(S(idx, idx));
        rel = mean(max(0, simVals));
        dStd = std(d_score(idx));
        if rel < cfg.minGroupReliability
            for j = idx
                refined{end+1} = j; %#ok<AGROW>
            end
        elseif dStd > 2 * cfg.diffStdLimit
            % Very mixed difficulty usually means the structural cluster is
            % not a reliable easy group; split conservatively.
            for j = idx
                refined{end+1} = j; %#ok<AGROW>
            end
        else
            refined{end+1} = idx; %#ok<AGROW>
        end
    end
    Groups = refined;
end

function GroupInfo = buildInfo(Groups, similarity, Gamma, d_score, pairReliability, cfg)
    K = numel(Groups);
    GroupInfo = struct();
    GroupInfo.similarity = similarity;
    GroupInfo.Gamma = Gamma;
    GroupInfo.groupDifficulty = zeros(1, K);
    GroupInfo.groupDifficultyStd = zeros(1, K);
    GroupInfo.groupReliability = zeros(1, K);
    GroupInfo.aggregatedWeights = cell(1, K);
    GroupInfo.isEasyGroup = false(1, K);
    GroupInfo.groupSizes = zeros(1, K);
    GroupInfo.groups = Groups;

    for k = 1:K
        idx = Groups{k}(:)';
        dk = d_score(idx);
        dStd = std(dk);
        GroupInfo.groupSizes(k) = numel(idx);
        GroupInfo.groupDifficulty(k) = mean(dk) + 0.5 * dStd;
        GroupInfo.groupDifficultyStd(k) = dStd;

        if numel(idx) <= 1
            simRel = 1;
        else
            simVals = upperTriVals(similarity(idx, idx));
            simRel = mean(max(0, simVals));
        end
        diffPenalty = max(0, 1 - dStd / max(cfg.diffStdLimit, 1e-12));
        GroupInfo.groupReliability(k) = min(1, pairReliability * (0.65*simRel + 0.35*diffPenalty));

        invD = 1 ./ max(dk(:)', 1e-6);
        GroupInfo.aggregatedWeights{k} = invD ./ max(sum(invD), 1e-12);
    end

    if K > 0
        easyThr = quantile(GroupInfo.groupDifficulty, cfg.easyQuantile);
        GroupInfo.isEasyGroup = GroupInfo.groupDifficulty <= easyThr & ...
                                GroupInfo.groupReliability >= cfg.easyReliabilityThr & ...
                                GroupInfo.groupDifficultyStd <= cfg.diffStdLimit;
    end
end

function info = emptyInfo(M)
    info = struct('similarity', eye(M), 'Gamma', [], ...
        'groupDifficulty', [], 'groupDifficultyStd', [], ...
        'groupReliability', [], 'aggregatedWeights', {{}}, ...
        'isEasyGroup', [], 'groupSizes', [], 'groups', {{}});
end

function Xn = normalizeCols(X)
    if isempty(X)
        Xn = X;
        return;
    end
    lo = min(X, [], 1);
    hi = max(X, [], 1);
    span = max(hi - lo, 1e-12);
    Xn = (X - lo) ./ span;
    Xn(~isfinite(Xn)) = 0;
end

function vals = upperTriVals(A)
    if size(A, 1) <= 1
        vals = 1;
        return;
    end
    mask = triu(true(size(A)), 1);
    vals = A(mask);
    if isempty(vals)
        vals = 1;
    end
end

function d = resizeDifficulty(d, M)
    if isempty(d)
        d = zeros(M, 1);
    elseif numel(d) < M
        d = [d(:); repmat(mean(d(:)), M-numel(d), 1)];
    else
        d = d(1:M);
    end
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
