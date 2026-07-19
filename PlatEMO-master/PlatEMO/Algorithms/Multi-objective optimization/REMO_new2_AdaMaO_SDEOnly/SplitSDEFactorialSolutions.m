function [trainIdx,valIdx] = ...
    SplitSDEFactorialSolutions(Input,runId,generation)
%SplitSDEFactorialSolutions Split unique decision rows without RNG leakage.
%   The 3/4--1/4 split inherits the legacy DataProcess validation protocol;
%   it is fixed for causal compatibility and is not an algorithm parameter.

    if ~isnumeric(Input) || ~isreal(Input) || ~ismatrix(Input) || ...
            any(~isfinite(Input(:)))
        error('AdaMaO:InvalidSolutionSplitInput', ...
            'Input must be a finite numeric matrix.');
    end
    [~,~,group] = unique(Input,'rows');
    groupCount = max([group;0]);
    if groupCount < 4
        trainIdx = (1:size(Input,1))';
        valIdx = zeros(0,1);
        return;
    end

    validationCount = min(groupCount-2,max(2,round(0.25*groupCount)));
    seed = MakeSDEFactorialSeed(runId,generation,0,'split');
    stream = RandStream('mt19937ar','Seed',double(seed));
    groupOrder = randperm(stream,groupCount);
    validationGroups = groupOrder(1:validationCount);

    isValidation = ismember(group,validationGroups);
    trainIdx = find(~isValidation);
    valIdx = find(isValidation);
end
