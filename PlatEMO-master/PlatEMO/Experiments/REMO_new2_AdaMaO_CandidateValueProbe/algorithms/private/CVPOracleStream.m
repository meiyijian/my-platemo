function stream = CVPOracleStream(runId, M)
%CVPORACLESTREAM RNG stream used only by the oracle pool subsample.
%   The stream is independent of MATLAB's global stream, so switching the
%   oracle on or off cannot perturb the optimisation trajectory. It is
%   seeded from (runId, M) so that every arm of the same paired job draws
%   the SAME pool subsample, which keeps the arms comparable.

    if isempty(runId) || ~isnumeric(runId) || ~isscalar(runId) || ...
            ~isfinite(runId) || runId <= 0
        runId = 1;
    else
        runId = max(1, floor(double(runId)));
    end
    if isempty(M) || ~isnumeric(M) || ~isscalar(M) || ~isfinite(M) || M <= 0
        M = 1;
    else
        M = max(1, floor(double(M)));
    end

    maxSeed = double(intmax('uint32'));
    seed = mod(20000000 + 1000*runId + M, maxSeed);
    stream = RandStream('mt19937ar', 'Seed', seed);
end
