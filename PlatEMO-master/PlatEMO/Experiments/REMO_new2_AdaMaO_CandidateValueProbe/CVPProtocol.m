function config = CVPProtocol(profile)
%CVPPROTOCOL Frozen protocol for the candidate-value probe.
%   CONFIG = CVPPROTOCOL(PROFILE) returns the problem matrix, algorithm
%   parameters and the fully enumerated job list for PROFILE.
%
%   Profiles
%     smoke   1 problem  x M=2    x 1 run  x 5 arms =   5 jobs (minutes)
%     pilot   2 problems x M=10   x 2 runs x 5 arms =  20 jobs
%     formal  4 problems x M=10,20 x 10 runs x 5 arms = 400 jobs
%
%   Problem choice follows the recorded ablation evidence: DTLZ2 as the
%   standard concave benchmark, DTLZ7 as the disconnected front that carries
%   the largest module gain, WFG3 as the ONE problem that degrades in every
%   contrast (kept deliberately so the probe can be falsified), and WFG7 as
%   a well-behaved WFG reference.
%
%   Seeds are shared across arms via CVPStableSeed(problemIndex, M, run), so
%   arm contrasts are paired on common random numbers: within one paired key
%   all five arms start from the same initial population and the same
%   network initialisation stream. This is what makes the paired Wilcoxon
%   test in analyze_CandidateValueProbe legitimate.

    if nargin < 1 || isempty(profile)
        profile = "formal";
    end
    profile = validatestring(string(profile), ["smoke", "pilot", "formal"]);

    problems = struct( ...
        "Name", {"DTLZ2", "DTLZ7", "WFG3", "WFG7"}, ...
        "Family", {"DTLZ", "DTLZ", "WFG", "WFG"}, ...
        "RequestedD", {30, 30, 30, 30}, ...
        "ExpectedActualD", {30, 30, 31, 30});

    parameters = struct( ...
        "gmax", 3000, ...
        "pMix", 0.50, ...
        "rGood", 0.25, ...
        "qKeep", 0.80, ...
        "lambda0", 0.35, ...
        "nMin", 4, ...
        "nMax", 6, ...
        "oracleEvery", 1, ...
        "oraclePoolLimit", 400, ...
        "oracleRefSize", 300);

    switch profile
        case "smoke"
            % The host sizes its own initial population as 11*D-1 when
            % D <= 10, independently of Problem.N. maxFE must exceed that
            % initial cost or the very first NotTerminated call terminates
            % the run and no generation is ever recorded. D=6 gives an
            % initial 65 evaluations, so maxFE=95 leaves ~5 batches.
            problemIndices = 1;
            objectiveCounts = 2;
            runNumbers = 1;
            requestedD = 6;
            expectedD = 6;
            populationSize = 20;
            maxFE = 95;
            gmax = 200;
            oracleEvery = 1;
            oraclePoolLimit = 60;
            oracleRefSize = 40;
        case "pilot"
            problemIndices = [1, 3];
            objectiveCounts = 10;
            runNumbers = 1:2;
            requestedD = 30;
            expectedD = [];
            populationSize = 100;
            maxFE = 300;
            gmax = 600;
            oracleEvery = 2;
            oraclePoolLimit = 200;
            oracleRefSize = 200;
        case "formal"
            problemIndices = 1:numel(problems);
            objectiveCounts = [10, 20];
            runNumbers = 1:10;
            requestedD = 30;
            expectedD = [];
            populationSize = 100;
            maxFE = 300;
            gmax = parameters.gmax;
            oracleEvery = parameters.oracleEvery;
            oraclePoolLimit = parameters.oraclePoolLimit;
            oracleRefSize = parameters.oracleRefSize;
        otherwise
            error("CVP:UnknownProfile", "Unsupported profile: %s", profile);
    end

    parameters.gmax = gmax;
    parameters.oracleEvery = oracleEvery;
    parameters.oraclePoolLimit = oraclePoolLimit;
    parameters.oracleRefSize = oracleRefSize;

    catalog = CVPArmCatalog();
    numberOfJobs = numel(problemIndices) * numel(objectiveCounts) * ...
        numel(runNumbers) * height(catalog);

    emptyJob = struct( ...
        "ProblemIndex", 0, "Problem", "", "Family", "", "M", 0, ...
        "RequestedD", 0, "ExpectedActualD", 0, "N", 0, "MaxFE", 0, ...
        "Gmax", 0, "Run", 0, "Seed", 0, "PairedKey", "", ...
        "ArmID", 0, "Arm", "", "Pool", "", "Route", "");
    jobs = repmat(emptyJob, numberOfJobs, 1);

    jobIndex = 0;
    for problemIndex = problemIndices
        problem = problems(problemIndex);
        for objectiveCount = objectiveCounts
            for runNumber = runNumbers
                for armRow = 1:height(catalog)
                    jobIndex = jobIndex + 1;
                    if profile == "smoke"
                        actualRequestedD = requestedD;
                        actualExpectedD = expectedD;
                    else
                        actualRequestedD = problem.RequestedD;
                        actualExpectedD = problem.ExpectedActualD;
                    end
                    jobs(jobIndex) = struct( ...
                        "ProblemIndex", problemIndex, ...
                        "Problem", problem.Name, ...
                        "Family", problem.Family, ...
                        "M", objectiveCount, ...
                        "RequestedD", actualRequestedD, ...
                        "ExpectedActualD", actualExpectedD, ...
                        "N", populationSize, ...
                        "MaxFE", maxFE, ...
                        "Gmax", gmax, ...
                        "Run", runNumber, ...
                        "Seed", CVPStableSeed(problemIndex, objectiveCount, runNumber), ...
                        "PairedKey", sprintf("%s_M%d_run%03d", ...
                            problem.Name, objectiveCount, runNumber), ...
                        "ArmID", catalog.ArmID(armRow), ...
                        "Arm", catalog.Arm(armRow), ...
                        "Pool", catalog.Pool(armRow), ...
                        "Route", catalog.Route(armRow));
                end
            end
        end
    end

    config = struct( ...
        "SchemaVersion", 1, ...
        "Profile", profile, ...
        "Problems", problems, ...
        "Parameters", parameters, ...
        "Arms", catalog, ...
        "StageEdges", [0, 0.25, 0.50, 0.75, 1.00], ...
        "LateStageStart", 0.50, ...
        "Jobs", jobs);
end
