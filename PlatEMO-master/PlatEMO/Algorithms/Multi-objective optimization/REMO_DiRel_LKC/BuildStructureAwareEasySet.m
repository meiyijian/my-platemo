function [S_easy_raw, S_easy_group, EasyAggObj, d_score, groupDifficulty, H, EasyInfo] = BuildStructureAwareEasySet(Population, H, gen, alpha, k_easy, StructState, cfg)
% BuildStructureAwareEasySet - Select easy aggregated objective groups.
%
% The original DifficultyProfiler still estimates raw-objective difficulty.
% LKC grouping then lifts raw difficulties to group difficulties and selects
% reliable, easy-to-model structural groups for the sub-network.

    if nargin < 7 || isempty(cfg)
        cfg = struct();
    end
    eta       = getCfg(cfg, 'eta', 0.5);
    minRel    = getCfg(cfg, 'minGroupReliability', 0.65);
    lambdaRel = getCfg(cfg, 'lambdaRel', 0.0);

    [d_score, H, S_easy_orig] = DifficultyProfiler(Population, H, gen, alpha, k_easy);
    S_easy_orig = unique(double(S_easy_orig(:)'), 'stable');

    Groups = StructState.Groups;
    K = numel(Groups);
    groupDifficulty = inf(1, K);
    groupVar = zeros(1, K);

    for g = 1:K
        C = Groups{g}(:)';
        C = C(C >= 1 & C <= numel(d_score));
        if isempty(C)
            continue;
        end
        vals = d_score(C);
        groupDifficulty(g) = mean(vals) + eta .* std(vals);
        groupVar(g) = var(vals);
    end

    reliability = StructState.GroupReliability;
    if isempty(reliability)
        reliability = zeros(1, K);
    end
    reliability = reliability(:)';

    valid = isfinite(groupDifficulty) & reliability >= minRel;
    if ~any(valid)
        [S_easy_raw, S_easy_group, EasyAggObj] = fallbackRawEasy(Population, StructState, S_easy_orig);
        EasyInfo = makeInfo(true, S_easy_orig, groupVar, reliability, eta, minRel);
        return;
    end

    groupScore = groupDifficulty ./ max(reliability, eps) - lambdaRel .* reliability;
    groupScore(~valid) = inf;
    [~, ord] = sort(groupScore, 'ascend');

    selected = [];
    rawCount = 0;
    for ii = 1:numel(ord)
        g = ord(ii);
        if ~isfinite(groupScore(g))
            continue;
        end
        selected(end+1) = g; %#ok<AGROW>
        rawCount = numel(unique([Groups{selected}], 'stable'));
        if rawCount >= k_easy
            break;
        end
    end

    if isempty(selected)
        [S_easy_raw, S_easy_group, EasyAggObj] = fallbackRawEasy(Population, StructState, S_easy_orig);
        EasyInfo = makeInfo(true, S_easy_orig, groupVar, reliability, eta, minRel);
        return;
    end

    S_easy_group = selected;
    S_easy_raw = unique([Groups{selected}], 'stable');
    EasyAggObj = StructState.AggregatedObj(:, selected);

    EasyInfo = makeInfo(false, S_easy_orig, groupVar, reliability, eta, minRel);
    EasyInfo.groupScore = groupScore;
end


function [S_easy_raw, S_easy_group, EasyAggObj] = fallbackRawEasy(Population, StructState, S_easy_orig)
    S_easy_raw = S_easy_orig;
    S_easy_group = [];

    if ~isempty(StructState.Groups)
        selected = [];
        for i = 1:numel(StructState.Groups)
            if any(ismember(StructState.Groups{i}, S_easy_raw))
                selected(end+1) = i; %#ok<AGROW>
            end
        end
        selected = unique(selected, 'stable');
        if ~isempty(selected) && ~isempty(StructState.AggregatedObj)
            S_easy_group = selected;
            EasyAggObj = StructState.AggregatedObj(:, selected);
            return;
        end
    end

    PopObj = Population.objs;
    [EasyAggObj, ~, ~] = safeMinMaxLocal(PopObj(:, S_easy_raw));
end


function EasyInfo = makeInfo(isFallback, S_easy_orig, groupVar, reliability, eta, minRel)
    EasyInfo = struct();
    EasyInfo.IsFallback = isFallback;
    EasyInfo.S_easy_original = S_easy_orig;
    EasyInfo.groupVariance = groupVar;
    EasyInfo.groupReliability = reliability;
    EasyInfo.eta = eta;
    EasyInfo.minGroupReliability = minRel;
    EasyInfo.groupScore = [];
end


function value = getCfg(cfg, name, defaultValue)
    if isstruct(cfg) && isfield(cfg, name) && ~isempty(cfg.(name))
        value = cfg.(name);
    else
        value = defaultValue;
    end
end


function [Xn, xmin, span] = safeMinMaxLocal(X)
    X = double(X);
    [N, D] = size(X);
    Xn = zeros(N, D);
    xmin = zeros(1, D);
    span = ones(1, D);
    for d = 1:D
        col = X(:, d);
        finite = isfinite(col);
        if any(finite)
            fill = median(col(finite));
            col(~finite) = fill;
            lo = min(col);
            hi = max(col);
            sp = hi - lo;
            xmin(d) = lo;
            if sp > 1e-12
                span(d) = sp;
                Xn(:, d) = (col - lo) ./ sp;
            end
        end
    end
end
