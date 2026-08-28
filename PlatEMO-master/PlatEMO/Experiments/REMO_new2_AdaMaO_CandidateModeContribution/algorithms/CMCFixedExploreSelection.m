function [selected,retainedCount,augmented] = ...
        CMCFixedExploreSelection(candidates,finalScore,ambiguity,lambda, ...
        qKeep,K,useQ,useC,universe)
%CMCFIXEDEXPLORESELECTION Select and normalize inside one frozen pool.
%   Values outside UNIVERSE cannot affect scaling, retention, or selection.

    universe = logical(universe(:));
    if numel(universe) ~= size(candidates,1)
        error('CMC:ExploreUniverseMismatch', ...
            'Explore universe must match the candidate row count.');
    end
    augmented = zeros(size(finalScore(:)));
    if ~any(universe) || K < 1
        selected = zeros(0,1);
        retainedCount = 0;
        return;
    end
    augmented(universe) = norm01(finalScore(universe)) + ...
        lambda.*norm01(ambiguity(universe));
    retained = universe;
    if useQ
        threshold = quantile(augmented(universe),qKeep);
        retained = universe & augmented >= threshold;
    end
    retainedCount = nnz(retained);
    if retainedCount < K
        selected = topK(augmented,universe,K);
    elseif useC
        selected = diversitySelection( ...
            candidates,find(retained),augmented,K);
    else
        selected = topK(augmented,retained,K);
    end
end

function selected = topK(score,universe,K)
    index = find(universe);
    if isempty(index) || K < 1
        selected = zeros(0,1);
        return;
    end
    [~,order] = sort(score(index),'descend');
    selected = index(order(1:min(K,numel(order))));
end

function selected = diversitySelection(candidates,index,score,K)
    index = index(:);
    if isempty(index) || K < 1
        selected = zeros(0,1);
        return;
    end
    if numel(index) <= K
        [~,order] = sort(score(index),'descend');
        selected = index(order);
        return;
    end
    [~,first] = max(score(index));
    selected = index(first);
    remain = index;
    remain(first) = [];
    while numel(selected) < K && ~isempty(remain)
        distance = min(pdist2( ...
            candidates(remain,:),candidates(selected,:)),[],2);
        acquisition = 0.75.*norm01(score(remain)) + ...
            0.25.*norm01(distance);
        [~,best] = max(acquisition);
        selected(end+1,1) = remain(best); %#ok<AGROW>
        remain(best) = [];
    end
end

function scaled = norm01(value)
    value = value(:);
    if isempty(value)
        scaled = value;
    elseif max(value)-min(value) < 1e-12
        scaled = 0.5.*ones(size(value));
    else
        scaled = (value-min(value))./(max(value)-min(value));
    end
end
