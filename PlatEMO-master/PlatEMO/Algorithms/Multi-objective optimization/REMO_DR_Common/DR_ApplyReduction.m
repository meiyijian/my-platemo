function [ReducedObj, State] = DR_ApplyReduction(PopObj, State)
% DR_ApplyReduction - Apply locked objective groups and weights to PopObj.

    if isvector(PopObj)
        PopObj = PopObj(:);
    end
    if isempty(State) || ~isfield(State, 'Groups') || isempty(State.Groups)
        error('DR_ApplyReduction:InvalidState', 'Reduction state must contain non-empty Groups.');
    end

    M = size(PopObj, 2);
    Groups = State.Groups;
    F = safeMinMaxLocal(PopObj);
    K = numel(Groups);
    ReducedObj = zeros(size(F, 1), K);

    if ~isfield(State, 'GroupWeights') || numel(State.GroupWeights) ~= K
        State.GroupWeights = cell(1, K);
    end

    for g = 1:K
        C = Groups{g}(:)';
        C = C(C >= 1 & C <= M);
        if isempty(C)
            error('DR_ApplyReduction:EmptyGroup', 'Each objective group must contain at least one valid objective.');
        end

        w = State.GroupWeights{g};
        if isempty(w) || numel(w) ~= numel(C) || any(~isfinite(w)) || sum(w) <= 0
            w = ones(1, numel(C)) ./ numel(C);
            State.GroupWeights{g} = w;
        else
            w = w(:)' ./ sum(w);
            State.GroupWeights{g} = w;
        end
        ReducedObj(:, g) = F(:, C) * w(:);
    end

    State.AggregatedObj = ReducedObj;
end


function Xn = safeMinMaxLocal(X)
    X = double(X);
    [N, D] = size(X);
    Xn = zeros(N, D);
    for d = 1:D
        col = X(:, d);
        finite = isfinite(col);
        if any(finite)
            fill = median(col(finite));
            col(~finite) = fill;
            lo = min(col);
            hi = max(col);
            sp = hi - lo;
            if sp > 1e-12
                Xn(:, d) = (col - lo) ./ sp;
            end
        end
    end
end
