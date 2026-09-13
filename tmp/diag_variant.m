function diag_variant(which,nRuns,maxFE,seedBase)
%DIAG_VARIANT Isolate which run-time option triggers the MATLAB crash.
%   which = 1: GUI-like  (default outputFcn, save=18, metName {'IGD'}, no 'run')
%   which = 2: harness   (outputFcn no-op, save=18, 'run',r, CalMetric after)
%   which = 3: harness but no explicit rng seeding
    if nargin < 1 || isempty(which),   which   = 1; end
    if nargin < 2 || isempty(nRuns),   nRuns   = 6; end
    if nargin < 3 || isempty(maxFE),   maxFE   = 120; end
    if nargin < 4 || isempty(seedBase),seedBase = 20260911; end

    platemoRoot = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    scratch     = fullfile('D:\PlatEMO-master\tmp\diag_scratch', sprintf('v%d',which));
    if ~isfolder(scratch), mkdir(scratch); end
    cd(scratch);
    logFile = fullfile(scratch,'diag.log');

    lg = @(varargin)diaglog(logFile,varargin{:});
    lg('==== variant %d | runs %d | maxFE %d | cwd %s ====',which,nRuns,maxFE,scratch);
    lg('matlab %s | threads %d | java %s',version,feature('numcores'),version('-java'));

    addpath(genpath(platemoRoot));
    rehash;
    algName = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned';
    params  = {3000,0.50,0.25,0.70,6};

    for r = 1:nRuns
        lg('--- run %d/%d starting ---',r,nRuns);
        t0 = tic;
        try
            if which ~= 3
                rng(seedBase + 1000*1 + r,'twister');
            end
            PRO = DTLZ2('N',100,'M',10,'D',30,'maxFE',maxFE);
            switch which
                case 1
                    ALG = feval(algName,'parameter',params,'save',18,'metName',{'IGD'});
                case 2
                    ALG = feval(algName,'parameter',params,'save',18,'run',r,'outputFcn',@(varargin)[]);
                case 3
                    ALG = feval(algName,'parameter',params,'save',18,'run',r,'outputFcn',@(varargin)[]);
                otherwise
                    error('bad variant');
            end
            ALG.Solve(PRO);
            if which ~= 1
                ALG.CalMetric('IGD');
            end
            igd = ALG.metric.IGD;
            lg('--- run %d OK: FE=%d IGD(end)=%.6f runtime=%.1fs wall=%.1fs ---', ...
                r,ALG.pro.FE,igd(end),ALG.metric.runtime,toc(t0));
            clear ALG PRO igd;
        catch err
            lg('!!! run %d ERROR: %s | %s',r,err.identifier,err.message);
        end
    end
    lg('==== variant %d finished all %d runs ====',which,nRuns);
end

function diaglog(logFile,varargin)
    msg   = sprintf(varargin{:});
    stamp = datestr(now,'yyyy-mm-dd HH:MM:SS');
    line  = sprintf('[%s] %s',stamp,msg);
    fprintf('%s\n',line);
    fid = fopen(logFile,'a');
    if fid >= 0
        fprintf(fid,'%s\n',line);
        fclose(fid);
    end
end
