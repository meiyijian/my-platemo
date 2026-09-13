function summary = RunPaperWeighted30(action,workers)
%RUNPAPERWEIGHTED30 Resume the seven-algorithm, 48-instance paper experiment.
%   RunPaperWeighted30('check') audits existing files without optimization.
%   RunPaperWeighted30('run',2) fills run IDs 1:30 using two process workers.
%   Historical results are never overwritten. Read README_30runs.md first.
    if nargin < 1, action = 'run'; end
    if nargin < 2, workers = 2; end
    assert(ismember(action,{'run','check','verify'}),'Use run, check or verify.');
    validateattributes(workers,{'numeric'},{'scalar','integer','positive'});
    root = fileparts(mfilename('fullpath'));
    platform = fileparts(fileparts(fileparts(root)));
    addpath(genpath(platform));
    addpath(root);
    cfg = configuration(root,platform);
    if ~isfolder(cfg.logs), mkdir(cfg.logs); end
    if strcmp(action,'verify')
        pool=gcp('nocreate');
        if isempty(pool), pool=parpool('Processes',1); end
        assert(isa(pool,'parallel.ProcessPool'),'Use a process pool.');
        setup=parfevalOnAll(pool,@prepareWorker,0,platform,root);
        fetchOutputs(setup);
        check=parfeval(pool,@verifyWorker,1,cfg);
        summary=fetchOutputs(check);
        disp(summary);
        return;
    end
    stamp = char(datetime('now','Format','yyyyMMdd_HHmmss_SSS'));
    manifest = sourceManifest(cfg);
    manifestFile = fullfile(cfg.logs,['sources_',stamp,'.mat']);
    save(manifestFile,'manifest','cfg');
    fprintf('N=100 (configured), maxFE=300; D=30 requested; runs=1:30.\n');
    fprintf('Weighted parameters: {3000,0.50,0.25,0.70,6}; mode run=1.\n');
    fprintf('Checking existing results. No optimization during this stage.\n');
    rows = struct([]); jobs = struct([]); counts = zeros(3,7);
    for mi = 1:3
        M = cfg.objectives(mi);
        for pi = 1:16
            problem = cfg.problems{pi};
            pro = feval(problem,'N',100,'M',M,'D',30,'maxFE',300);
            expectedD = 30 + (ismember(M,[10,20]) && ismember(problem,{'WFG2','WFG3'}));
            assert(pro.D==expectedD && pro.M==M && pro.N==100);
            for ai = 1:7
                alg = cfg.algorithms{ai};
                folder = fullfile(cfg.dataFolders{mi},alg);
                for ri = 1:30
                    name = sprintf('%s_%s_M%d_D%d_%d.mat',alg,problem,M,pro.D,ri);
                    file = fullfile(folder,name);
                    recovery = fullfile(folder,'supplement30',name);
                    job = struct('algorithm',alg,'algorithmFolder',cfg.algorithmFolders{ai}, ...
                        'problem',problem,'M',M,'D',pro.D,'runId',ri, ...
                        'seed',20260912+M*100000+pi*1000+ri, ...
                        'parameters',{cfg.parameters{ai}},'file',file, ...
                        'logs',cfg.logs,'manifestFile',manifestFile,'kind','optimize');
                    % A repaired replacement takes precedence over an invalid legacy file.
                    [valid,reason,fe,igd,provenance] = inspectResult(recovery,job);
                    source = recovery;
                    if ~valid
                        [valid,reason,fe,igd,provenance] = inspectResult(file,job);
                        source = file;
                    end
                    state = 'existing';
                    if valid
                        counts(mi,ai) = counts(mi,ai)+1;
                    else
                        state = 'pending';
                        if isfile(file), job.file = recovery; end
                        % Do not silently overwrite a damaged replacement either.
                        if isfile(job.file)
                            state = 'conflict';
                            reason = ['Invalid supplement file requires inspection: ',reason];
                        else
                            if isempty(jobs), jobs=job; else, jobs(end+1)=job; end %#ok<AGROW>
                        end
                        source = job.file;
                    end
                    row = struct('algorithm',alg,'problem',problem,'M',M,'D',pro.D, ...
                        'runId',ri,'state',state,'actualFE',fe,'IGD',igd, ...
                        'provenance',provenance,'note',reason,'file',source);
                    if isempty(rows), rows=row; else, rows(end+1)=row; end %#ok<AGROW>
                end
            end
        end
        fprintf('M=%d existing: %d / 3360\n',M,sum(counts(mi,:)));
    end
    audit = struct2table(rows);
    writetable(audit,fullfile(cfg.logs,['inventory_',stamp,'.csv']),'Encoding','UTF-8');
    writetable(audit,fullfile(cfg.logs,'inventory_latest.csv'),'Encoding','UTF-8');
    summary = array2table(counts,'VariableNames',cfg.labels,'RowNames',{'M10','M15','M20'});
    disp(summary);
    conflicts = sum(strcmp({rows.state},'conflict'));
    fprintf('Existing=%d; pending=%d; conflicts=%d; total=10080.\n',sum(counts,'all'),numel(jobs),conflicts);
    fprintf('Legacy files without per-run metadata are marked legacy-unverified.\n');
    fprintf('Actual FE above 300 is retained and reported, not called equal-budget.\n');
    if strcmp(action,'check'), return; end
    assert(conflicts==0,'Resolve conflicting supplement files shown in inventory before running.');
    if isempty(jobs), fprintf('COMPLETE: all requested runs already exist.\n'); return; end
    % Whole-run lock prevents duplicate launches without touching old results.
    lockFile = fullfile(cfg.logs,'RUNNING.lock');
    lock = java.io.File(lockFile);
    assert(lock.createNewFile(),'Another runner is active, or RUNNING.lock is stale. See README.');
    lockCleanup = onCleanup(@()deleteIfPresent(lockFile)); %#ok<NASGU>
    diary(fullfile(cfg.logs,['run_',stamp,'.log']));
    diaryCleanup = onCleanup(@()diary('off')); %#ok<NASGU>
    pool = gcp('nocreate');
    if isempty(pool), pool=parpool('Processes',workers); end
    assert(isa(pool,'parallel.ProcessPool'),'Use a process pool, not a thread pool.');
    fprintf('Pool has %d workers; this runner uses at most %d.\n',pool.NumWorkers,min(workers,pool.NumWorkers));
    setup = parfevalOnAll(pool,@prepareWorker,0,platform,root);
    fetchOutputs(setup);
    % Submit bounded waves, so a very large pool cannot exceed requested concurrency.
    capacity = min(workers,pool.NumWorkers);
    failures = 0;
    completed = 0;
    for first = 1:capacity:numel(jobs)
        last = min(first+capacity-1,numel(jobs));
        futures = parallel.FevalFuture.empty;
        for ji = first:last
            futures(end+1)=parfeval(pool,@runOne,1,jobs(ji)); %#ok<AGROW>
        end
        cancelCleanup = onCleanup(@()cancel(futures));
        for ji = first:last
            [~,status]=fetchNext(futures);
            completed=completed+1;
            if status.ok
                fprintf('[%d/%d] %s %s M%d run %02d FE=%d IGD=%.8g saved\n', ...
                    completed,numel(jobs),status.algorithm,status.problem,status.M,status.runId,status.FE,status.IGD);
            else
                failures=failures+1;
                fprintf(2,'[%d/%d] FAILED %s %s M%d run %02d: %s\n', ...
                    completed,numel(jobs),status.algorithm,status.problem,status.M,status.runId,status.message);
            end
        end
        clear cancelCleanup
    end
    fprintf('Finished: %d successful; %d failed. Rerun the same command to retry missing runs.\n',completed-failures,failures);
    assert(failures==0,'Some runs failed; see individual error logs.');
