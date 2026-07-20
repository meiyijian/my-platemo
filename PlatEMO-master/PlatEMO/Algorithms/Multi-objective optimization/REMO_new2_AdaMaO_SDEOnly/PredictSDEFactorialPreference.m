function [p,ambiguity,Qsym] = ...
    PredictSDEFactorialPreference(model,left,right)
%PredictSDEFactorialPreference Predict explicitly reciprocal preferences.

    [modelKind,inputDimension] = validatePredictionInputs(model,left,right);
    if isempty(left)
        p = zeros(0,1);
        ambiguity = zeros(0,1);
        Qsym = zeros(0,2);
        return;
    end

    if strcmp(modelKind,'regression')
        if size(left,2) ~= inputDimension
            error('AdaMaO:InvalidPreferenceDimensions', ...
                'Each endpoint must match the regression input dimension.');
        end
        leftNormalized = mapminmax('apply',left',model.mp_struct);
        rightNormalized = mapminmax('apply',right',model.mp_struct);
        leftScore = model.net(leftNormalized)';
        rightScore = model.net(rightNormalized)';
        leftScore = min(1,max(0,leftScore(:)));
        rightScore = min(1,max(0,rightScore(:)));
        p = (1+leftScore-rightScore)./2;
        p = min(1,max(0,p));
        ambiguity = 1-abs(2.*p-1);
        Qsym = [p,1-p];
        return;
    end

    forwardInput = [left,right];
    reverseInput = [right,left];
    if size(forwardInput,2) ~= inputDimension
        error('AdaMaO:InvalidPreferenceDimensions', ...
            'Each pair must match the dimension used to train the model.');
    end
    forwardNormalized = mapminmax( ...
        'apply',forwardInput',model.mp_struct);
    reverseNormalized = mapminmax( ...
        'apply',reverseInput',model.mp_struct);
    Qforward = model.net(forwardNormalized)';
    Qreverse = model.net(reverseNormalized)';
    [p,ambiguity,Qsym] = SymmetrizeSDEFactorialPreference( ...
        Qforward,Qreverse);
end

function [modelKind,inputDimension] = validatePredictionInputs(model,left,right)
    if ~isstruct(model) || ~isscalar(model) || ...
            ~isfield(model,'net') || ~isfield(model,'mp_struct') || ...
            isempty(model.net) || isempty(model.mp_struct)
        error('AdaMaO:InvalidRelationModel', ...
            'model must contain a trained net and mapminmax settings.');
    end
    if ~isnumeric(left) || ~isreal(left) || ~ismatrix(left) || ...
            ~isnumeric(right) || ~isreal(right) || ~ismatrix(right) || ...
            size(left,1) ~= size(right,1) || ...
            size(left,2) ~= size(right,2) || ...
            any(~isfinite(left(:))) || any(~isfinite(right(:)))
        error('AdaMaO:InvalidPreferenceDimensions', ...
            'left and right must be equally sized finite numeric matrices.');
    end
    modelKind = 'pairwise';
    if isfield(model,'kind') && ~isempty(model.kind)
        modelKind = model.kind;
        if isstring(modelKind) && isscalar(modelKind)
            modelKind = char(modelKind);
        end
    end
    if ~ischar(modelKind) || ...
            ~ismember(lower(strtrim(modelKind)),{'pairwise','regression'})
        error('AdaMaO:InvalidRelationModel', ...
            'The model kind must be pairwise or regression.');
    end
    modelKind = lower(strtrim(modelKind));

    if isfield(model.mp_struct,'xrows')
        inputDimension = model.mp_struct.xrows;
    elseif ~isempty(model.net.inputs) && ...
            ~isempty(model.net.inputs{1}.size)
        inputDimension = model.net.inputs{1}.size;
    else
        error('AdaMaO:InvalidRelationModel', ...
            'The model does not expose its trained input dimension.');
    end
    if strcmp(modelKind,'pairwise')
        dimensionsMatch = inputDimension >= 2 && ...
            mod(inputDimension,2) == 0 && ...
            2*size(left,2) == inputDimension;
    else
        dimensionsMatch = inputDimension >= 1 && ...
            size(left,2) == inputDimension;
    end
    if ~isscalar(inputDimension) || ~dimensionsMatch
        error('AdaMaO:InvalidPreferenceDimensions', ...
            'Inputs do not match the trained model dimension.');
    end
end
