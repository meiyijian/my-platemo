function ModuleEffectM10()
%ModuleEffectM10 Test whether the candidate-selection module adds a positive
%   contribution at M=10. Each pair is module-off -> module-on, with both arms
%   restricted to the same run IDs, so no comparison is biased by sample size.
%   Prints only; writes no output file.

    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    problems = {'DTLZ1','DTLZ2','DTLZ5','DTLZ7','WFG1','WFG3','WFG6','WFG8'};
    isDTLZ = cellfun(@(p)strncmp(p,'DTLZ',4),problems);
    runIds = 1:18;
    pairs = {
        'P1  k=6  : REMO -> +candidate(old)   ','REMO','REMO_UniformMixCandidate'
        'P2  k=1.5: k15  -> +CDIS(new)        ','REMO_k15','RMEO_k_CDIS'
        'P3  k=1.5: k15  -> +CDIS+PAQC (F)    ','REMO_k15','REMO_UniformMix_Pruned_Weighted_Lambdat030'
        'P4  k=6  : REMO -> +HPC (not cand.)  ','REMO','REMO_new2'
        'P5  k=1.5: k15  -> full architecture ','REMO_k15','REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'
        'P6  k=1.5: k15  -> +HPC               ','REMO_k15','REMO_new2_k15'
        };
    cache = containers.Map();
    fprintf('All arms restricted to run IDs %d..%d (n=18 per problem).\n', ...
        runIds(1),runIds(end));
    fprintf('delta%% = 100*(mean(off)-mean(on))/mean(off); POSITIVE = the module helps.\n');
    for q = 1:size(pairs,1)
        tag = pairs{q,1}; offName = pairs{q,2}; onName = pairs{q,3};
        A = getArm(cache,root,offName,problems,runIds);
        B = getArm(cache,root,onName,problems,runIds);
        fprintf('\n================ %s\n',tag);
        fprintf('   off = %-46s on = %s\n',offName,onName);
        m = numel(problems);
        raw = nan(m,1); delta = nan(m,1); nOn = zeros(m,1);
        for i = 1:m
            f = matlab.lang.makeValidName(problems{i});
            x = A.(f); y = B.(f);
            nOn(i) = numel(y);
            if numel(x) < 3 || numel(y) < 3, continue; end
            delta(i) = 100*(mean(x)-mean(y))/mean(x);
            raw(i) = ranksum(x,y);
        end
        holm = holmCorrect(raw);
        fprintf('   %-6s %12s %12s %10s %9s %9s %s\n','Problem','off-mean','on-mean','delta%','p','p_holm','decision');
        for i = 1:m
            if isnan(delta(i))
                fprintf('   %-6s %12s %12s %10s\n',problems{i},'missing','missing','-');
                continue;
            end
            if isnan(raw(i))
                dec = 'no-test';
            elseif holm(i) < 0.05 && delta(i) > 0
                dec = 'MODULE HELPS';
            elseif holm(i) < 0.05 && delta(i) < 0
                dec = 'module hurts';
            else
                dec = 'ns';
            end
            fprintf('   %-6s %12.5g %12.5g %+9.2f%% %9.2g %9.2g %s\n', ...
                problems{i},mean(A.(matlab.lang.makeValidName(problems{i}))), ...
                mean(B.(matlab.lang.makeValidName(problems{i}))),delta(i), ...
                raw(i),holm(i),dec);
        end
        sig = ~isnan(holm) & holm < 0.05;
        fprintf('   n(into test) = %s\n',mat2str(nOn'));
        fprintf('   ALL  : helps %d, hurts %d, ns %d, mean delta %+.2f%%\n', ...
            sum(sig & delta(:)>0),sum(sig & delta(:)<0),sum(~sig), ...
            mean(delta(~isnan(delta))));
        fprintf('   DTLZ : helps %d, hurts %d, ns %d, mean delta %+.2f%%\n', ...
            sum(sig & delta(:)>0 & isDTLZ(:)),sum(sig & delta(:)<0 & isDTLZ(:)), ...
            sum(~sig & isDTLZ(:)),mean(delta(~isnan(delta) & isDTLZ(:))));
        fprintf('   WFG  : helps %d, hurts %d, ns %d, mean delta %+.2f%%\n', ...
            sum(sig & delta(:)>0 & ~isDTLZ(:)),sum(sig & delta(:)<0 & ~isDTLZ(:)), ...
            sum(~sig & ~isDTLZ(:)),mean(delta(~isnan(delta) & ~isDTLZ(:))));
        fprintf('   problems with delta>0 (descriptive, no test): %d/8  [%s]\n', ...
            sum(delta(~isnan(delta))>0), ...
            strjoin(problems(delta(:)>0 & ~isnan(delta)),', '));
    end
end

function A = getArm(cache,root,name,problems,runIds)
%getArm Read (and cache) the final-snapshot IGD per problem for one arm.
    if isKey(cache,name), A = cache(name); return; end
    folder = fullfile(root,'10目标','n30',name);
    A = struct();
    for i = 1:numel(problems)
        p = problems{i};
        field = matlab.lang.makeValidName(p);
        A.(field) = [];
        if ~isfolder(folder), continue; end
        files = dir(fullfile(folder,sprintf('%s_%s_M10_D*_*.mat',name,p)));
        v = zeros(numel(files),1);
        keep = false(numel(files),1);
        for k = 1:numel(files)
            t = regexp(files(k).name,'_(\d+)\.mat$','tokens','once');
            if isempty(t) || ~ismember(str2double(t{1}),runIds), continue; end
            S = load(fullfile(folder,files(k).name),'metric');
            if ~isfield(S,'metric') || ~isfield(S.metric,'IGD') || ...
                    isempty(S.metric.IGD) || ~isfinite(S.metric.IGD(end))
                continue;
            end
            v(k) = S.metric.IGD(end);
            keep(k) = true;
        end
        A.(field) = sort(v(keep));
    end
    cache(name) = A;
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