end

function cfg = configuration(root,platform)
    cfg = struct('platform',platform,'logs',fullfile(root,'diagnostics','paper_30runs'));
    cfg.objectives=[10,15,20];
    dataRoot='C:/Users/lsx/Desktop/REMOandDREMO测试集';
    cfg.dataFolders={fullfile(dataRoot,'10目标','n30'),fullfile(dataRoot,'15目标'),fullfile(dataRoot,'20目标')};
    cfg.algorithms={'REMO','PIEA','CSEA','PCSAEA_N100','KRVEA_100','MCEAD', ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'};
    cfg.labels={'REMO','PIEA','CSEA','PCSAEA_N100','KRVEA_100','MCEAD','Weighted'};
    sub={'REMO','PIEA','CSEA','PC-SAEA','K-RVEA','MCEA-D',cfg.algorithms{7}};
    cfg.parameters={{6,3000},{5,20,20},{6,3000},{0.8,3000},{2,20,5},{0.9,2,10},{3000,0.50,0.25,0.70,6}};
    cfg.problems=[arrayfun(@(i)sprintf('DTLZ%d',i),1:7,'UniformOutput',false), ...
        arrayfun(@(i)sprintf('WFG%d',i),1:9,'UniformOutput',false)];
    cfg.algorithmFolders=cell(1,7);
    for i=1:7
        cfg.algorithmFolders{i}=fullfile(platform,'Algorithms','Multi-objective optimization',sub{i});
        assert(strcmpi(fileparts(which(cfg.algorithms{i})),cfg.algorithmFolders{i}), ...
            'Unexpected algorithm path: %s',cfg.algorithms{i});
        a=feval(cfg.algorithms{i},'parameter',cfg.parameters{i},'outputFcn',@(~,~)[]);
        assert(isequal(a.parameter,cfg.parameters{i}));
    end
end

function [valid,reason,fe,igd,provenance] = inspectResult(file,job)
    valid=false; reason='missing'; fe=NaN; igd=NaN; provenance='';
    if ~isfile(file), return; end
    try
        names=who('-file',file);
        wanted=intersect(names,{'result','metric','metadata'});
        d=load(file,wanted{:});
        assert(isfield(d,'result') && iscell(d.result) && size(d.result,2)==2 && ~isempty(d.result),'Missing result.');
        fe=d.result{end,1};
        % Legacy REMO/CSEA may overshoot by the final batch. No altered baseline.
        upper=300;
        if ismember(job.algorithm,{'REMO','CSEA'}), upper=399; end
        assert(isscalar(fe) && isfinite(fe) && fe>=300 && fe<=upper,'Unexpected final FE.');
        pop=d.result{end,2};
        assert(isa(pop,'SOLUTION') && ~isempty(pop),'Missing solution population.');
        objs=pop.objs; decs=pop.decs;
        assert(size(objs,2)==job.M && size(decs,2)==job.D && all(isfinite(objs),'all') && all(isfinite(decs),'all'),'Invalid dimensions or nonfinite population.');
        fes=cell2mat(d.result(:,1));
        assert(all(isfinite(fes)) && all(diff(fes)>=0) && fes(1)>=1,'Invalid FE trajectory.');
        provenance='legacy-unverified';
        if isfield(d,'metadata')
            md=d.metadata;
            fields={'algorithm','problem','M','D','maxFE','runId'};
            values={job.algorithm,job.problem,job.M,job.D,300,job.runId};
            for k=1:numel(fields)
                if isfield(md,fields{k})
                    assert(isequal(md.(fields{k}),values{k}),'Metadata mismatch: %s',fields{k});
                end
            end
            if isfield(md,'parameters')
                assert(isequal(md.parameters,job.parameters),'Algorithm parameters differ.');
                provenance='metadata-checked';
            end
            if isfield(md,'N'), assert(md.N==100,'Configured N differs.'); end
        end
        if isfield(d,'metric') && isfield(d.metric,'IGD') && ~isempty(d.metric.IGD)
            igd=d.metric.IGD(end);
            assert(isfinite(igd) && igd>=0,'Invalid saved IGD.');
        end
        reason='';
        if isnan(igd), reason='Population complete; IGD absent; reuse without rerunning optimization.'; end
        if fe>300, reason=[reason,' Historical final-batch FE overshoot retained.']; end
        valid=true;
    catch err
        reason=err.message;
    end
end

function prepareWorker(platform,root)
    addpath(genpath(platform));
    addpath(root);
    set(groot,'defaultFigureVisible','off');
end

function message=verifyWorker(cfg)
    % Exercise worker resolution and resume validation, without optimization.
    for i=1:7
        addpath(cfg.algorithmFolders{i});
        assert(strcmpi(fileparts(which(cfg.algorithms{i})),cfg.algorithmFolders{i}));
        a=feval(cfg.algorithms{i},'parameter',cfg.parameters{i},'outputFcn',@(~,~)[]);
        assert(isequal(a.parameter,cfg.parameters{i}));
    end
    p=DTLZ2('N',100,'M',15,'D',30,'maxFE',300);
    pop=p.Evaluation(0.5*ones(2,30));
    result={100,pop;100,pop;300,pop};
    metric=struct('IGD',1);
    file=[tempname,'.mat'];
    cleaner=onCleanup(@()deleteIfPresent(file)); %#ok<NASGU>
    j=struct('algorithm',cfg.algorithms{7},'problem','DTLZ2','M',15,'D',30, ...
        'runId',1,'parameters',{cfg.parameters{7}});
    save(file,'result','metric');
    [valid,~,~,~,provenance]=inspectResult(file,j);
    assert(valid && strcmp(provenance,'legacy-unverified'),'Complete legacy file must be reused, including repeated FE snapshots.');
    metadata=struct('parameters',{{3000,0.50,0.25,0.80,6}});
    save(file,'metadata','-append');
    assert(~inspectResult(file,j),'Q080 must not be reused as Weighted Q070.');
    result{end,1}=299;
    save(file,'result','metric');
    assert(~inspectResult(file,j),'Incomplete result must not count as complete.');
    message='PASS: process-worker setup, seven algorithm constructors, complete/duplicate-FE reuse, parameter mismatch and incomplete-result rejection. No optimization run started.';
end

function status=runOne(job)
    status=struct('ok',false,'algorithm',job.algorithm,'problem',job.problem, ...
        'M',job.M,'runId',job.runId,'FE',NaN,'IGD',NaN,'message','');
    previousPath=path;
    previousWarnings=warning;
    cleanup=onCleanup(@()restoreWorker(previousPath,previousWarnings)); %#ok<NASGU>
    temporary='';
    try
        assert(~isfile(job.file),'Result now exists; rerun inventory to reuse it.');
        addpath(job.algorithmFolder);
        assert(strcmpi(fileparts(which(job.algorithm)),job.algorithmFolder),'Unexpected algorithm resolution.');
        frozen=load(job.manifestFile,'manifest');
        entries=frozen.manifest;
        for k=1:numel(entries)
            if strcmp(entries(k).algorithm,job.algorithm)
                assert(strcmp(entries(k).sha256,sha256(entries(k).file)),'Source changed during experiment: %s',entries(k).file);
            end
        end
        pro=feval(job.problem,'N',100,'M',job.M,'D',30,'maxFE',300);
        assert(pro.D==job.D);
        % Keep Weighted's historical fixed mode-stream ID. Global seeds vary.
        alg=feval(job.algorithm,'parameter',job.parameters,'save',30,'run',1,'outputFcn',@(~,~)[]);
        rng(job.seed,'twister');
        metadata=struct('algorithm',job.algorithm,'problem',job.problem,'runId',job.runId, ...
            'seed',job.seed,'modeRunId',1,'parameters',{job.parameters},'N',100, ...
            'M',job.M,'D',job.D,'maxFE',300,'save',30,'matlabVersion',version, ...
            'sourceManifest',job.manifestFile,'rngBeforeSolve',rng, ...
            'started',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        alg.Solve(pro);
        assert(~isempty(alg.result) && pro.FE>=300 && alg.result{end,1}==pro.FE,'Incomplete run.');
        result=alg.result; metric=alg.metric;
        metadata.actualFE=pro.FE;
        metadata.finalN=pro.N;
        metadata.finished=char(datetime('now','Format','yyyy-MM-dd HH:mm:ss'));
        folder=fileparts(job.file);
        if ~isfolder(folder), mkdir(folder); end
        temporary=[tempname(folder),'.mat'];
        % First preserve complete populations. Metric failure must not cause a rerun.
        save(temporary,'result','metric','metadata','-v7');
        try
            alg.CalMetric('IGD');
            metric=alg.metric;
            assert(all(isfinite(metric.IGD)) && all(metric.IGD>=0),'Invalid IGD.');
            save(temporary,'metric','-append');
            status.IGD=metric.IGD(end);
        catch metricError
            metadata.metricError=metricError.message;
            save(temporary,'metadata','-append');
        end
        [valid,reason]=inspectResult(temporary,job);
        assert(valid,'Saved output invalid: %s',reason);
        assert(~isfile(job.file),'Refusing to overwrite a result.');
        [ok,message]=movefile(temporary,job.file);
        assert(ok,'%s',message);
        temporary='';
        status.ok=true; status.FE=pro.FE;
    catch err
        status.message=err.message;
        logFile=fullfile(job.logs,sprintf('%s_%s_M%d_run%02d_error.txt',job.algorithm,job.problem,job.M,job.runId));
        fid=fopen(logFile,'w','n','UTF-8');
        if fid>=0, fprintf(fid,'%s',getReport(err,'extended','hyperlinks','off')); fclose(fid); end
        % A temporary file is intentionally retained for recovery, never counted complete.
        if ~isempty(temporary), fprintf(2,'Recovery file: %s\n',temporary); end
    end
end

function restoreWorker(oldPath,oldWarnings)
    path(oldPath);
    warning(oldWarnings);
end

function manifest=sourceManifest(cfg)
    manifest=struct([]);
    for a=1:7
        files=dir(fullfile(cfg.algorithmFolders{a},'**','*.m'));
        for i=1:numel(files)
            file=fullfile(files(i).folder,files(i).name);
            relative=erase(file,[cfg.algorithmFolders{a},filesep]);
            if contains(relative,['diagnostics',filesep]) || contains(relative,['tests',filesep]) || startsWith(files(i).name,'Run'), continue; end
            entry=struct('algorithm',cfg.algorithms{a},'file',file,'sha256',sha256(file));
            if isempty(manifest), manifest=entry; else, manifest(end+1)=entry; end %#ok<AGROW>
        end
    end
    % This is an algorithm-folder manifest, not a complete dependency closure.
end

function hash=sha256(file)
    fid=fopen(file,'rb');
    assert(fid>=0,'Cannot read source: %s',file);
    closeFile=onCleanup(@()fclose(fid)); %#ok<NASGU>
    bytes=fread(fid,Inf,'*uint8');
    digest=java.security.MessageDigest.getInstance('SHA-256');
    digest.update(bytes);
    hash=lower(reshape(dec2hex(typecast(digest.digest(),'uint8'),2).',1,[]));
end

function deleteIfPresent(file)
    if isfile(file), delete(file); end
end
