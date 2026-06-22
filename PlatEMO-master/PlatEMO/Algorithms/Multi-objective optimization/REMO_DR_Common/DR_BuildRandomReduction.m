function State = DR_BuildRandomReduction(PopObj, k_red)
% DR_BuildRandomReduction - Build one fixed random objective grouping.

    if isvector(PopObj)
        PopObj = PopObj(:);
    end
    M = size(PopObj, 2);
    k_eff = max(1, min(round(k_red), M));

    perm = randperm(M);
    Groups = cell(1, k_eff);
    for i = 1:M
        g = mod(i - 1, k_eff) + 1;
        Groups{g}(end+1) = perm(i); %#ok<AGROW>
    end
    Groups = sortGroups(Groups);

    State = makeState(PopObj, Groups, 'RandFixed', true);
end


function State = makeState(PopObj, Groups, method, isFixed)
    [AggregatedObj, GroupWeights, GroupReliability] = aggregateByGroups(PopObj, Groups);

    State = struct();
    State.Method = method;
    State.IsFixed = isFixed;
    State.Groups = Groups;
    State.GroupWeights = GroupWeights;
    State.GroupReliability = GroupReliability;
    State.AggregatedObj = AggregatedObj;
    State.Sim = eye(size(PopObj, 2));
    State.Gamma = [];
    State.ClusterK = numel(Groups);
    State.Note = 'Random fixed equal-size objective grouping.';
end


function [AggregatedObj, GroupWeights, GroupReliability] = aggregateByGroups(PopObj, Groups)
    F = safeMinMaxLocal(PopObj);
    N = size(F, 1);
    K = numel(Groups);
    AggregatedObj = zeros(N, K);
    GroupWeights = cell(1, K);
    GroupReliability = ones(1, K);

    for g = 1:K
        C = Groups{g}(:)';
        w = ones(1, numel(C)) ./ max(1, numel(C));
        GroupWeights{g} = w;
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


function Groups = sortGroups(Groups)
    firstIdx = zeros(1, numel(Groups));
    for i = 1:numel(Groups)
        Groups{i} = sort(unique(Groups{i}(:)'));
        firstIdx(i) = min(Groups{i});
    end
    [~, ord] = sort(firstIdx, 'ascend');
    Groups = Groups(ord);
end
