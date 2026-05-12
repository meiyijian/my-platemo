function Next = SelectTopByRegion_RegionalSR(Candidate,scores,bestRegion,maxNum)
% Pick high-score candidates while avoiding too many from the same region.

    if isempty(Candidate)
        Next = Candidate;
        return;
    end

    selected = false(size(scores));
    regions = unique(bestRegion(:))';
    for r = regions
        ind = find(bestRegion == r);
        [~,best] = max(scores(ind));
        selected(ind(best)) = true;
    end

    chosen = find(selected);
    [~,order] = sort(scores(chosen),'descend');
    chosen = chosen(order);

    if numel(chosen) < maxNum
        [~,globalOrder] = sort(scores,'descend');
        for i = 1:numel(globalOrder)
            if ~ismember(globalOrder(i),chosen)
                chosen(end+1) = globalOrder(i); %#ok<AGROW>
            end
            if numel(chosen) >= maxNum
                break;
            end
        end
    end

    chosen = chosen(1:min(maxNum,numel(chosen)));
    Next = Candidate(chosen,:);
end
