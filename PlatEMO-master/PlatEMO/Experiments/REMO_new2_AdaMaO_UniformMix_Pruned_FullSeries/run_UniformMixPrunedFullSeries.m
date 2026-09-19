function summary = run_UniformMixPrunedFullSeries(part,nParts,varargin)
%RUN_UNIFORMMIXPRUNEDFULLSERIES Resumable DTLZ+WFG sweep for the Pruned variant.
%   SUMMARY = RUN_UNIFORMMIXPRUNEDFULLSERIES(PART,NPARTS) runs the slice of
%   problems assigned to worker PART (1..NPARTS) with round-robin assignment
%   (problemGlobalIndex = PART : NPARTS : numel(Problems)).
%
%   Every completed run is written to its own MAT file that mirrors the
%   PlatEMO experiment-module convention:
%       <FolderName>/<Algorithm>_<Problem>_M<M>_D<D>_<run>.mat
%   and contains the variables `result` (SAVECOUNT x 2 cell: {FE, Population})
%   and `metric` (struct with `runtime` and `IGD`, one IGD value per snapshot).
%   The file is named with Problem.D, so WFG2/WFG3 land on _M10_D31_.
%
%   Existing valid files are skipped, which makes the sweep resumable.
%
%   Name-value options: OutputRoot, FolderName, Algorithm, Problems, Runs, M,
%   D, MaxFE, N, Parameters, SaveCount, SeedBase, SeedMode, PlatEMORoot,
%   LogFile, Warmup, SummaryCsvDir, ExtraMetrics.

    if nargin < 1 || isempty(part),   part   = 1; end
    if nargin < 2 || isempty(nParts), nParts = 1; end
    part   = max(1,round(double(part)));
    nParts = max(1,round(double(nParts)));
    if part > nParts
        error('PrunedFullSeries:BadPartition','part must be in 1..nParts.');
    end

    parser = inputParser();
    parser.FunctionName = mfilename();
    parser.addParameter('OutputRoot', 'D:\REMOandDREMO测试集\10目标\n30', @(s)ischar(s)||isstring(s));
    parser.addParameter('FolderName', 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned', @(s)ischar(s)||isstring(s));
    parser.addParameter('Algorithm',  'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned', @(s)ischar(s)||isstring(s));
    parser.addParameter('Problems',   {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                                       'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'}, @iscell);
    parser.addParameter('Runs',       18,   @(v)isnumeric(v)&&isvector(v)&&~isempty(v)&&all(v>=1));
    parser.addParameter('M',          10,   @(v)isnumeric(v)&&isscalar(v));
    parser.addParameter('D',          30,   @(v)isnumeric(v)&&isscalar(v));
    parser.addParameter('MaxFE',      300,  @(v)isnumeric(v)&&isscalar(v));
    parser.addParameter('N',          100,  @(v)isnumeric(v)&&isscalar(v));
    parser.addParameter('Parameters', {3000,0.50,0.25,0.70,6}, @iscell);
    parser.addParameter('SaveCount',  18,   @(v)isnumeric(v)&&isscalar(v)&&v>=1);
    parser.addParameter('SeedBase',   20260911, @(v)isnumeric(v)&&isscalar(v));
    parser.addParameter('SeedMode',   'deterministic', @(s)ischar(s)||isstring(s));
    parser.addParameter('PlatEMORoot','D:\PlatEMO-master\PlatEMO-master\PlatEMO', @(s)ischar(s)||isstring(s));
    parser.addParameter('LogFile',    '', @(s)ischar(s)||isstring(s));
    parser.addParameter('Warmup',     true, @(v)islogical(v)||isnumeric(v));
    % Optional: where the per-slice summary CSV goes. Empty means "next to the
    % results", which is the historical behaviour; sweeping callers pass a logs
    % directory so the dataset folder stays MAT-only and parallel slices of the
    % same problem cannot clobber each other's CSV.
    parser.addParameter('SummaryCsvDir','', @(s)ischar(s)||isstring(s));
    % Optional extra metrics to store alongside IGD (e.g. {'IGDp'}). Empty by
    % default, so every existing caller keeps its exact previous behaviour.
    parser.addParameter('ExtraMetrics',{}, @iscell);
    parser.parse(varargin{:});
    o = parser.Results;

    o.OutputRoot  = char(string(o.OutputRoot));
    o.FolderName  = char(string(o.FolderName));
    o.Algorithm   = char(string(o.Algorithm));
    o.SeedMode    = char(string(o.SeedMode));
    o.PlatEMORoot = char(string(o.PlatEMORoot));
    o.SummaryCsvDir = char(string(o.SummaryCsvDir));
    o.ExtraMetrics  = cellfun(@char,o.ExtraMetrics(:)','UniformOutput',false);

    if isscalar(o.Runs)
        o.RunList = 1:round(double(o.Runs));
    else
        o.RunList = round(double(o.Runs(:)'));
    end
    o.Runs = numel(o.RunList);

    outDir = fullfile(o.OutputRoot,o.FolderName);
    if ~isfolder(outDir), mkdir(outDir); end

    % Remove leftovers from an interrupted save (results are written through a
    % temporary file, so a "*.tmp.mat" means the process died mid-write).
    leftovers = dir(fullfile(outDir,'*.tmp.mat'));
    for i = 1:numel(leftovers)
        delete(fullfile(outDir,leftovers(i).name));
    end

    if isempty(o.LogFile)
        o.LogFile = fullfile(outDir, sprintf('_runlog_part%dof%d.txt',part,nParts));
    end
    fid = fopen(o.LogFile,'a');
    if fid >= 0
        fprintf(fid,'==== part %d/%d start %s ====\n',part,nParts,datestr(now,'yyyy-mm-dd HH:MM:SS'));
        fclose(fid);
    end

    logMsg = @(varargin)localLog(o.LogFile,varargin{:});

    logMsg('PlatEMO root: %s',o.PlatEMORoot);
    addpath(genpath(o.PlatEMORoot));
    rehash;

    assert(exist(o.Algorithm,'class')==8,'PrunedFullSeries:NoAlgorithm','Cannot find class %s.',o.Algorithm);
    expectedParamCount = 5;
    assert(numel(o.Parameters)<=expectedParamCount,'PrunedFullSeries:TooManyParameters', ...
        'Expected at most %d algorithm parameters, got %d.',expectedParamCount,numel(o.Parameters));

    if o.Warmup
        localWarmup();
    end

    list     = o.Problems(:)';
    myIdx    = part:nParts:numel(list);
    myList   = list(myIdx);
    logMsg('Algorithm %s | parameters [%s]',o.Algorithm,num2str(cell2mat(o.Parameters)));
    logMsg('SaveCount %d | Runs %d | M %d | requested D %d | N %d | maxFE %d | Seeds %s(base=%d)', ...
        o.SaveCount,o.Runs,o.M,o.D,o.N,o.MaxFE,o.SeedMode,o.SeedBase);
    logMsg('Slice %d/%d -> %d problems: %s',part,nParts,numel(myList),strjoin(myList,', '));

    summary      = struct('Problem',{},'Run',{},'File',{},'Status',{},'IGD',{},'Runtime',{},'FE',{},'D',{},'Seconds',{});
    totalRuns    = 0;
    skippedRuns  = 0;
    tSweepStart  = tic;

    for ip = 1:numel(myList)
        problemName = myList{ip};
        globalIndex = myIdx(ip);

        PRO = feval(problemName,'N',o.N,'M',o.M,'D',o.D,'maxFE',o.MaxFE); %#ok<NASGU>
        actualD = PRO.D;
        actualFE = PRO.maxFE;
        logMsg('--- %s (global #%d): M=%d D=%d maxFE=%d ---',problemName,globalIndex,PRO.M,actualD,actualFE);

        for r = o.RunList
            totalRuns = totalRuns + 1;
            fname = fullfile(outDir,sprintf('%s_%s_M%d_D%d_%d.mat',o.Algorithm,problemName,PRO.M,actualD,r));

            if isfile(fname)
                chk = localValidateRunFile(fname,o.SaveCount,actualFE);
                if chk.Valid
                    skippedRuns = skippedRuns + 1;
                    logMsg('[skip] %s (valid, final IGD %.6f)',fname,chk.FinalIGD);
                    summary(end+1) = localRow(problemName,r,fname,'skipped',chk.FinalIGD,chk.Runtime,chk.FE,actualD,0); %#ok<AGROW>
                    continue;
                else
                    logMsg('[redo] %s (%s)',fname,chk.Detail);
                end
            end

            t0 = tic;
            if strcmpi(o.SeedMode,'deterministic')
                % Deterministic, unique per (problem, run) pair.
                rng(o.SeedBase + 1000*globalIndex + r,'twister');
            end

            ALG = feval(o.Algorithm, ...
                'parameter',o.Parameters, ...
                'save',o.SaveCount, ...
                'run',r, ...
                'outputFcn',@(varargin)[]);
            ALG.Solve(PRO);
            ALG.CalMetric('IGD');
            for im = 1:numel(o.ExtraMetrics)
                ALG.CalMetric(o.ExtraMetrics{im});
            end

            result = ALG.result; %#ok<NASGU>
            metric = ALG.metric; %#ok<NASGU>

            feList = cellfun(@(x)x,result(:,1));
            bOK    = ~isempty(metric.IGD) && all(isfinite(metric.IGD)) && feList(end) == actualFE;
            if ~bOK
                logMsg('[warn] %s final FE=%s IGD tail=%s',fname,mat2str(feList(end)),mat2str(metric.IGD(end)));
            end

            tmpName = [fname '.tmp.mat'];
            save(tmpName,'result','metric');
            movefile(tmpName,fname,'f');

            chk = localValidateRunFile(fname,o.SaveCount,actualFE);
            elapsed = toc(t0);
            logMsg('[done] %s run %d | IGD first %g -> final %g | runtime %.1fs | wall %.1fs | %s', ...
                problemName,r,metric.IGD(1),metric.IGD(end),metric.runtime,elapsed,chk.Detail);
            summary(end+1) = localRow(problemName,r,fname,'done',chk.FinalIGD,metric.runtime,chk.FE,actualD,elapsed); %#ok<AGROW>
        end
    end

    sweepSeconds = toc(tSweepStart);
    logMsg('==== part %d/%d done: %d runs (%d skipped) in %.1f s (%.1f h) ====', ...
        part,nParts,totalRuns,skippedRuns,sweepSeconds,sweepSeconds/3600);

    if ~isempty(summary)
        csvDir = o.SummaryCsvDir;
        if isempty(csvDir)
            csvDir = outDir;
        elseif ~isfolder(csvDir)
            mkdir(csvDir);
        end
        csvName = fullfile(csvDir, ...
            sprintf('_%s_runlog_part%dof%d.csv',o.FolderName,part,nParts));
        T = struct2table(summary);
        writetable(T,csvName);
        logMsg('Summary CSV: %s',csvName);
    end
end

function row = localRow(problemName,r,fname,status,igd,rt,fe,d,secs)
    row = struct('Problem',problemName,'Run',r,'File',fname,'Status',status, ...
        'IGD',igd,'Runtime',rt,'FE',fe,'D',d,'Seconds',secs);
end

function localLog(logFile,varargin)
    msg = sprintf(varargin{:});
    stamp = datestr(now,'yyyy-mm-dd HH:MM:SS');
    line = sprintf('[%s] %s',stamp,msg);
    fprintf('%s\n',line);
    fid = fopen(logFile,'a');
    if fid >= 0
        fprintf(fid,'%s\n',line);
        fclose(fid);
    end
end

function chk = localValidateRunFile(fname,expectCount,expectFE)
    chk = struct('Valid',false,'Detail','','FinalIGD',NaN,'Runtime',NaN,'FE',NaN);
    try
        info = whos('-file',fname);
        names = {info.name};
        if ~all(ismember({'result','metric'},names))
            chk.Detail = sprintf('missing variables: %s',strjoin(setdiff({'result','metric'},names),',')); return;
        end
        S = load(fname,'result','metric');
        if isempty(S.metric) || ~isfield(S.metric,'IGD')
            chk.Detail = 'metric.IGD missing'; return;
        end
        igd = S.metric.IGD;
        if numel(igd) > expectCount
            chk.Detail = sprintf('IGD length %d > %d',numel(igd),expectCount); return;
        end
        if any(~isfinite(igd))
            chk.Detail = 'IGD contains non-finite values'; return;
        end
        feList = cellfun(@(x)x,S.result(:,1));
        if numel(feList) ~= numel(igd)
            chk.Detail = sprintf('result rows %d ~= IGD length %d',numel(feList),numel(igd)); return;
        end
        if feList(end) ~= expectFE
            chk.Detail = sprintf('final FE %g ~= %g',feList(end),expectFE); return;
        end
        chk.Valid    = true;
        chk.FinalIGD = igd(end);
        chk.FE       = feList(end);
        if isfield(S.metric,'runtime'), chk.Runtime = S.metric.runtime; end
        chk.Detail   = 'ok';
    catch err
        chk.Detail = sprintf('read error: %s',err.message);
    end
end

function localWarmup()
%LOCALWARMUP Touch the toolboxes used by the relation/indicator models so that
%   first-run loading cost is not charged to the measured runtime.
    try
        rng(1,'twister');
        X = rand(24,6); Y = ones(24,1); Y(1:12) = 2;
        net = patternnet([9,6,3]);
        net.trainParam.showWindow = 0;
        net.trainParam.epochs = 3;
        train(net,X',Y');
    catch
    end
    try
        rng(1,'twister');
        fitrsvm(rand(40,6),rand(40,1),'KernelFunction','rbf','KernelScale','auto','Standardize',true);
    catch
    end
end
