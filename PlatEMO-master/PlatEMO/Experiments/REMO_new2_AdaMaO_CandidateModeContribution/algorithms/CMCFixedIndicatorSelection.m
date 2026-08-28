function [selected,retainedCount,operational] = ...
        CMCFixedIndicatorSelection( ...
        Smodel,candidates,simpleScore,K,shuffle,universe)
%CMCFIXEDINDICATORSELECTION Select within one explicitly frozen pool.

    if nargin < 6 || isempty(universe)
        universe = true(size(candidates,1),1);
    end
    universe = logical(universe(:));
    if numel(universe) ~= size(candidates,1)
        error('CMC:IndicatorUniverseMismatch', ...
            'Indicator universe must match the candidate row count.');
    end
    eligible = find(universe);
    keep = min(numel(eligible),max(20,ceil(0.30*numel(eligible))));
    coarse = topK(simpleScore,universe,keep);
    indicatorScore = simpleScore(coarse);
    operational = false;
    if ~isempty(Smodel.IndicatorModel)
        try
            prediction = predict(Smodel.IndicatorModel,candidates(coarse,:));
            if all(isfinite(prediction))
                indicatorScore = prediction;
                operational = true;
            end
        catch
        end
    end
    if shuffle && operational
        seed = double(Smodel.RandomControlSeed) + ...
            1009*double(Smodel.Generation) + 91;
        stream = RandStream('mt19937ar','Seed',mod(seed,2^32-1));
        indicatorScore = indicatorScore( ...
            randperm(stream,numel(indicatorScore)));
    end
    retainedCount = numel(coarse);
    local = topK(indicatorScore,true(numel(indicatorScore),1), ...
        min(K,numel(indicatorScore)));
    selected = coarse(local);
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
