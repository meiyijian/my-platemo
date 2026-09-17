function resultPath = LTGGPResultPath(resultRoot, profile, job)
%LTGGPRESULTPATH Return the unique per-run MAT path for one protocol job.

    if ~((ischar(resultRoot) && isrow(resultRoot)) || ...
            (isstring(resultRoot) && isscalar(resultRoot)))
        error("LTGGP:InvalidResultRoot", "resultRoot must be a text scalar.");
    end
    profile = validatestring(string(profile), ["smoke", "pilot", "formal"]);
    requiredFields = ["Problem", "M", "Run"];
    if ~all(isfield(job, requiredFields))
        error("LTGGP:InvalidJob", "job must contain Problem, M, and Run fields.");
    end

    resultPath = fullfile(string(resultRoot), "raw", profile, ...
        string(job.Problem), sprintf("M%d", job.M), ...
        sprintf("run_%03d.mat", job.Run));
    resultPath = char(resultPath);
end
