function [utility,baselineIGDp,referenceCount,baselineDistance,candidateDistance] = ...
    ComputeMarginalIGDp(archiveObj,candidateObj,referenceObj)
%ComputeMarginalIGDp - Candidate-wise IGD+ reduction for minimization.
%
% The returned distance matrix has one row per reference point and one
% column per candidate. No SOLUTION objects or official evaluations are
% created by this helper.

    if ~validMatrix(archiveObj) || isempty(archiveObj) || ...
            ~validMatrix(candidateObj) || ...
            ~validMatrix(referenceObj) || isempty(referenceObj) || ...
            size(archiveObj,2) ~= size(referenceObj,2) || ...
            size(candidateObj,2) ~= size(referenceObj,2)
        error('AdaMaO:InvalidCascadeIGDpInputs', ...
            ['Archive, candidates, and reference points must be finite ', ...
            'real matrices with compatible objective dimensions; the ', ...
            'archive and reference set must be nonempty.']);
    end

    referenceCount = size(referenceObj,1);
    baselineDistance = inf(referenceCount,1);
    for i = 1:size(archiveObj,1)
        delta = max(archiveObj(i,:) - referenceObj,0);
        baselineDistance = min(baselineDistance, ...
            sqrt(sum(delta.^2,2)));
    end
    baselineIGDp = mean(baselineDistance);

    candidateCount = size(candidateObj,1);
    candidateDistance = zeros(referenceCount,candidateCount);
    utility = zeros(candidateCount,1);
    for first = 1:256:candidateCount
        last = min(first+255,candidateCount);
        block = candidateObj(first:last,:);
        squaredDistance = zeros(referenceCount,size(block,1));
        for objective = 1:size(block,2)
            shifted = max(block(:,objective)' - ...
                referenceObj(:,objective),0);
            squaredDistance = squaredDistance + shifted.^2;
        end
        blockDistance = sqrt(squaredDistance);
        candidateDistance(:,first:last) = blockDistance;
        gain = max(baselineDistance-blockDistance,0);
        utility(first:last) = mean(gain,1)';
    end
    utility = max(utility,0);
end

function valid = validMatrix(value)
    valid = isnumeric(value) && isreal(value) && ismatrix(value) && ...
        all(isfinite(value(:)));
end
