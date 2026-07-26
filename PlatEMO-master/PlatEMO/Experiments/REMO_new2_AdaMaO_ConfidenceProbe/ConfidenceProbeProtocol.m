function protocol = ConfidenceProbeProtocol(profile)
%CONFIDENCEPROBEPROTOCOL Frozen confidence-validity experiment profiles.
%   PROTOCOL = CONFIDENCEPROBEPROTOCOL(PROFILE) returns the approved
%   problem matrix and one deterministic job row per problem/run.

    if nargin < 1 || isempty(profile)
        profile = 'smoke';
    end
    if ~(ischar(profile) || (isstring(profile) && isscalar(profile)))
        error('AdaMaO:UnknownConfidenceProbeProfile', ...
            'The profile must be a character vector or scalar string.');
    end
    profile = lower(char(profile));

    switch profile
        case 'smoke'
            problems = {'DTLZ2'};
            objectives = 3;
            requestedD = 3;
            populationSize = 20;
            maxFE = 36;
            runs = 1;
            gmax = 1;
        case 'pilot'
            problems = {'DTLZ2','DTLZ7','WFG3'};
            objectives = 10;
            requestedD = 30;
            populationSize = 100;
            maxFE = 500;
            runs = 3;
            gmax = 3000;
        case 'screening'
            problems = {'DTLZ2','DTLZ4','DTLZ7','WFG3','WFG7'};
            objectives = 10;
            requestedD = 30;
            populationSize = 100;
            maxFE = 500;
            runs = 10;
            gmax = 3000;
        case 'confirmation'
            problems = {'DTLZ2','DTLZ4','DTLZ7','WFG3','WFG7'};
            objectives = 20;
            requestedD = 30;
            populationSize = 100;
            maxFE = 500;
            runs = 10;
            gmax = 3000;
        otherwise
            error('AdaMaO:UnknownConfidenceProbeProfile', ...
                'Unknown confidence-probe profile: %s.',profile);
    end

    protocol = struct();
    protocol.schemaVersion = 1;
    protocol.profile = profile;
    protocol.problems = problems;
    protocol.objectives = objectives;
    protocol.requestedD = requestedD;
    protocol.populationSize = populationSize;
    protocol.maxFE = maxFE;
    protocol.runs = runs;
    protocol.gmax = gmax;
    protocol.algorithmLabel = 'ConfidenceProbe';
    protocol.algorithmClass = ...
        'REMO_new2_AdaMaO_SDEOnly_ConfidenceProbe';
    protocol.analysis = struct( ...
        'bootstrapSamples',10000, ...
        'bootstrapSeed',20260726, ...
        'confidenceLevel',0.95, ...
        'minimumProblems',5, ...
        'minimumNegativeProblems',4, ...
        'gateErrorReduction',0.05);
    protocol.jobs = expandJobs(protocol);
end

function jobs = expandJobs(protocol)
    total = numel(protocol.problems)*protocol.runs;
    jobs = table('Size',[total,13], ...
        'VariableTypes',{'string','string','double','double','double', ...
        'double','double','double','double','double','string','string', ...
        'string'}, ...
        'VariableNames',{'Problem','Family','M','RequestedD','ActualD', ...
        'N','MaxFE','Gmax','Run','Seed','Algorithm','AlgorithmClass', ...
        'JobID'});

    row = 0;
    for problemIndex = 1:numel(protocol.problems)
        problem = protocol.problems{problemIndex};
        for run = 1:protocol.runs
            row = row + 1;
            jobs.Problem(row) = string(problem);
            jobs.Family(row) = string(problemFamily(problem));
            jobs.M(row) = protocol.objectives;
            jobs.RequestedD(row) = protocol.requestedD;
            jobs.ActualD(row) = actualDimension(problem, ...
                protocol.requestedD);
            jobs.N(row) = protocol.populationSize;
            jobs.MaxFE(row) = protocol.maxFE;
            jobs.Gmax(row) = protocol.gmax;
            jobs.Run(row) = run;
            jobs.Seed(row) = stableSeed(problem,protocol.objectives,run);
            jobs.Algorithm(row) = string(protocol.algorithmLabel);
            jobs.AlgorithmClass(row) = string(protocol.algorithmClass);
            jobs.JobID(row) = string(sprintf('%s_M%d_run%03d', ...
                problem,protocol.objectives,run));
        end
    end
end

function family = problemFamily(problem)
    if startsWith(problem,'DTLZ')
        family = 'DTLZ';
    elseif startsWith(problem,'WFG')
        family = 'WFG';
    else
        error('AdaMaO:UnsupportedConfidenceProbeProblem', ...
            'Unsupported confidence-probe problem: %s.',problem);
    end
end

function D = actualDimension(problem,requestedD)
    if strcmp(problem,'WFG3')
        D = requestedD + 1;
    else
        D = requestedD;
    end
end

function seed = stableSeed(problem,M,run)
    number = str2double(regexprep(problem,'\D',''));
    if startsWith(problem,'DTLZ')
        familyCode = 1;
    else
        familyCode = 2;
    end
    seed = familyCode*1000000 + number*10000 + M*100 + run;
end
