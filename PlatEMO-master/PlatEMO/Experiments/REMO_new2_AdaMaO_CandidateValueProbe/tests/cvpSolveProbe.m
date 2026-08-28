function cvpSolveProbe(arm, poolLimit)
%CVPSOLVEPROBE Instantiate and solve the probe once, for validation tests.
%   Lives in its own file because MATLAB's functiontests harness requires
%   every local function of a test file to accept exactly one input, so
%   multi-argument helpers cannot be local functions there.

    algorithm = CVP_CandidateProbe('parameter', ...
        {arm, 200, 0.5, 0.25, 0.8, 0.35, 4, 6, 1, poolLimit, 40}, ...
        'run', 1, 'save', 0, 'outputFcn', @(varargin) []);
    problem = DTLZ2('N', 20, 'M', 2, 'D', 6, 'maxFE', 95, 'maxRuntime', inf);
    algorithm.Solve(problem);
end
