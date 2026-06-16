function [AggregatedObj, GroupWeights, GroupReliability] = AggregateObjectives_LKC(PopObj, StructState)
% AggregateObjectives_LKC - Aggregate normalized objectives by LKC groups.

    if isempty(PopObj) || isempty(StructState) || ~isfield(StructState, 'Groups')
        AggregatedObj = [];
        GroupWeights = {};
        GroupReliability = [];
        return;
    end

    F = safeMinMaxLocal(PopObj);
    Groups = StructState.Groups;
    Gamma = StructState.Gamma;
    Sim = StructState.Sim;

    K = numel(Groups);
    AggregatedObj = zeros(size(F, 1), K);
    GroupWeights = cell(1, K);
    GroupReliability = ones(1, K);
    Z = normalizeRows(centerRows(Gamma));

    for g = 1:K
        C = Groups{g}(:)';
        if numel(C) == 1
            w = 1;
            rel = 1;
        else
            rel = mean(pairwiseValues(Sim, C));
            center = mean(Z(C, :), 1);
            dist = sqrt(sum(bsxfun(@minus, Z(C, :), center).^2, 2));
            w = exp(-dist(:)');
            w = w ./ max(sum(w), eps);
        end
        GroupWeights{g} = w;
        GroupReliability(g) = rel;
        AggregatedObj(:, g) = F(:, C) * w(:);
    end
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


function B = centerRows(A)
    B = bsxfun(@minus, A, mean(A, 2));
end


function Z = normalizeRows(A)
    n = sqrt(sum(A.^2, 2));
    Z = A;
    ok = n > 1e-12;
    Z(ok, :) = bsxfun(@rdivide, A(ok, :), n(ok));
    Z(~ok, :) = 0;
end


function vals = pairwiseValues(Sim, C)
    vals = [];
    for i = 1:numel(C)
        for j = i+1:numel(C)
            vals(end+1) = Sim(C(i), C(j)); %#ok<AGROW>
        end
    end
    if isempty(vals)
        vals = 1;
    end
end
