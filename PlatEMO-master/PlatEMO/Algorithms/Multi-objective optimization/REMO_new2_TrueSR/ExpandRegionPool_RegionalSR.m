function pool = ExpandRegionPool_RegionalSR(region,W,r,neighborNum,minSamples)
% Get samples in region r, expanding to nearest reference-vector neighbors
% until enough evaluated samples are available.

    if nargin < 5
        minSamples = 2;
    end
    pool = find(region == r);
    if numel(pool) >= minSamples
        return;
    end

    cosWR = min(max(W*W(r,:)',-1),1);
    [~,order] = sort(real(acos(cosWR)),'ascend');
    maxTake = min(numel(order),neighborNum + 1);
    for i = 1:maxTake
        pool = unique([pool;find(region == order(i))]); %#ok<AGROW>
        if numel(pool) >= minSamples
            return;
        end
    end

    if numel(pool) < minSamples
        pool = unique([pool;(1:numel(region))']);
    end
end
