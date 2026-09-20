function HeadToHeadSSDE()
%HeadToHeadSSDE  Should SSDE replace MCEAD as a baseline?
%
%   Compares SSDE head to head against each of the paper's six baselines with
%   the SAME test the comparison tables use (MATLAB ranksum, p<0.05), at
%   M=10/15/20, runs 1..20, metric IGDp(end).  Also prints a strength profile:
%   for every problem the eight algorithms are ranked by their mean IGDp, and
%   each algorithm's average rank and number of "best on" problems are shown.
%
%   Read-only: loads the archived .mat files, writes nothing.

    testRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    PROB = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
            'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    ALGS = {'REMO','REMO'; 'PIEA','PIEA'; 'CSEA','CSEA'; ...
            'PCSAEA_N100','PCSAEA_N100'; 'KRVEA_100','KRVEA_100'; 'MCEAD','MCEAD'; ...
            'SSDE','SSDE'; 'PACDIS','REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist'};
    runs = 1:20;

    for M = [10 15 20]
        if M == 10, sub = fullfile('10目标','n30'); else, sub = sprintf('%d目标',M); end
        V = cell(size(ALGS,1),numel(PROB));
        for a = 1:size(ALGS,1)
            d = fullfile(testRoot,sub,ALGS{a,2});
            for p = 1:numel(PROB)
                v = nan(1,numel(runs));
                for ri = 1:numel(runs)
                    f = '';
                    for dd = [30 31]
                        c = fullfile(d,sprintf('%s_%s_M%d_D%d_%d.mat',ALGS{a,2},PROB{p},M,dd,runs(ri)));
                        if isfile(c), f = c; break; end
                    end
                    if isempty(f)
                        error('missing %s %s run%d M=%d',ALGS{a,1},PROB{p},runs(ri),M);
                    end
                    S = load(f,'metric');
                    vv = S.metric.IGDp(:);
                    v(ri) = vv(end);
                end
                V{a,p} = v;
            end
        end

        iSSDE = find(strcmp(ALGS(:,1),'SSDE'));
        fprintf('\n%s\n=== M=%d : SSDE head to head (ranksum p<0.05, runs 1-20) ===\n', ...
            repmat('=',1,78),M);
        fprintf('  %-13s %-12s %s\n','baseline','SSDE + / - / =','SSDE better on');
        for a = 1:size(ALGS,1)
            if a == iSSDE || strcmp(ALGS{a,1},'PACDIS'), continue; end
            w=0; l=0; t=0; better={};
            for p = 1:numel(PROB)
                pv = ranksum(V{iSSDE,p},V{a,p});
                if pv < 0.05
                    if mean(V{iSSDE,p}) < mean(V{a,p}), w=w+1; better{end+1}=PROB{p}; %#ok<AGROW>
                    else, l=l+1; end
                else, t=t+1; end
            end
            fprintf('  %-13s %-12s %s\n',ALGS{a,1}, ...
                sprintf('%d / %d / %d',w,l,t), strjoin(better,', '));
        end

        % strength profile: rank the 8 algorithms per problem by mean IGDp
        fprintf('\n  强度画像（每题按均值排名，1=最好）\n');
        R = nan(size(ALGS,1),numel(PROB));
        for p = 1:numel(PROB)
            m = cellfun(@(v)mean(v),V(:,p));
            [~,ord] = sort(m);
            R(ord,p) = 1:size(ALGS,1);
        end
        for a = 1:size(ALGS,1)
            fprintf('    %-13s 平均排名 %.2f   拿过第1名的题数 %d\n', ...
                ALGS{a,1},mean(R(a,:)),sum(R(a,:)==1));
        end

        % MCEAD vs SSDE per problem
        iM = find(strcmp(ALGS(:,1),'MCEAD'));
        fprintf('\n  MCEAD vs SSDE 逐题（均值 IGDp）\n');
        for p = 1:numel(PROB)
            a = V{iSSDE,p}; b = V{iM,p};
            pv = ranksum(a,b);
            if pv < 0.05 && mean(a) < mean(b),   tag = 'SSDE 更好';
            elseif pv < 0.05,                    tag = 'MCEAD 更好';
            else,                                tag = '无差异'; end
            fprintf('    %-6s SSDE %11.5f  MCEAD %11.5f  p=%.3g  %s\n', ...
                PROB{p},mean(a),mean(b),pv,tag);
        end
    end
    fprintf('\nH2H DONE\n');
end
