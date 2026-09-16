function FinalizeRMEOkCdis()
%FinalizeRMEOkCdis Integrity check of the finished batch plus the M=20 analysis.
%   Prints only; nothing is written into the data folders.

    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    probs = {'DTLZ1','DTLZ2','DTLZ5','DTLZ7','WFG1','WFG3','WFG6','WFG8'};
    runIds = 1:18;

    %% ---------- 1. integrity ----------
    fprintf('===== integrity check =====\n');
    bad = 0; n = 0;
    for M = [10 20]
        if M == 10, folder = fullfile(root,'10目标','n30','RMEO_k_CDIS');
        else, folder = fullfile(root,'20目标','RMEO_k_CDIS'); end
        for i = 1:numel(probs)
            p = probs{i};
            files = dir(fullfile(folder,sprintf('RMEO_k_CDIS_%s_M%d_D*_*.mat',p,M)));
            for k = 1:numel(files)
                f = fullfile(folder,files(k).name);
                S = load(f,'result','metric','metadata');
                n = n + 1;
                msg = '';
                if ~isfield(S,'metadata'), msg = 'no metadata';
                elseif ~strcmp(S.metadata.algorithm,'RMEO_k_CDIS'), msg = 'algorithm name';
                elseif S.metadata.M ~= M, msg = 'M mismatch';
                elseif S.metadata.actualFE ~= 300, msg = ['FE=' num2str(S.metadata.actualFE)];
                elseif S.metadata.referenceSolutions ~= min(100,max(6,ceil(1.5*M)))
                    msg = ['k=' num2str(S.metadata.referenceSolutions)];
                elseif isempty(S.result) || S.result{end,1} ~= 300, msg = 'last snapshot FE';
                elseif ~isfield(S.metric,'IGD') || ~isfinite(S.metric.IGD(end))
                    msg = 'IGD not finite';
                end
                if ~isempty(msg)
                    bad = bad + 1;
                    fprintf('  ANOMALY %s : %s\n',files(k).name,msg);
                end
            end
        end
    end
    fprintf('scanned %d files, anomalies %d\n',n,bad);

    %% ---------- 2. M=20 comparison ----------
    fprintf('\n===== M=20, all arms restricted to run IDs %d..%d =====\n',runIds(1),runIds(end));
    O = getArm(root,20,'RMEO_k_CDIS',probs,runIds);
    fprintf('-- own IGD --\n');
    for i = 1:numel(probs)
        v = O.(matlab.lang.makeValidName(probs{i}));
        fprintf('%-6s n=%2d mean=%.6g sd=%.4g\n',probs{i},numel(v),mean(v),std(v));
    end
    refs = {'REMO','REMO_k','REMO_k15','REMO_UniformMixCandidate', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    for a = 1:numel(refs)
        B = getArm(root,20,refs{a},probs,runIds);
        compare(probs,O,B,refs{a});
    end

    %% ---------- 3. M=20 two-by-two ----------
    fprintf('\n===== M=20 two-by-two (k=30 corner arms) =====\n');
    names = {'REMO_k','REMO_new2_k','RMEO_k_CDIS', ...
             'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    A = cell(1,4);
    for i = 1:4, A{i} = getArm(root,20,names{i},probs,runIds); end
    m = numel(probs);
    M4 = nan(m,4);
    for i = 1:m
        f = matlab.lang.makeValidName(probs{i});
        for j = 1:4
            v = A{j}.(f);
            if ~isempty(v), M4(i,j) = mean(v); end
        end
    end
    fprintf('%-6s %12s %12s %12s %12s\n','Problem','noPAQC/no','+PAQC/no','noPAQC/cand','+PAQC/cand');
    for i = 1:m
        fprintf('%-6s %12.5g %12.5g %12.5g %12.5g\n',probs{i},M4(i,1),M4(i,2),M4(i,3),M4(i,4));
    end
    E = nan(m,4); P = nan(m,4);
    pairs = [1 2; 3 4; 1 3; 2 4];
    E(:,1) = 100*(M4(:,1)-M4(:,2))./M4(:,1);
    E(:,2) = 100*(M4(:,3)-M4(:,4))./M4(:,3);
    E(:,3) = 100*(M4(:,1)-M4(:,3))./M4(:,1);
    E(:,4) = 100*(M4(:,2)-M4(:,4))./M4(:,2);
    for e = 1:4
        for i = 1:m
            f = matlab.lang.makeValidName(probs{i});
            x = A{pairs(e,1)}.(f); y = A{pairs(e,2)}.(f);
            if numel(x) >= 3 && numel(y) >= 3, P(i,e) = ranksum(x,y); end
        end
    end
    H = nan(m,4);
    for e = 1:4, H(:,e) = holmCorrect(P(:,e)); end
    sig = H < 0.05;
    labels = {'PAQC|noCand','PAQC|withCand','Cand|noPAQC','Cand|withPAQC'};
    fprintf('\nEffects (%%, positive = module helps), * = Holm<0.05\n');
    fprintf('%-6s %15s %15s %15s %15s\n','Problem',labels{:});
    for i = 1:m
        fprintf('%-6s',probs{i});
        for e = 1:4
            mk = ' ';
            if sig(i,e), if E(i,e) > 0, mk = '+'; else, mk = '-'; end, end
            fprintf(' %13.2f%%%s',E(i,e),mk);
        end
        fprintf('\n');
    end
    fprintf('\n%-16s %10s %6s %6s\n','effect','mean%','sig+','sig-');
    for e = 1:4
        fprintf('%-16s %+10.2f %6d %6d\n',labels{e},mean(E(~isnan(E(:,e)),e)), ...
            sum(sig(:,e)&E(:,e)>0),sum(sig(:,e)&E(:,e)<0));
    end
end

function A = getArm(root,M,name,probs,runIds)
%getArm Read the final-snapshot IGD per problem for one arm at one M.
    if M == 10, folder = fullfile(root,'10目标','n30',name);
    else, folder = fullfile(root,'20目标',name); end
    A = struct();
    for i = 1:numel(probs)
        p = probs{i};
        field = matlab.lang.makeValidName(p);
        A.(field) = [];
        if ~isfolder(folder), continue; end
        files = dir(fullfile(folder,sprintf('%s_%s_M%d_D*_*.mat',name,p,M)));
        v = zeros(numel(files),1); keep = false(numel(files),1);
        for k = 1:numel(files)
            t = regexp(files(k).name,'_(\d+)\.mat$','tokens','once');
            if isempty(t) || ~ismember(str2double(t{1}),runIds), continue; end
            S = load(fullfile(folder,files(k).name),'metric');
            if ~isfield(S,'metric') || ~isfield(S.metric,'IGD') || ...
                    isempty(S.metric.IGD) || ~isfinite(S.metric.IGD(end))
                continue;
            end
            v(k) = S.metric.IGD(end); keep(k) = true;
        end
        A.(field) = sort(v(keep));
    end
end

function compare(probs,O,B,armName)
%compare Per-problem rank-sum plus Holm over the eight problems.
    fprintf('\n-- vs %s --\n',armName);
    m = numel(probs); raw = nan(m,1); delta = nan(m,1); nBase = zeros(m,1);
    for i = 1:m
        f = matlab.lang.makeValidName(probs{i});
        x = O.(f); y = B.(f);
        nBase(i) = numel(y);
        if numel(y) < 3, continue; end
        delta(i) = 100*(mean(y)-mean(x))/mean(y);
        raw(i) = ranksum(x,y);
    end
    fprintf('   baseline n = %s\n',mat2str(nBase'));
    holm = holmCorrect(raw);
    fprintf('   %-6s %11s %11s %10s %9s %9s %s\n','Problem','own','base','delta%','p','p_holm','decision');
    for i = 1:m
        if isnan(delta(i)), continue; end
        if isnan(raw(i)), dec = 'no-test';
        elseif holm(i) < 0.05 && delta(i) > 0, dec = 'own-better';
        elseif holm(i) < 0.05 && delta(i) < 0, dec = 'own-worse';
        else, dec = 'ns'; end
        fprintf('   %-6s %11.5g %11.5g %+9.2f%% %9.2g %9.2g %s\n', ...
            probs{i},mean(O.(matlab.lang.makeValidName(probs{i}))), ...
            mean(B.(matlab.lang.makeValidName(probs{i}))),delta(i),raw(i),holm(i),dec);
    end
    sig = ~isnan(holm) & holm < 0.05;
    fprintf('   mean delta %+.2f%%; better %d, worse %d, ns %d\n', ...
        mean(delta(~isnan(delta))),sum(sig & delta(:)>0),sum(sig & delta(:)<0),sum(~sig));
end

function h = holmCorrect(p)
%holmCorrect Holm step-down adjustment with an explicit running maximum.
    m = numel(p); h = p; order = p; order(isnan(order)) = inf;
    [~,idx] = sort(order); prev = 0;
    for k = 1:m
        i = idx(k);
        if isnan(p(i)), h(i) = NaN; continue; end
        val = (m-k+1)*p(i);
        if val > 1, val = 1; end
        if val < prev, val = prev; end
        prev = val; h(i) = val;
    end
end
