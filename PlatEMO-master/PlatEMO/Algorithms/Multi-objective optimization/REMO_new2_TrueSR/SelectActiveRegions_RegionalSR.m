function activeRegions = SelectActiveRegions_RegionalSR(region,maxRegions)
% Select active reference regions by sample count.

    activeRegions = unique(region(:))';
    if isempty(activeRegions)
        return;
    end
    counts = zeros(size(activeRegions));
    for i = 1:numel(activeRegions)
        counts(i) = sum(region == activeRegions(i));
    end
    [~,order] = sort(counts,'descend');
    activeRegions = activeRegions(order);
    activeRegions = activeRegions(1:min(maxRegions,numel(activeRegions)));
end
