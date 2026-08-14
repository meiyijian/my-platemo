function seed = LabelValidationStableSeed(problemIndex,M,run)
%LabelValidationStableSeed Paired-seed formula for all stages.
%   seed = LabelValidationStableSeed(problemIndex,M,run) implements the
%   frozen formula
%       seed = problemIndex*10000 + M*100 + run
%   e.g. DTLZ2/M10/run1 -> 11001, WFG3/M20/run5 -> 42005.

    assert(isscalar(problemIndex) && isnumeric(problemIndex) && ...
        problemIndex == floor(problemIndex) && problemIndex > 0, ...
        'LabelValidation:BadProblemIndex','problemIndex must be a positive integer.');
    assert(isscalar(M) && isnumeric(M) && M == floor(M) && M > 0, ...
        'LabelValidation:BadM','M must be a positive integer.');
    assert(isscalar(run) && isnumeric(run) && run == floor(run) && run > 0, ...
        'LabelValidation:BadRun','run must be a positive integer.');

    seed = problemIndex*10000 + M*100 + run;
end
