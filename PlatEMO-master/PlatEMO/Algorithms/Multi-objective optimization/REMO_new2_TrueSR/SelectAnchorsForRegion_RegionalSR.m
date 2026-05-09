function anchorIndex = SelectAnchorsForRegion_RegionalSR(score,pool,anchorNum)
% Select anchors covering high, middle, and low local rankings.

    pool = pool(:);
    if isempty(pool)
        anchorIndex = [];
        return;
    end
    [~,order] = sort(score(pool),'descend');
    pool = pool(order);
    rankPos = unique(round(linspace(1,numel(pool),min(anchorNum,numel(pool)))));
    anchorIndex = pool(rankPos);
end
