function [ind,scores,uncertainty] = ...
    ScoreSDEFactorialCandidates(model,Candidates,Anchors,aggregationMode)
%ScoreSDEFactorialCandidates Rank candidates against all evaluated anchors.

    if nargin < 4 || isempty(aggregationMode)
        aggregationMode = 'expected';
    end
    aggregationMode = validateAggregationMode(aggregationMode);
    validateCandidateInputs(Candidates,Anchors);
    candidateCount = size(Candidates,1);
    anchorCount = size(Anchors,1);
    scores = 0.5.*ones(candidateCount,1);
    uncertainty = ones(candidateCount,1);

    if anchorCount > 0 && candidateCount > 0
        blockSize = candidateBlockSize( ...
            candidateCount,anchorCount,size(Candidates,2));
        for first = 1:blockSize:candidateCount
            last = min(candidateCount,first+blockSize-1);
            blockIndex = first:last;
            blockCount = numel(blockIndex);
            query = repelem(Candidates(blockIndex,:),anchorCount,1);
            anchorBlock = repmat(Anchors,blockCount,1);
            [pairPreference,pairAmbiguity] = ...
                PredictSDEFactorialPreference(model,query,anchorBlock);
            if strcmp(aggregationMode,'hard_vote')
                contribution = 0.5.*ones(size(pairPreference));
                contribution(pairPreference > 0.5) = 1;
                contribution(pairPreference < 0.5) = 0;
            else
                contribution = pairPreference;
            end
            contribution = reshape(contribution,anchorCount,blockCount);
            pairAmbiguity = reshape(pairAmbiguity,anchorCount,blockCount);
            scores(blockIndex) = mean(contribution,1)';
            uncertainty(blockIndex) = mean(pairAmbiguity,1)';
        end
    end
    [~,ind] = sort(scores,'descend');
end

function blockSize = candidateBlockSize(candidateCount,anchorCount,D)
% Bound inference memory without changing any algorithm decision.
    maxPairInputElements = 2^20;
    pairWidth = max(1,2*D);
    pairLimit = max(1,floor(maxPairInputElements/pairWidth));
    blockSize = min(candidateCount,max(1,floor(pairLimit/anchorCount)));
end

function mode = validateAggregationMode(mode)
    if isstring(mode) && isscalar(mode)
        mode = char(mode);
    end
    if ~ischar(mode) || ~isrow(mode)
        error('AdaMaO:InvalidPreferenceAggregation', ...
            'Preference aggregation must be expected or hard_vote.');
    end
    mode = lower(strtrim(mode));
    if ~ismember(mode,{'expected','hard_vote'})
        error('AdaMaO:InvalidPreferenceAggregation', ...
            'Preference aggregation must be expected or hard_vote.');
    end
end

function validateCandidateInputs(Candidates,Anchors)
    if ~isnumeric(Candidates) || ~isreal(Candidates) || ...
            ~ismatrix(Candidates) || ~isnumeric(Anchors) || ...
            ~isreal(Anchors) || ~ismatrix(Anchors) || ...
            size(Candidates,2) ~= size(Anchors,2) || ...
            any(~isfinite(Candidates(:))) || any(~isfinite(Anchors(:)))
        error('AdaMaO:InvalidCandidateDimensions', ...
            'Candidates and Anchors must be finite matrices with equal width.');
    end
end
