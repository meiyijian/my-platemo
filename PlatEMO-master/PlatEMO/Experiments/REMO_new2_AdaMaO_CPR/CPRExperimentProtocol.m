function protocol = CPRExperimentProtocol(profile)
%CPREXPERIMENTPROTOCOL Define reproducible CPR experiment matrices.
%   PROTOCOL = CPREXPERIMENTPROTOCOL(PROFILE) returns the immutable
%   experiment definition and an expanded job table for PROFILE. Supported
%   profiles are screening, formal, extreme, and micro.

    if nargin < 1 || isempty(profile)
        profile = 'screening';
    end
    if ~(ischar(profile) || (isstring(profile) && isscalar(profile)))
        error('AdaMaO:UnknownCPRExperimentProfile', ...
            'The CPR experiment profile must be a character vector or scalar string.');
    end
    profile = lower(char(profile));

    mainProblems = {'DTLZ2','DTLZ4','DTLZ7', ...
        'WFG2','WFG3','WFG5','WFG7','WFG8'};
    mainLabels = {'U0','F00','F10','F01','F11'};
    mainClasses = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix', ...
        'REMO_new2_AdaMaO_CPR_F00', ...
        'REMO_new2_AdaMaO_CPR_F10', ...
        'REMO_new2_AdaMaO_CPR_F01', ...
        'REMO_new2_AdaMaO_CPR_F11'};
    comparisonLabels = {};
    comparisonClasses = {};

    switch profile
        case 'screening'
            problems = mainProblems;
            labels = mainLabels;
            classes = mainClasses;
            maxFE = 500;
            runs = 10;
        case 'formal'
            problems = [composeNames('DTLZ',1:7),composeNames('WFG',1:9)];
            labels = mainLabels;
            classes = mainClasses;
            comparisonLabels = {'REMO','PIEA','PCSAEA'};
            comparisonClasses = {'REMO','PIEA','PCSAEA'};
            maxFE = 500;
            runs = 30;
        case 'extreme'
            problems = mainProblems;
            labels = mainLabels;
            classes = mainClasses;
            maxFE = 300;
            runs = 10;
        case 'micro'
            problems = {'DTLZ2','DTLZ7','WFG3','WFG7'};
            labels = {'F11','F11_HardVote','F11_Regression'};
            classes = { ...
                'REMO_new2_AdaMaO_CPR_F11', ...
                'REMO_new2_AdaMaO_CPR_F11_HardVote', ...
                'REMO_new2_AdaMaO_CPR_F11_Regression'};
            maxFE = 500;
            runs = 10;
        otherwise
            error('AdaMaO:UnknownCPRExperimentProfile', ...
                'Unknown CPR experiment profile: %s.',profile);
    end
    labels = [labels,comparisonLabels];
    classes = [classes,comparisonClasses];

    protocol = struct();
    protocol.profile = profile;
    protocol.problems = problems;
    protocol.objectives = [10,20];
    protocol.requestedD = 30;
    protocol.maxFE = maxFE;
    protocol.runs = runs;
    protocol.algorithmLabels = labels;
    protocol.algorithmClasses = classes;
    protocol.comparisonAlgorithmLabels = comparisonLabels;
    protocol.comparisonAlgorithmClasses = comparisonClasses;
    protocol.resultBudgetFolder = sprintf('FE%d',maxFE);
    protocol.resultProfileFolder = profile;
    protocol.autoExecute = false;
    protocol.analysis = struct( ...
        'bootstrapSamples',10000, ...
        'bootstrapSeed',20260720, ...
        'nonInferiorityMargin',1.05, ...
        'severeRegressionRatio',1.20, ...
        'maxSevereRegressionCount',1);
    protocol.jobs = expandJobs(protocol);
end

function names = composeNames(prefix,numbers)
    names = arrayfun(@(number)sprintf('%s%d',prefix,number), ...
        numbers,'UniformOutput',false);
end

function jobs = expandJobs(protocol)
    total = numel(protocol.problems)*numel(protocol.objectives)* ...
        protocol.runs*numel(protocol.algorithmLabels);
    jobs = table('Size',[total,10], ...
        'VariableTypes',{'string','string','double','double','double', ...
        'double','double','string','string','string'}, ...
        'VariableNames',{'Problem','Family','M','RequestedD','ActualD', ...
        'Run','Seed','Algorithm','AlgorithmClass','JobID'});

    row = 0;
    for problemIndex = 1:numel(protocol.problems)
        problem = protocol.problems{problemIndex};
        family = problemFamily(problem);
        actualD = actualDimension(problem,protocol.requestedD);
        for M = protocol.objectives
            for run = 1:protocol.runs
                seed = pairedSeed(problem,M,run);
                for algorithmIndex = 1:numel(protocol.algorithmLabels)
                    row = row + 1;
                    label = protocol.algorithmLabels{algorithmIndex};
                    jobs.Problem(row) = string(problem);
                    jobs.Family(row) = string(family);
                    jobs.M(row) = M;
                    jobs.RequestedD(row) = protocol.requestedD;
                    jobs.ActualD(row) = actualD;
                    jobs.Run(row) = run;
                    jobs.Seed(row) = seed;
                    jobs.Algorithm(row) = string(label);
                    jobs.AlgorithmClass(row) = string(protocol.algorithmClasses{algorithmIndex});
                    jobs.JobID(row) = string(sprintf('%s_M%d_%s_run%03d', ...
                        problem,M,label,run));
                end
            end
        end
    end
end

function family = problemFamily(problem)
    if startsWith(problem,'DTLZ')
        family = 'DTLZ';
    elseif startsWith(problem,'WFG')
        family = 'WFG';
    else
        error('AdaMaO:UnsupportedCPRProblem', ...
            'Unsupported CPR problem family: %s.',problem);
    end
end

function D = actualDimension(problem,requestedD)
    if ismember(problem,{'WFG2','WFG3'})
        D = requestedD + 1;
    else
        D = requestedD;
    end
end

function seed = pairedSeed(problem,M,run)
    number = str2double(regexprep(problem,'\D',''));
    if startsWith(problem,'DTLZ')
        familyCode = 1;
    else
        familyCode = 2;
    end
    seed = familyCode*1000000 + number*10000 + M*100 + run;
end
