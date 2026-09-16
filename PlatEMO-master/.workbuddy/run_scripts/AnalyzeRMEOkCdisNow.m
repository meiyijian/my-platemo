function AnalyzeRMEOkCdisNow()
%AnalyzeRMEOkCdisNow Compare RMEO_k_CDIS with reference arms on identical run IDs.
%   Every arm is restricted to the requested run IDs so that all arms enter the
%   test with the same number of runs. Nothing is written except stdout.

    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    problems = {'DTLZ1','DTLZ2','DTLZ5','DTLZ7','WFG1','WFG3','WFG6','WFG8'};
    ours = 'RMEO_k_CDIS';
    arms = {'REMO','REMO_k15','REMO_k','REMO_UniformMixCandidate', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030', ...
            'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'};
    runIds = 1:18;

    fprintf('===== RMEO_k_CDIS, M=10, run IDs %d..%d (%d runs per problem) =====\n', ...
        runIds(1),runIds(end),numel(runIds));
    fprintf('All arms are restricted to the same run ID set.\n');
    O = collect(root,'10目标',ours,problems,10,runIds);
    nOwn = cellfun(@(p)numel(O.(matlab.lang.makeValidName(p))),problems);
    assert(all(nOwn == numel(runIds)),'Own arm is not complete for these run IDs.');
    fprintf('\n-- own IGD --\n');
    for i = 1:numel(problems)
        v = O.(matlab.lang.makeValidName(problems{i}));
        fprintf('%-6s n=%2d mean=%.6g sd=%.4g\n',problems{i},numel(v),mean(v),std(v));
    end

    for a = 1:numel(arms)
        B = collect(root,'10目标',arms{a},problems,10,runIds);
        compare(problems,O,B,arms{a},runIds);
    end

    fprintf('\n===== M=20 (still running) =====\n');
    O20 = collect(root,'20目标',ours,{'DTLZ1'},20,runIds);
    fprintf('own DTLZ1 M20: n=%d mean=%.6g sd=%.4g\n',numel(O20.DTLZ1), ...
        mean(O20.DTLZ1),std(O20.DTLZ1));
    for a = [1 2 4 5]
        B20 = collect(root,'20目标',arms{a},{'DTLZ1'},20,runIds);
        if isempty(B20.DTLZ1), continue; end
        fprintf('%-46s n=%2d mean=%.6g  delta=%+7.2f%%\n',arms{a}, ...
            numel(B20.DTLZ1),mean(B20.DTLZ1), ...
            100*(mean(B20.DTLZ1)-mean(O20.DTLZ1))/mean(O20.DTLZ1));
    end
end

function D = collect(root,tag,alg,problems,M,runIds)
%collect Read the final-snapshot IGD of the requested run IDs per problem.
    D = struct();
    folder = fullfile(root,tag);
    if strcmp(tag,'10目标'), folder = fullfile(folder,'n30'); end
    folder = fullfile(folder,alg);
    for i = 1:numel(problems)
        p = problems{i};
        field = matlab.lang.makeValidName(p);
        D.(field) = [];
        if ~isfolder(folder), continue; end
        files = dir(fullfile(folder,sprintf('%s_%s_M%d_D*_*.mat',alg,p,M)));
        v = zeros(numel(files),1);
        keep = false(numel(files),1);
        for k = 1:numel(files)
            t = regexp(files(k).name,'_(\d+)\.mat$','tokens','once');
            if isempty(t), continue; end
            if ~ismember(str2double(t{1}),runIds), continue; end
            S = load(fullfile(folder,files(k).name),'metric');
            if ~isfield(S,'metric') || ~isfield(S.metric,'IGD') || ...
                    isempty(S.metric.IGD) || ~isfinite(S.metric.IGD(end))
                continue;
            end
            v(k) = S.metric.IGD(end);
            keep(k) = true;
        end
        D.(field) = sort(v(keep));
    end
end

function compare(problems,O,B,armName,runIds)
%compare Per-problem non-paired rank-sum plus Holm over the eight problems.
    fprintf('\n-- vs %s --\n',armName);
    m = numel(problems);
    raw = nan(m,1); delta = nan(m,1); nBase = zeros(m,1);
    for i = 1:numel(problems)
        f = matlab.lang.makeValidName(problems{i});
        x = O.(f); y = B.(f);
        nBase(i) = numel(y);
        if numel(y) < 3, continue; end
        delta(i) = 100*(mean(y)-mean(x))/mean(y);
        raw(i) = ranksum(x,y);
    end
    fprintf('baseline n per problem: %s\n',mat2str(nBase'));
    if any(nBase < numel(runIds))
        fprintf('WARNING: baseline is missing some of run IDs %d..%d\n', ...
            runIds(1),runIds(end));
    end
    holm = holmCorrect(raw);
    fprintf('%-6s %10s %10s %10s %9s %9s %11s\n', ...
        'Problem','own-mean','base-mean','delta%','p','p_holm','decision');
    for i = 1:numel(problems)
        if isnan(delta(i)), continue; end
        if isnan(raw(i))
            pTxt = '   n/a  '; hTxt = '   n/a  '; dec = 'no-test';
        else
            pTxt = sprintf('%9.2g',raw(i));
            hTxt = sprintf('%9.2g',holm(i));
            if holm(i) < 0.05 && delta(i) > 0, dec = 'own-better';
            elseif holm(i) < 0.05 && delta(i) < 0, dec = 'own-worse';
            else, dec = 'ns'; end
        end
        fprintf('%-6s %10.5g %10.5g %+9.2f%% %s %s %11s\n', ...
            problems{i},mean(O.(matlab.lang.makeValidName(problems{i}))), ...
            mean(B.(matlab.lang.makeValidName(problems{i}))),delta(i), ...
            pTxt,hTxt,dec);
    end
    sig = ~isnan(holm) & holm < 0.05;
    fprintf('mean delta = %+.2f%%; significant better %d, worse %d, not-significant %d\n', ...
        mean(delta(~isnan(delta))),sum(sig & delta(:) > 0), ...
        sum(sig & delta(:) < 0),sum(~sig));
    if any(sig & delta(:) > 0)
        fprintf('  better on: %s\n',strjoin(problems(sig & delta(:) > 0),', '));
    end
    if any(sig & delta(:) < 0)
        fprintf('  worse  on: %s\n',strjoin(problems(sig & delta(:) < 0),', '));
    end
end

function h = holmCorrect(p)
%holmCorrect Holm step-down adjustment with an explicit running maximum.
    m = numel(p);
    h = p;
    order = p;
    order(isnan(order)) = inf;
    [~,idx] = sort(order);
    prev = 0;
    for k = 1:m
        i = idx(k);
        if isnan(p(i)), h(i) = NaN; continue; end
        val = (m-k+1)*p(i);
        if val > 1, val = 1; end
        if val < prev, val = prev; end
        prev = val;
        h(i) = val;
    end
end
