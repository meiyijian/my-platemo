function [PairInput,Targets,PairIndex] = ...
    BuildSDEFactorialRelationData(Input,score,relationBit,indices)
%BuildSDEFactorialRelationData Build matched hard or soft ordered pairs.

    if nargin < 4
        indices = (1:size(Input,1))';
    end
    validateInputs(Input,score,relationBit,indices);
    indices = sort(indices(:));

    dimension = size(Input,2);
    if numel(indices) < 2
        PairInput = zeros(0,2*dimension);
        Targets   = zeros(0,2);
        PairIndex = zeros(0,2);
        return;
    end

    unordered = nchoosek(indices,2);
    pairCount = size(unordered,1);
    PairIndex = zeros(2*pairCount,2);
    PairIndex(1:2:end,:) = unordered;
    PairIndex(2:2:end,:) = unordered(:,[2 1]);
    PairInput = [Input(PairIndex(:,1),:),Input(PairIndex(:,2),:)];

    leftScore  = score(PairIndex(:,1));
    rightScore = score(PairIndex(:,2));
    difference = leftScore-rightScore;
    if relationBit == 0
        preference = 0.5.*ones(size(difference));
        preference(difference > 0) = 1;
        preference(difference < 0) = 0;
    else
        preference = (1+leftScore-rightScore)./2;
    end
    Targets = [preference,1-preference];
end

function validateInputs(Input,score,relationBit,indices)
    if ~isnumeric(Input) || ~isreal(Input) || ~ismatrix(Input) || ...
            any(~isfinite(Input(:)))
        error('AdaMaO:InvalidRelationInput', ...
            'Input must be a finite numeric matrix.');
    end
    if ~isnumeric(score) || ~isreal(score) || ~isvector(score) || ...
            numel(score) ~= size(Input,1) || any(~isfinite(score(:))) || ...
            any(score(:) < 0) || any(score(:) > 1)
        error('AdaMaO:InvalidRelationScore', ...
            'score must contain one finite value in [0,1] per solution.');
    end
    score = score(:); %#ok<NASGU>
    if ~isnumeric(relationBit) || ~isreal(relationBit) || ...
            ~isscalar(relationBit) || ~ismember(relationBit,[0 1])
        error('AdaMaO:InvalidRelationBit', ...
            'relationBit must be either zero or one.');
    end
    if ~isnumeric(indices) || ~isreal(indices) || ...
            (~isempty(indices) && ~isvector(indices)) || ...
            any(~isfinite(indices(:))) || any(indices(:) ~= fix(indices(:))) || ...
            any(indices(:) < 1) || any(indices(:) > size(Input,1)) || ...
            numel(unique(indices(:))) ~= numel(indices)
        error('AdaMaO:InvalidRelationIndices', ...
            'indices must be unique valid solution indices.');
    end
end
