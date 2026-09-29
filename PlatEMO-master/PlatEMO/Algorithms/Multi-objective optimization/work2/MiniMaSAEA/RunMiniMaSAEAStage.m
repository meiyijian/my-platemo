function summary = RunMiniMaSAEAStage(action,workers)
%RUNMINIMASAEASTAGE Run the fixed FE300, ten-seed first-layer comparison.
%   RunMiniMaSAEAStage('probe') runs four modes on DTLZ2/M3/run 1.
%   RunMiniMaSAEAStage('regression') repeats the former failing SDE seed.
%   RunMiniMaSAEAStage('development','max') uses the Processes profile limit.
%   RunMiniMaSAEAStage('validation','max') runs the held-out problems.
%   RunMiniMaSAEAStage('check') counts validated output files.

    if nargin < 1, action = 'check'; end
    if nargin < 2, workers = 1; end
    action = lower(char(action));
    if ~ismember(action,{'probe','regression','development','validation','check'})
        error('MiniMaSAEA:Action','Use probe, regression, development, validation, or check.');
    end
    if (ischar(workers) || isstring(workers)) && strcmpi(workers,'max')
        profile = parcluster('Processes');
        workers = profile.NumWorkers;
    end
    validateattributes(workers,{'numeric'},{'scalar','integer','positive'});

    cfg = configuration();
    addpath(genpath(cfg.platform));
    assert(strcmpi(which('MiniMaSAEA'),fullfile(cfg.algorithmFolder,'MiniMaSAEA.m')), ...
        'MiniMaSAEA resolves outside the intended work2 folder.');
    jobs = buildJobs(cfg);
    if ~isfolder(cfg.results), mkdir(cfg.results); end
    writeManifest(cfg,jobs);

    if strcmp(action,'check')
        states = strings(numel(jobs),1);
        for i = 1:numel(jobs)
            if isfile(jobs(i).file)
                try
                    s = load(jobs(i).file,'record');
                    validateRecord(s.record,jobs(i),sourceManifest(cfg,jobs(i)));
                    states(i) = "complete";
                catch
                    states(i) = "invalid";
                end
            else
                states(i) = "pending";
            end
        end
        statusTable = table(string({jobs.phase})',string({jobs.mode})',states, ...
            'VariableNames',{'phase','mode','status'});
        summary = groupsummary(statusTable,{'phase','mode','status'});
        disp(summary);
        return;
    end

    switch action
        case 'probe'
            use = strcmp({jobs.problem},'DTLZ2') & [jobs.M]==3 & ...
                [jobs.runId]==1;
        case 'regression'
            use = strcmp({jobs.problem},'DTLZ2') & [jobs.M]==3 & ...
                strcmp({jobs.mode},'SDE') & [jobs.runId]==6;
        case 'development'
            use = strcmp({jobs.phase},'development');
        case 'validation'
            use = strcmp({jobs.phase},'validation');
    end
    jobs = jobs(use);
    fprintf('%s: %d planned jobs, N=%d, maxFE=%d, runs 1..%d, workers=%d\n', ...
        action,numel(jobs),cfg.N,cfg.maxFE,cfg.runs,workers);
    fprintf('Results: %s\n',cfg.results);

    if workers == 1
        status = cell(numel(jobs),1);
        for i = 1:numel(jobs)
            status{i} = runOne(cfg,jobs(i));
            printStatus(i,numel(jobs),status{i});
        end
    else
        pool = gcp('nocreate');
        if isempty(pool), pool = parpool('Processes',workers); end
        assert(isa(pool,'parallel.ProcessPool') && pool.NumWorkers==workers, ...
            'A process pool with the requested worker count is required.');
        futures = parallel.FevalFuture.empty;
        for i = 1:numel(jobs)
            futures(i) = parfeval(pool,@runOne,1,cfg,jobs(i)); %#ok<AGROW>
        end
        status = cell(numel(jobs),1);
        for i = 1:numel(jobs)
            [~,status{i}] = fetchNext(futures);
            printStatus(i,numel(jobs),status{i});
            if ~status{i}.ok
                cancel(futures);
                status = status(1:i);
                break;
            end
        end
    end
    summary = [status{:}]';
    if any(~[summary.ok])
        error('MiniMaSAEA:StageFailures','%d jobs failed; inspect the .error.txt files.', ...
            sum(~[summary.ok]));
    end
    if strcmp(action,'probe')
        verifyMatchedInitialization(jobs);
    end
end

