function TwoByTwoM10()
%TwoByTwoM10 Two-module two-by-two design at M=10 with k=15 in every arm.
%   Rows: PAQC off / on.  Columns: candidate-selection module off / on.
%     no PAQC, no cand : REMO_k15
%     PAQC   , no cand : REMO_new2_k15     (HybridPBI_Classification)
%     no PAQC, cand    : RMEO_k_CDIS       (CDIS)
%     PAQC   , cand    : REMO_UniformMix_Pruned_Weighted_Lambdat030 (PAQC+CDIS)
%   All arms restricted to run IDs 1..18. Prints only.

    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    problems = {'DTLZ1','DTLZ2','DTLZ5','DTLZ7','WFG1','WFG3','WFG6','WFG8'};
    isDTLZ = cellfun(@(p)strncmp(p,'DTLZ',4),problems);
    runIds = 1:18;
    names = {'REMO_k15','REMO_new2_k15','RMEO_k_CDIS', ...
             'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    A = cell(1,4);
    for i = 1:4
        A{i} = getArm(root,names{i},problems,runIds);
    end
    m = numel(problems);
    M4 = nan(m,4);
    for i = 1:m
        f = matlab.lang.makeValidName(problems{i});
        for j = 1:4
            v = A{j}.(f);
            if ~isempty(v), M4(i,j) = mean(v); end
        end
    end
    % Effect directions: positive always means "the module helps".
    E = nan(m,4);
    E(:,1) = 100*(M4(:,1)-M4(:,2))./M4(:,1);   % PAQC effect, no cand
    E(:,2) = 100*(M4(:,3)-M4(:,4))./M4(:,3);   % PAQC effect, with cand
    E(:,3) = 100*(M4(:,1)-M4(:,3))./M4(:,1);   % cand effect, no PAQC
    E(:,4) = 100*(M4(:,2)-M4(:,4))./M4(:,2);   % cand effect, with PAQC
    P = nan(m,4);
    pairs = [1 2; 3 4; 1 3; 2 4];
    for e = 1:4
        for i = 1:m
            f = matlab.lang.makeValidName(problems{i});
            x = A{pairs(e,1)}.(f); y = A{pairs(e,2)}.(f);
            if numel(x) >= 3 && numel(y) >= 3, P(i,e) = ranksum(x,y); end
        end
    end
    H = nan(m,4);
    for e = 1:4, H(:,e) = holmCorrect(P(:,e)); end
    sig = H < 0.05;

    fprintf('M=10, k=15 in all four arms, run IDs %d..%d.\n',runIds(1),runIds(end));
    fprintf('Cell means:\n');
    fprintf('%-6s %12s %12s %12s %12s\n','Problem','noPAQC/no','+PAQC/no', ...
        'noPAQC/cand','+PAQC/cand');
    for i = 1:m
        fprintf('%-6s %12.5g %12.5g %12.5g %12.5g\n',problems{i},M4(i,1),M4(i,2),M4(i,3),M4(i,4));
    end

    labels = {'PAQC|noCand ','PAQC|withCand','Cand|noPAQC ','Cand|withPAQC'};
    fprintf('\nEffects (%% , positive = the module helps), * = Holm<0.05\n');
    fprintf('%-6s %16s %16s %16s %16s\n','Problem',labels{:});
    for i = 1:m
        fprintf('%-6s',problems{i});
        for e = 1:4
            mark = ' ';
            if sig(i,e), if E(i,e) > 0, mark = '+'; else, mark = '-'; end, end
            fprintf(' %+14.2f%%%s',E(i,e),mark);
        end
        fprintf('\n');
    end
    fprintf('\nSummary (mean effect, significant counts, family split)\n');
    fprintf('%-16s %10s %8s %10s %10s %10s\n','effect','mean%','sig+','sig-','DTLZ mean%','WFG mean%');
    for e = 1:4
        fprintf('%-16s %+10.2f %8d %10d %10.2f %10.2f\n',labels{e}, ...
            mean(E(~isnan(E(:,e)),e)),sum(sig(:,e)&E(:,e)>0),sum(sig(:,e)&E(:,e)<0), ...
            mean(E(isDTLZ(:)&~isnan(E(:,e)),e)),mean(E(~isDTLZ(:)&~isnan(E(:,e)),e)));
    end
    fprintf('\nper-arm n: ');
    for j = 1:4
        fprintf('%s=%d ',names{j},numel(A{j}.(matlab.lang.makeValidName(problems{1}))));
    end
    fprintf('\n');
end

function A = getArm(root,name,problems,runIds)
%getArm Read the final-snapshot IGD per problem for one arm.
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
