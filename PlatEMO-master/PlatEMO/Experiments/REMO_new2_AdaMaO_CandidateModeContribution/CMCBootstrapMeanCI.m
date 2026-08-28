function [lower,upper,replicates] = CMCBootstrapMeanCI( ...
        values,groups,repetitions,seed)
%CMCBOOTSTRAPMEANCI Hierarchical group-then-observation bootstrap mean CI.

    values = values(:);
    groups = string(groups(:));
    valid = isfinite(values) & ~ismissing(groups);
    values = values(valid);
    groups = groups(valid);
    if isempty(values)
        lower = NaN; upper = NaN; replicates = NaN(0,1); return;
    end
    uniqueGroups = unique(groups,'stable');
    stream = RandStream('mt19937ar','Seed',mod(double(seed),2^32-1));
    if numel(uniqueGroups) == numel(values)
        sampled = randi(stream,numel(values),numel(values),repetitions);
        replicates = mean(values(sampled),1)';
        limits = prctile(replicates,[2.5 97.5]);
        lower = limits(1); upper = limits(2);
        return;
    end
    replicates = NaN(repetitions,1);
    for repetition = 1:repetitions
        sampledGroups = uniqueGroups(randi(stream,numel(uniqueGroups), ...
            numel(uniqueGroups),1));
        groupMeans = NaN(numel(sampledGroups),1);
        for groupIndex = 1:numel(sampledGroups)
            within = values(groups == sampledGroups(groupIndex));
            sampled = within(randi(stream,numel(within),numel(within),1));
            groupMeans(groupIndex) = mean(sampled);
        end
        replicates(repetition) = mean(groupMeans);
    end
    limits = prctile(replicates,[2.5 97.5]);
    lower = limits(1); upper = limits(2);
end