function cfg = configuration()
    cfg.algorithmFolder = fileparts(mfilename('fullpath'));
    cfg.platform = fileparts(fileparts(fileparts(fileparts(cfg.algorithmFolder))));
    cfg.results = 'C:\Users\lsx\Desktop\AutoSAEA';
    cfg.development = {'DTLZ2','DTLZ4','WFG3','WFG4'};
    cfg.validation = {'DTLZ1','DTLZ7','WFG2','WFG5'};
    cfg.modes = {'PBI','TCH','SDE','OBJ'};
    cfg.objectives = [3 5 8 10];
    cfg.N = 100;
    cfg.maxFE = 300;
    cfg.runs = 10;
    cfg.seedBase = 20260929;
    cfg.save = 30;
end

function jobs = buildJobs(cfg)
    problems = [cfg.development,cfg.validation];
    jobs = struct('phase',{},'mode',{},'problem',{},'M',{},'D',{}, ...
        'N',{},'maxFE',{},'initialFE',{},'runId',{},'seed',{},'file',{});
    for p = 1:numel(problems)
        problem = problems{p};
        if p <= numel(cfg.development)
            phase = 'development';
        else
            phase = 'validation';
        end
        for M = cfg.objectives
            pro = feval(problem,'N',cfg.N,'M',M,'maxFE',cfg.maxFE);
            D = pro.D;  % Respect the actual PlatEMO default and WFG repair.
            NI = min([11*D-1,cfg.N,floor(cfg.maxFE/2)]);
            assert(NI >= D+2,'Not enough initial samples for %s M%d D%d.',problem,M,D);
            for runId = 1:cfg.runs
                seed = cfg.seedBase + M*100000 + p*1000 + runId;
                for v = 1:numel(cfg.modes)
                    mode = cfg.modes{v};
                    file = fullfile(cfg.results,['MiniMaSAEA_' mode],problem, ...
                        sprintf('M%02d',M),sprintf('D%02d',D), ...
                        sprintf('FE%d',cfg.maxFE),sprintf('run_%03d.mat',runId));
                    jobs(end+1) = struct('phase',phase,'mode',mode,'problem',problem, ...
                        'M',M,'D',D,'N',cfg.N,'maxFE',cfg.maxFE, ...
                        'initialFE',NI,'runId',runId,'seed',seed,'file',file); %#ok<AGROW>
                end
            end
        end
    end
end

function writeManifest(cfg,jobs)
    T = struct2table(jobs);
    manifestFile = fullfile(cfg.results,'manifest.csv');
    if isfile(manifestFile)
        old = readtable(manifestFile,'TextType','string');
        expected = convertvars(T,@iscellstr,'string');
        assert(isequal(old,expected),'Existing manifest differs; refusing to mix protocols.');
    else
        writetable(T,manifestFile);
    end
end

