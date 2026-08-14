function [modeStream,modeSeed] = CreateSDECandidateModeStream(runId)
%CreateSDECandidateModeStream Create an RNG stream for mode routing only.
%   The stream is independent of MATLAB's global random-number stream.

    if isempty(runId) || ~isnumeric(runId) || ~isscalar(runId) || ...
            ~isfinite(runId) || runId <= 0
        runId = 1;
    else
        runId = max(1,floor(double(runId)));
    end

    maxSeed  = double(intmax('uint32'));
    modeSeed = mod(10000000 + runId,maxSeed);
    modeStream = RandStream('mt19937ar','Seed',modeSeed);
end
