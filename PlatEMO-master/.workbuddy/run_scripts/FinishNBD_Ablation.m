function FinishNBD_Ablation(Ms)
%FinishNBD_Ablation  Post-processing pipeline for the NoBatchDist ablation sweep.
%
%   FinishNBD_Ablation()      both objective counts (default [10 20])
%   FinishNBD_Ablation(10)    the 10-objective block only
%
%   Steps
%     1. coverage guard : refuse to continue unless every arm of every requested
%        objective count has all 16 problems x 20 runs, with 30 snapshots,
%        final FE = 300 and a stored IGD+ trace
%     2. IGD+ for the RMEO baseline, which carries only IGD
%        (REMO_k15 at M=10, REMO_k at M=20)
%     3. IGD+ for DTLZ7 at M=20 of the two new arms (the stock metric is
%        unusable there inside a pool, so it is filled in serially)
%     4. emit the raw IGD+ table texts, two tables per objective count
%
%   The Excel files are produced afterwards by
%       python build_nobatchdict_tables.py

    if nargin < 1 || isempty(Ms), Ms = [10 20]; end
    Ms = Ms(:)';

    testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    logDir   = 'D:\PlatEMO-master\PlatEMO-master\.workbuddy\ablation_logs';
    if ~isfolder(logDir), mkdir(logDir); end
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    runs = 1:20;

    logFile = fullfile(logDir,'finish.log');
    fid = fopen(logFile,'a');
    fprintf(fid,'\n######## FinishNBD_Ablation Ms=%s  %s\n', ...
        mat2str(Ms),char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));

    allArms = [];
    for M = Ms
        a = AblationArms(testRoot,M);
        if isempty(allArms), allArms = a; else, allArms = [allArms a]; end  %#ok<AGROW>
    end

    % ---- 1. coverage ----------------------------------------------------
    %   The historical baselines are only required to exist, to carry at least
    %   one snapshot and to have consumed at least 300 evaluations: their saved
    %   snapshot count (6..17 for REMO_k) and their FE overshoot (up to 311) are
    %   properties of the archived runs and cannot be changed here. Every arm
    %   produced by the current runner must have exactly 30 snapshots and end at
    %   FE = 300.
    missing = {};
    for a = 1:numel(allArms)
        d = allArms(a).dir; M = allArms(a).M; tag = allArms(a).tag;
        feLo = inf; feHi = 0; snaps = [];
        for p = 1:numel(problems)
            for r = runs
                f = dir(fullfile(d,sprintf('*_%s_M%d_D*_%d.mat',problems{p},M,r)));
                if numel(f) ~= 1
                    missing{end+1} = sprintf('%s M%d %s run%d (%d files)', ...
                        tag,M,problems{p},r,numel(f));                        %#ok<AGROW>
                    continue;
                end
                S = load(fullfile(d,f(1).name));
                nSnap  = size(S.result,1);
                feEnd  = double(S.result{end,1});
                snaps  = [snaps nSnap];                                      %#ok<AGROW>
                feLo = min(feLo,feEnd); feHi = max(feHi,feEnd);
                if allArms(a).snaps > 0 && nSnap ~= allArms(a).snaps
                    missing{end+1} = sprintf('%s M%d %s run%d : %d snapshots', ...
                        tag,M,problems{p},r,nSnap);                           %#ok<AGROW>
                elseif allArms(a).exactFE && feEnd ~= 300
                    missing{end+1} = sprintf('%s M%d %s run%d : final FE = %g', ...
                        tag,M,problems{p},r,feEnd);                           %#ok<AGROW>
                elseif ~allArms(a).exactFE && feEnd < 300
                    missing{end+1} = sprintf('%s M%d %s run%d : final FE = %g', ...
                        tag,M,problems{p},r,feEnd);                           %#ok<AGROW>
                elseif allArms(a).strict && ...
                        (~isfield(S.metric,'IGDp') || numel(S.metric.IGDp) ~= nSnap)
                    missing{end+1} = sprintf('%s M%d %s run%d : IGDp missing', ...
                        tag,M,problems{p},r);                                 %#ok<AGROW>
                end
            end
        end
        fprintf(fid,'[%s M%d] snapshots %d..%d, final FE %g..%g\n', ...
            tag,M,min(snaps),max(snaps),feLo,feHi);
    end
    if ~isempty(missing)
        fprintf(fid,'COVERAGE INCOMPLETE : %d problems\n',numel(missing));
        for i = 1:min(numel(missing),40), fprintf(fid,'   %s\n',missing{i}); end
        fclose(fid);
        error('FinishNBD_Ablation:Coverage','%d entries are missing or invalid.',numel(missing));
    end
    fprintf(fid,'coverage OK for Ms=%s\n',mat2str(Ms));
    fclose(fid);

    % ---- 2 + 3. fill in the missing IGD+ traces -------------------------
    %   MergeIGDpForDir keeps DTLZ7 at M=20 on the client (its 524288-point
    %   reference set has crashed the pool six times), so a pool is safe for
    %   the other 15 problems and saves most of the wall time.
    for M = Ms
        if M == 10
            MergeIGDpForDir('REMO_k15',10,1);
        else
            MergeIGDpForDir('REMO_k',20,5);
            RunNBD_Ablation('post','noCDIS',20,1);
            RunNBD_Ablation('post','noPAQC',20,1);
        end
    end

    % ---- 4. table payloads ----------------------------------------------
    for M = Ms
        BuildNBD_AblationTables(M);
    end

    fprintf('\nFINISH DONE for Ms=%s : now run  python build_nobatchdict_tables.py\n',mat2str(Ms));
end

% ------------------------------------------------------------------------
function arms = AblationArms(testRoot,M)
%AblationArms  tag / objective count / folder / guard flags.
%   strict  : the run files must already carry an IGD+ trace
%   snaps   : required snapshot count (0 = accept any archived count)
%   exactFE : the run must end exactly at FE = 300
    if M == 10
        sub  = fullfile('10目标','n30');
        remo = 'REMO_k15';
    else
        sub  = sprintf('%d目标',M);
        remo = 'REMO_k';
    end
    mk = @(tag,name,strict,snaps,exactFE) struct('tag',tag,'M',M, ...
        'dir',fullfile(testRoot,sub,name),'strict',strict, ...
        'snaps',snaps,'exactFE',exactFE);
    arms = [ ...
        mk(remo,remo,false,0,false), ...          % archived baseline, IGD only
        mk('full','REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist',false,30,true), ...
        mk('noCDIS','REMO_noBatchDict_noCDIS',M == 10,30,true), ...
        mk('noPAQC','REMO_noBatchDict_noPAQC',M == 10,30,true)];
end