function s = runOne(cfg,job)
    s = struct('ok',false,'skipped',false,'file',job.file, ...
        'mode',job.mode,'problem',job.problem,'M',job.M, ...
        'runId',job.runId,'FE',NaN,'IGDp',NaN,'seconds',NaN,'message','');
    try
        maxNumCompThreads(1);
        addpath(genpath(cfg.platform));
        sources = sourceManifest(cfg,job);
        if isfile(job.file)
            old = load(job.file,'record');
            validateRecord(old.record,job,sources);
            s.ok = true;
            s.skipped = true;
            s.FE = old.record.FE;
            s.IGDp = old.record.IGDp;
            s.seconds = old.record.seconds;
            return;
        end
        folder = fileparts(job.file);
        if ~isfolder(folder), mkdir(folder); end
        problem = feval(job.problem,'N',job.N,'M',job.M,'maxFE',job.maxFE);
        assert(problem.D==job.D,'Actual decision dimension changed.');
        algorithm = MiniMaSAEA('parameter',{job.mode},'save',cfg.save, ...
            'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        started = tic;
        algorithm.Solve(problem);
        seconds = toc(started);
        assert(problem.FE==job.maxFE,'Actual FE differs from maxFE.');
        result = algorithm.result;
        assert(result{end,1}==job.maxFE,'Final snapshot has wrong FE.');
        final = result{end,2};
        assert(length(final)==job.maxFE,'The final archive does not contain all evaluations.');
        score = problem.CalMetric('IGDp',final);
        assert(isfinite(score),'Final IGD+ is not finite.');

        selected = find(~cellfun(@isempty,result(:,1)));
        snapshots = struct('FE',{},'decs',{},'objs',{},'cons',{});
        for k = 1:numel(selected)
            row = selected(k);
            pop = result{row,2};
            snapshots(k) = struct('FE',result{row,1}, ...
                'decs',pop.decs,'objs',pop.objs,'cons',pop.cons); %#ok<AGROW>
        end
        record = struct('protocol','MiniMaSAEA_stage_FE300_run10_v2', ...
            'phase',job.phase,'mode',job.mode,'problem',job.problem, ...
            'M',job.M,'D',job.D,'N',job.N,'maxFE',job.maxFE, ...
            'initialFE',job.initialFE,'runId',job.runId,'seed',job.seed, ...
            'FE',problem.FE,'IGDp',score,'seconds',seconds, ...
            'sources',sources,'referenceObj',problem.optimum, ...
            'snapshots',snapshots,'completedAt',char(datetime('now')));
        temp = [job.file,'.',char(java.util.UUID.randomUUID),'.tmp.mat'];
        save(temp,'record','-v7.3');
        assert(~isfile(job.file),'Target appeared during run: %s',job.file);
        [moved,msg] = movefile(temp,job.file);
        assert(moved,'%s',msg);
        s.ok = true;
        s.FE = problem.FE;
        s.IGDp = score;
        s.seconds = seconds;
        errorFile = [job.file,'.error.txt'];
        if isfile(errorFile), delete(errorFile); end
    catch ME
        s.message = getReport(ME,'extended','hyperlinks','off');
        folder = fileparts(job.file);
        if ~isfolder(folder), mkdir(folder); end
        fid = fopen([job.file,'.error.txt'],'w');
        if fid >= 0
            fprintf(fid,'%s',s.message);
            fclose(fid);
        end
    end
end

function verifyMatchedInitialization(jobs)
    baseline = load(jobs(1).file,'record');
    for i = 2:numel(jobs)
        current = load(jobs(i).file,'record');
        assert(current.record.seed==baseline.record.seed && ...
            current.record.initialFE==baseline.record.initialFE && ...
            isequal(current.record.snapshots(1).decs, ...
                    baseline.record.snapshots(1).decs), ...
            'Matched-seed initial designs differ between modes.');
    end
    fprintf('Probe verified: all four modes share the initial evaluated decisions.\n');
end

function sources = sourceManifest(cfg,job)
    own = {'MiniMaSAEA.m','MiniMaSAEAHandler.m', ...
        fullfile('private','MiniDaceFit.m'), ...
        fullfile('private','MiniDacePredictor.m')};
    paths = cellfun(@(f)fullfile(cfg.algorithmFolder,f),own,'UniformOutput',false);
    if startsWith(job.problem,'DTLZ')
        family = 'DTLZ';
    else
        family = 'WFG';
    end
    paths{end+1} = fullfile(cfg.platform,'Problems', ...
        'Multi-objective optimization',family,[job.problem,'.m']);
    paths{end+1} = fullfile(cfg.platform,'Algorithms','ALGORITHM.m');
    paths{end+1} = fullfile(cfg.platform,'Problems','PROBLEM.m');
    paths{end+1} = fullfile(cfg.platform,'Problems','SOLUTION.m');
    paths{end+1} = fullfile(cfg.platform,'Algorithms','Utility functions','OperatorGA.m');
    paths{end+1} = fullfile(cfg.platform,'Algorithms','Utility functions','UniformPoint.m');
    paths{end+1} = fullfile(cfg.platform,'Algorithms','Utility functions','NDSort.m');
    paths{end+1} = fullfile(cfg.platform,'Metrics','IGDp.m');
    sources = struct('path',paths(:),'sha256',cell(numel(paths),1));
    for i = 1:numel(paths)
        assert(isfile(paths{i}),'Missing source file: %s',paths{i});
        sources(i).sha256 = sha256File(paths{i});
    end
end

function hash = sha256File(path)
    fid = fopen(path,'r');
    assert(fid>=0,'Cannot read source file %s',path);
    bytes = fread(fid,Inf,'*uint8');
    fclose(fid);
    md = java.security.MessageDigest.getInstance('SHA-256');
    md.update(bytes);
    hash = sprintf('%02x',typecast(md.digest(),'uint8'));
end

function validateRecord(record,job,sources)
    assert(strcmp(record.protocol,'MiniMaSAEA_stage_FE300_run10_v2') && ...
        strcmp(record.mode,job.mode) && strcmp(record.problem,job.problem) && ...
        record.M==job.M && record.D==job.D && record.N==job.N && ...
        record.maxFE==job.maxFE && record.initialFE==job.initialFE && ...
        record.runId==job.runId && record.seed==job.seed && ...
        record.FE==job.maxFE && isfinite(record.IGDp), ...
        'Existing output has mismatched or incomplete metadata: %s',job.file);
    assert(isequal(record.sources,sources), ...
        'Existing output was produced by different source files: %s',job.file);
end

function printStatus(index,total,s)
    if s.ok
        if s.skipped, label = 'SKIP'; else, label = 'DONE'; end
        fprintf('[%d/%d] %s %s %s M%d run%02d FE%d IGDp=%.6g %.1fs\n', ...
            index,total,label,s.mode,s.problem,s.M,s.runId,s.FE,s.IGDp,s.seconds);
    else
        fprintf(2,'[%d/%d] FAILED %s %s M%d run%02d: %s\n', ...
            index,total,s.mode,s.problem,s.M,s.runId,s.message);
    end
end
