function verify_FE500_M20(algKeys)
%VERIFY_FE500_M20 Integrity check of the FE500 20-objective sweep (no analysis).
%
%   verify_FE500_M20()                       -> every algorithm of the registry
%   verify_FE500_M20('PACDIS')               -> one algorithm
%   verify_FE500_M20({'REMO','PACDIS'})      -> a subset
%
%   Per algorithm it checks, for all 16 problems x runs 1..20:
%     * the file exists under <root>\<folder>\ with D in {30,31}
%     * payload = result + metric{runtime, IGD, IGDp}
%     * numel(IGD) == numel(IGDp) == numel(result(:,1)) <= 30
%     * every IGD / IGDp sample finite
%     * the final FE lies in [500, 500+FESLACK] (batch-evaluating algorithms
%       legitimately overshoot; FESLACK must match the runner)
%
%   It also prints the FIRST-snapshot FE, which is the algorithm's initial
%   design size. That number is the single most important caveat of this sweep:
%   the published PCSAEA / HES_EA / SAMOEA spend 11*D-1 = 329 of the 500 true
%   evaluations on the initial design and only ~171 on the search, while REMO /
%   CSEA / SSDE / PACDIS start at 100-109 and get ~400. Never compare their
%   final IGD without stating this.
%
%   A summary table is written next to this file as summary_FE500_M20_<KEY>.csv.

    if nargin < 1 || isempty(algKeys)
        reg = fe500_m20_registry();
        algKeys = {reg.key};
    elseif ischar(algKeys) || isstring(algKeys)
        algKeys = {char(algKeys)};
    end

    root    = 'D:\REMOandDREMO测试集\20目标\FE500';
    envRoot = getenv('FE500_M20_OUTPUT_ROOT');
    if ~isempty(envRoot), root = envRoot; end

    expectedFE = 500;
    feslack    = 100;      % MUST match run_FE500_M20.m
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    here = fileparts(mfilename('fullpath'));

    reg = fe500_m20_registry();
    for a = 1:numel(algKeys)
        key = char(algKeys{a});
        k = find(strcmpi({reg.key},key),1);
        assert(~isempty(k),'FE500_M20:UnknownAlgorithm','Unknown key %s',key);
        R = reg(k);
        D = fullfile(root,R.folder);

        fprintf('\n================ %s  (%s) ================\n',R.key,R.cls);
        fprintf('folder : %s\n',D);
        fprintf('note   : %s\n',R.note);
        if ~isfolder(D)
            fprintf('  !! output folder does not exist - algorithm not started\n');
            continue;
        end
        stray = dir(fullfile(D,'*.tmp.mat'));
        if ~isempty(stray)
            fprintf('  !! %d leftover *.tmp.mat (interrupted write)\n',numel(stray));
        end

        nOK = 0; nBad = 0; nP = 0; badList = {};
        feFirst = nan(numel(probs),1); feLast = nan(numel(probs),1);
        igdMean = nan(numel(probs),1); igdpMean = nan(numel(probs),1);
        wallMean = nan(numel(probs),1);
        for i = 1:numel(probs)
            line = ''; finals = []; finalsP = []; walls = []; ff = []; fl = [];
            for r = 1:20
                f = '';
                for dd = [30 31]
                    cand = fullfile(D,sprintf('%s_%s_M20_D%d_%d.mat',R.cls,probs{i},dd,r));
                    if isfile(cand), f = cand; break; end
                end
                if isempty(f)
                    line = [line 'x']; nBad = nBad+1;
                    badList{end+1} = sprintf('%s run %d MISSING',probs{i},r); %#ok<AGROW>
                    continue;
                end
                try
                    S = load(f);
                    ok = isfield(S,'result') && isfield(S,'metric') && ...
                         ~isempty(S.result) && isfield(S.metric,'IGD') && ...
                         isfield(S.metric,'runtime');
                    fe = cellfun(@(x)x,S.result(:,1));
                    ok = ok && numel(S.metric.IGD)==numel(fe) && ...
                         all(isfinite(S.metric.IGD)) && ...
                         fe(end)>=expectedFE && fe(end)<=expectedFE+feslack;
                    hasP = isfield(S.metric,'IGDp') && ...
                           numel(S.metric.IGDp)==numel(fe) && ...
                           all(isfinite(S.metric.IGDp));
                    if ~hasP
                        nP = nP + 1;
                        badList{end+1} = sprintf('%s run %d NO/BAD IGDp',probs{i},r); %#ok<AGROW>
                    end
                    if ok
                        nOK = nOK+1; line = [line '.'];
                        finals(end+1)  = S.metric.IGD(end);  %#ok<AGROW>
                        if hasP, finalsP(end+1) = S.metric.IGDp(end); end %#ok<AGROW>
                        walls(end+1)   = S.metric.runtime(end); %#ok<AGROW>
                        ff(end+1) = fe(1); fl(end+1) = fe(end); %#ok<AGROW>
                    else
                        nBad = nBad+1; line = [line 'X'];
                        badList{end+1} = sprintf('%s run %d BAD payload',probs{i},r); %#ok<AGROW>
                    end
                    clear S
                catch err
                    nBad = nBad+1; line = [line 'E'];
                    badList{end+1} = sprintf('%s run %d ERROR %s',probs{i},r,err.message); %#ok<AGROW>
                end
            end
            if ~isempty(finals),  igdMean(i)  = mean(finals);  end
            if ~isempty(finalsP), igdpMean(i) = mean(finalsP); end
            walls = walls(isfinite(walls) & walls < 3600);
            if ~isempty(walls), wallMean(i) = mean(walls); end
            if ~isempty(ff)
                feFirst(i) = mode(ff); feLast(i) = max(fl);
            end
            fprintf('  %-6s %-20s FE %s..%s  IGD %s | IGDp %s | wall %s\n', ...
                probs{i},line,str(feFirst(i)),str(feLast(i)), ...
                str(igdMean(i),'%.4f'),str(igdpMean(i),'%.4f'),str(wallMean(i),'%.0f'));
        end

        fprintf('  ==== OK=%d  BAD=%d  IGDp-missing=%d  TOTAL=%d\n',nOK,nBad,nP,nOK+nBad);
        for j = 1:numel(badList), fprintf('    !! %s\n',badList{j}); end
        if nBad==0 && nP==0 && nOK==16*20
            fprintf('  ==== ALL %d FILES VALID\n',nOK);
        end

        T = table(probs(:),feFirst,feLast,igdMean,igdpMean,wallMean, ...
            'VariableNames',{'Problem','FirstFE','LastFE','MeanFinalIGD', ...
                             'MeanFinalIGDp','MeanRuntime'});
        csv = fullfile(here,sprintf('summary_FE500_M20_%s.csv',R.key));
        writetable(T,csv);
        fprintf('  summary written: %s\n',csv);
    end
end

function s = str(v,fmt)
    if nargin < 2, fmt = '%.0f'; end
    if isnan(v), s = ' n/a'; else, s = sprintf(fmt,v); end
end
