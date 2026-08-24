function hcv_screen(nRuns,probsIn,MsIn)
% Paired low-cost screen: baseline vs HCV variants, identical seeds, 500 FE.
% Parallel over the (problem,M,config,run) grid via parfor.
%
% Usage:  hcv_screen           -> 3 runs, DTLZ2/WFG3, M=10/20   (smoke screen)
%         hcv_screen(5)        -> 5 runs
%         hcv_screen(5,{'DTLZ2','DTLZ4','WFG3','WFG7'},[10 20])

    if nargin < 1 || isempty(nRuns),  nRuns = 3;                      end
    if nargin < 2 || isempty(probsIn), probsIn = {'DTLZ2','WFG3'};     end
    if nargin < 3 || isempty(MsIn),    MsIn = [10 20];                 end

    root = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    addpath(genpath(root));

    maxFE = 500;  D = 30;  N = 100;
    % cfg: {label, parameter cell (empty = baseline defaults), class name}
    cfgs = { 'Base', {},                                        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original'
             'nH0',  {3000,0.50,0.25,0.80,0.35,4,6,0,0},        'REMO_new2_AdaMaO_HCV'
             'nH2',  {3000,0.50,0.25,0.80,0.35,4,6,2,0},        'REMO_new2_AdaMaO_HCV'
             'nH3',  {3000,0.50,0.25,0.80,0.35,4,6,3,0},        'REMO_new2_AdaMaO_HCV'
             'nH2w', {3000,0.50,0.25,0.80,0.35,4,6,2,1},        'REMO_new2_AdaMaO_HCV' };

    % flatten the grid so parfor gets one flat loop
    job = struct('prob',{},'M',{},'ci',{},'run',{});
    for pi = 1:numel(probsIn)
        for mi = 1:numel(MsIn)
            for ci = 1:size(cfgs,1)
                for r = 1:nRuns
                    job(end+1) = struct('prob',probsIn{pi},'M',MsIn(mi), ...
                        'ci',ci,'run',r); %#ok<AGROW>
                end
            end
        end
    end
    nJob = numel(job);
    fprintf('grid: %d jobs (%d problems x %d M x %d cfgs x %d runs)\n', ...
        nJob,numel(probsIn),numel(MsIn),size(cfgs,1),nRuns);

    pool = gcp('nocreate');
    if isempty(pool)
        pool = parpool('local');
    end
    fprintf('parpool workers: %d\n',pool.NumWorkers);

    igd = nan(nJob,1);  hv = nan(nJob,1);  sec = nan(nJob,1);
    err = strings(nJob,1);

    parfor j = 1:nJob
        addpath(genpath(root));
        t0 = tic;
        try
            pro = feval(job(j).prob,'N',N,'M',job(j).M,'D',D, ...
                'maxFE',maxFE,'maxRuntime',inf);
            par = cfgs{job(j).ci,2};
            if isempty(par)
                alg = feval(cfgs{job(j).ci,3},'save',0, ...
                    'outputFcn',@(varargin)[],'run',job(j).run);
            else
                alg = feval(cfgs{job(j).ci,3},'parameter',par,'save',0, ...
                    'outputFcn',@(varargin)[],'run',job(j).run);
            end
            rng(20260822+job(j).run,'twister');
            alg.Solve(pro);
            P = alg.result{end};
            igd(j) = pro.CalMetric('IGD',P);
            hv(j)  = pro.CalMetric('HV',P);
        catch ME
            err(j) = string(ME.message);
        end
        sec(j) = toc(t0);
        fprintf('  [%3d/%3d] %-6s M=%2d %-5s r=%d  IGD=%s  %.0fs\n', ...
            j,nJob,job(j).prob,job(j).M,cfgs{job(j).ci,1},job(j).run, ...
            num2str(igd(j),'%.4f'),sec(j));
    end

    res = struct('job',job,'igd',igd,'hv',hv,'sec',sec,'err',err, ...
        'cfgs',{cfgs},'maxFE',maxFE,'D',D);
    save(fullfile(fileparts(mfilename('fullpath')),'hcv_screen_res.mat'),'res');
    report(job,igd,hv,sec,err,cfgs);
end

function report(job,igd,hv,sec,err,cfgs)
    labels = cfgs(:,1)';
    fprintf('\n=== median IGD (lower better), %d cfgs ===\n',numel(labels));
    fprintf('%-7s %-3s',' prob','M');
    for c = 1:numel(labels), fprintf(' %-9s',labels{c}); end
    fprintf(' | vs Base\n');

    probs = unique({job.prob});  Ms = unique([job.M]);
    for pi = 1:numel(probs)
        for mi = 1:numel(Ms)
            med = nan(1,numel(labels));  medh = nan(1,numel(labels));
            for c = 1:numel(labels)
                k = strcmp({job.prob},probs{pi}) & [job.M]==Ms(mi) & [job.ci]==c;
                v = igd(k);  v = v(isfinite(v));
                if ~isempty(v), med(c) = median(v); end
                w = hv(k);   w = w(isfinite(w));
                if ~isempty(w), medh(c) = median(w); end
            end
            fprintf('%-7s %-3d',probs{pi},Ms(mi));
            for c = 1:numel(labels), fprintf(' %-9.4f',med(c)); end
            win = '';
            for c = 2:numel(labels)
                if isfinite(med(c)) && isfinite(med(1)) && med(c) < med(1)
                    win = [win ' ' labels{c} sprintf('(%+.1f%%)', ...
                        100*(med(c)/med(1)-1))]; %#ok<AGROW>
                end
            end
            if isempty(win), win = ' none'; end
            fprintf(' |%s\n',win);
            fprintf('%-7s %-3s',' (HV)','');
            for c = 1:numel(labels), fprintf(' %-9.4f',medh(c)); end
            fprintf(' |\n');
        end
    end

    nerr = sum(strlength(err)>0);
    fprintf('\nruntime: median %.0fs, max %.0fs per run | errors: %d\n', ...
        median(sec(isfinite(sec))),max(sec(isfinite(sec))),nerr);
    if nerr > 0
        u = unique(err(strlength(err)>0));
        for i = 1:min(3,numel(u)), fprintf('  ERR: %s\n',u(i)); end
    end
end
