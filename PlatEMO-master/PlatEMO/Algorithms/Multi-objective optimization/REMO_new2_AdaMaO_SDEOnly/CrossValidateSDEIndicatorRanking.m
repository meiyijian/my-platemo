function [tau,oofPrediction,foldID] = ...
    CrossValidateSDEIndicatorRanking(decisions,fitness,seed)
%CrossValidateSDEIndicatorRanking - Five-fold OOF SDE-SVR rank reliability.

    if nargin ~= 3
        error('AdaMaO:InvalidCascadeCVInputs', ...
            ['CrossValidateSDEIndicatorRanking requires decisions, ', ...
            'fitness, and a deterministic seed.']);
    end

    callerRng = rng;
    restoreRng = onCleanup(@() rng(callerRng));

    if ~isnumeric(decisions) || ~isreal(decisions) || ...
            ~ismatrix(decisions)
        error('AdaMaO:InvalidCascadeCVInputs', ...
            'Decisions must be a real numeric matrix with samples in rows.');
    end
    if ~isnumeric(fitness) || ~isreal(fitness) || ...
            ~(isvector(fitness) || isempty(fitness))
        error('AdaMaO:InvalidCascadeCVInputs', ...
            'Fitness must be a real numeric vector.');
    end
    sampleCount = size(decisions,1);
    if numel(fitness) ~= sampleCount
        error('AdaMaO:InvalidCascadeCVInputs', ...
            'Fitness must contain one value per decision row.');
    end
    if ~isnumeric(seed) || ~isreal(seed) || ~isscalar(seed) || ...
            ~isfinite(seed) || seed < 0 || seed ~= floor(seed) || ...
            double(seed) > double(intmax('uint32'))
        error('AdaMaO:InvalidCascadeCVSeed', ...
            'Seed must be an integer scalar from 0 through 2^32-1.');
    end

    fitness = fitness(:);
    tau = NaN;
    oofPrediction = nan(sampleCount,1);
    foldID = nan(sampleCount,1);
    if sampleCount < 10 || size(decisions,2) == 0 || ...
            any(~isfinite(decisions(:))) || any(~isfinite(fitness)) || ...
            numel(unique(fitness)) < 3
        return;
    end

    localStream = RandStream('mt19937ar','Seed',double(seed));
    permutation = randperm(localStream,sampleCount);
    assignedFold = mod((0:sampleCount-1)',5) + 1;
    foldID(permutation) = assignedFold;

    % KernelScale='auto' can use randomness, so seed it locally as well.
    rng(double(seed),'twister');
    for fold = 1:5
        testMask = foldID == fold;
        trainMask = ~testMask;
        try
            model = fitrsvm(decisions(trainMask,:),fitness(trainMask), ...
                'KernelFunction','rbf', ...
                'KernelScale','auto', ...
                'Standardize',true);
            foldPrediction = predict(model,decisions(testMask,:));
        catch
            oofPrediction(:) = NaN;
            foldID(:) = NaN;
            return;
        end
        if ~isnumeric(foldPrediction) || ~isreal(foldPrediction) || ...
                numel(foldPrediction) ~= nnz(testMask) || ...
                any(~isfinite(foldPrediction(:)))
            oofPrediction(:) = NaN;
            foldID(:) = NaN;
            return;
        end
        oofPrediction(testMask) = foldPrediction(:);
    end

    if any(~isfinite(oofPrediction)) || ...
            numel(unique(fitness)) < 2 || ...
            numel(unique(oofPrediction)) < 2
        oofPrediction(:) = NaN;
        foldID(:) = NaN;
        return;
    end

    try
        tau = corr(fitness,oofPrediction,'Type','Kendall');
    catch
        tau = NaN;
    end
    if ~isscalar(tau) || ~isreal(tau) || ~isfinite(tau)
        tau = NaN;
        oofPrediction(:) = NaN;
        foldID(:) = NaN;
    end
end
