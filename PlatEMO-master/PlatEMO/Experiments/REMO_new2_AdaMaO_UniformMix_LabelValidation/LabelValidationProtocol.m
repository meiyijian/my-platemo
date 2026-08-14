function cfg = LabelValidationProtocol(profile)
%LabelValidationProtocol Frozen problem matrix, parameters and job table.
%   cfg = LabelValidationProtocol(profile) returns the frozen Stage-1
%   protocol for 'smoke' | 'pilot' | 'screening':
%     - the problem matrix (problemIndex, family, requestedD)
%     - the seven frozen GUI parameters
%     - the job table (behavior x problem x M x run) with paired seeds
%
%   Section 3 of 01_Stage1_MechanismSnapshotAudit_Plan.md is the source of
%   truth; this function must not be modified by experimenters.

    if nargin < 1 || isempty(profile)
        profile = 'screening';
    end
    assert(any(strcmp(profile,{'smoke','pilot','screening'})), ...
        'LabelValidation:BadProfile','Unknown profile: %s',profile);

    %% ---- frozen problem matrix (order defines problemIndex) ----
    problems = struct('name',{},'family',{},'requestedD',{},'actualD',{});
    addProblem('DTLZ2','DTLZ',30,30);
    addProblem('DTLZ4','DTLZ',30,30);
    addProblem('DTLZ7','DTLZ',30,30);
    addProblem('WFG3','WFG',30,31);   % Setting() raises D to 31
    addProblem('WFG7','WFG',30,30);

    %% ---- frozen seven parameters (formal values) ----
    params = struct( ...
        'gmax',3000,'pMix',0.50,'rGood',0.25,'qKeep',0.80, ...
        'lambda0',0.35,'nMin',4,'nMax',6);

    %% ---- profile config ----
    switch profile
        case 'smoke'
            problemNames = {'DTLZ2'};
            Ms    = 3;
            runs  = 1;
            N     = 20;
            maxFE = 35;
            gmax  = 1;
            reqD  = 3;      % smoke uses D=3 (M=3)
        case 'pilot'
            problemNames = {'DTLZ2'};
            Ms    = 10;
            runs  = 1:2;
            N     = 100;
            maxFE = 300;
            gmax  = 300;
            reqD  = 30;
        case 'screening'
            problemNames = {problems.name};
            Ms    = [10,20];
            runs  = 1:5;
            N     = 100;
            maxFE = 500;
            gmax  = 3000;
            reqD  = [];
    end

    %% ---- job table ----
    behaviors = {'Hybrid','AnchorNative'};
    jobs = struct('behavior',{},'problemIndex',{},'problem',{}, ...
        'family',{},'M',{},'requestedD',{},'N',{},'maxFE',{}, ...
        'gmax',{},'run',{},'Seed',{},'pairedKey',{});
    for i = 1:numel(problemNames)
        idx = find(strcmp({problems.name},problemNames{i}));
        p = problems(idx);
        D = p.requestedD;
        if strcmp(profile,'smoke')
            D = reqD;
        end
        for M = Ms
            for run = runs
                seed = LabelValidationStableSeed(idx,M,run);
                key  = sprintf('%s_M%d_run%03d',p.name,M,run);
                for b = 1:numel(behaviors)
                    j = struct( ...
                        'behavior',behaviors{b}, ...
                        'problemIndex',idx, ...
                        'problem',p.name, ...
                        'family',p.family, ...
                        'M',M, ...
                        'requestedD',D, ...
                        'N',N, ...
                        'maxFE',maxFE, ...
                        'gmax',gmax, ...
                        'run',run, ...
                        'Seed',seed, ...
                        'pairedKey',key);
                    if isempty(jobs)
                        jobs = j;
                    else
                        jobs(end+1) = j; %#ok<AGROW>
                    end
                end
            end
        end
    end

    %% ---- assemble ----
    cfg = struct();
    cfg.profile  = profile;
    cfg.problems = problems;
    cfg.parameters = params;
    cfg.jobs     = jobs;
    cfg.behaviors = {behaviors};
    cfg.stats    = struct('Nref',100,'theta',5);

    %% ---- nested problem builder ----
    function addProblem(name,family,reqD,actD)
        p = struct('name',name,'family',family, ...
            'requestedD',reqD,'actualD',actD);
        if isempty(problems)
            problems = p;
        else
            problems(end+1) = p; %#ok<AGROW>
        end
    end
end
