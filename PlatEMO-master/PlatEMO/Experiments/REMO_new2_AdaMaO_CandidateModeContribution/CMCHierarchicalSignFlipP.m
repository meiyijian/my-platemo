function pValue = CMCHierarchicalSignFlipP( ...
        values,groups,repetitions,seed)
%CMCHIERARCHICALSIGNFLIPP Monte Carlo one-sided paired sign-flip test.
%   The statistic gives every Problem-M group equal weight and every run
%   within a group equal weight. Negative values favor A00_FULL.

    values = values(:);
    groups = string(groups(:));
    valid = isfinite(values) & ~ismissing(groups);
    values = values(valid);
    groups = groups(valid);
    if isempty(values)
        pValue = NaN;
        return;
    end
    [groupIndex,groupNames] = findgroups(groups); %#ok<ASGLU>
    groupCounts = accumarray(groupIndex,1);
    weights = 1./(numel(groupCounts).*groupCounts(groupIndex));
    observed = sum(weights.*values);
    stream = RandStream('mt19937ar','Seed',mod(double(seed),2^32-1));
    moreExtreme = 0;
    completed = 0;
    chunkSize = 1000;
    while completed < repetitions
        count = min(chunkSize,repetitions-completed);
        signs = 2.*(rand(stream,numel(values),count) >= 0.5)-1;
        nullStatistic = (weights.*values)'*signs;
        moreExtreme = moreExtreme + nnz(nullStatistic <= observed);
        completed = completed + count;
    end
    pValue = (moreExtreme+1)/(repetitions+1);
end
