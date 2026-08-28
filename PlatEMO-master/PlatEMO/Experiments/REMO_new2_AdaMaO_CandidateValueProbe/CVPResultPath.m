function resultPath = CVPResultPath(resultRoot, profile, job)
%CVPRESULTPATH Unique per-run MAT path for one protocol job.

    if ~((ischar(resultRoot) && isrow(resultRoot)) || ...
            (isstring(resultRoot) && isscalar(resultRoot)))
        error("CVP:InvalidResultRoot", "resultRoot must be a text scalar.");
    end
    profile = validatestring(string(profile), ["smoke", "pilot", "formal"]);
    requiredFields = ["Problem", "M", "Run", "Arm"];
    if ~all(isfield(job, requiredFields))
        error("CVP:InvalidJob", ...
            "job must contain Problem, M, Run and Arm fields.");
    end

    resultPath = fullfile(string(resultRoot), "raw", profile, ...
        string(job.Arm), string(job.Problem), sprintf("M%d", job.M), ...
        sprintf("run_%03d.mat", job.Run));
    resultPath = char(resultPath);
end
