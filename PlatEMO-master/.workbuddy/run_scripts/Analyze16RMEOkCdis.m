function Analyze16RMEOkCdis()
%Analyze16RMEOkCdis Integrity check plus the full 16-problem analysis.
%   Prints only; nothing is written into the data folders.

    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    isDTLZ = cellfun(@(p)strncmp(p,'DTLZ',4),probs);
    runIds = 1:18;
    alg = 'RMEO_k_CDIS';
    objectiveCounts = [10 20];

    %% 1. integrity
    n = 0; bad = 0;
    for M = [10 20]
        if M == 10, folder = fullfile(root,'10目标','n30',alg);
        else, folder = fullfile(root,'20目标',alg); end
        for i = 1:numel(probs)
            files = dir(fullfile(folder,sprintf('%s_%s_M%d_D*_*.mat',alg,probs{i},M)));
            for k = 1:numel(files)
                S = load(fullfile(folder,files(k).name),'result','metric','metadata');
                n = n + 1; msg = '';
                if ~isfield(S,'metadata'), msg = 'no metadata';
                elseif S.metadata.actualFE ~= 300, msg = 'FE';
                elseif S.metadata.referenceSolutions ~= min(100,max(6,ceil(1.5*M))), msg = 'k';
                elseif S.metadata.M ~= M, msg = 'M';
                elseif isempty(S.result) || S.result{end,1} ~= 300, msg = 'snapshot';
                elseif ~isfinite(S.metric.IGD(end)), msg = 'IGD';
                end
                if ~isempty(msg)
                    bad = bad + 1;
                    fprintf('ANOMALY %s : %s\n',files(k).name,msg);
                end
            end
        end
    end
    fprintf('===== integrity: %d files scanned, %d anomalies =====\n\n',n,bad);

    %% 2. own means
    O = cell(1,2);
    for m = 1:2
        O{m} = getArm(root,objectiveCounts(m),alg,probs,runIds);
    end
    fprintf('-- own mean IGD (n=18 per problem) --\n');
    fprintf('%-6s %12s %12s\n','Problem','M=10','M=20');
    for i = 1:numel(probs)
        f = matlab.lang.makeValidName(probs{i});
        fprintf('%-6s %12.5g %12.5g\n',probs{i},mean(O{1}.(f)),mean(O{2}.(f)));
    end

    %% 3. delta matrix per arm
    for m = 1:2
        M = objectiveCounts(m);
        arms = {'REMO','REMO_k15','REMO_k','REMO_UniformMixCandidate', ...
                'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
        D = nan(numel(probs),numel(arms));
        S = nan(numel(probs),numel(arms));
        for a = 1:numel(arms)
            B = getArm(root,M,arms{a},probs,runIds);
            raw = nan(numel(probs),1); d = nan(numel(probs),1);
            for i = 1:numel(probs)
                f = matlab.lang.makeValidName(probs{i});
                x = O{m}.(f); y = B.(f);
                if numel(y) < 3, continue; end
                d(i) = 100*(mean(y)-mean(x))/mean(y);
                raw(i) = ranksum(x,y);
            end
            h = holmCorrect(raw);
            D(:,a) = d; S(:,a) = h;
        end
        fprintf('\n===== M=%d : delta%% vs each arm (positive = ours better; +/- = Holm<0.05) =====\n',M);
        fprintf('%-6s','Problem');
        for a = 1:numel(arms), fprintf(' %11s',shortName(arms{a})); end
        fprintf('\n');
        for i = 1:numel(probs)
            fprintf('%-6s',probs{i});
            for a = 1:numel(arms)
                mk = '  ';
                if ~isnan(S(i,a)) && S(i,a)<0.05
                    if D(i,a)>0, mk = '+ '; else, mk = '- '; end
                end
                fprintf(' %+9.2f%%%s',D(i,a),mk);
            end
            fprintf('\n');
        end
        fprintf('%-6s','MEAN');
        for a = 1:numel(arms)
            fprintf(' %+9.2f%%  ',mean(D(~isnan(D(:,a)),a)));
        end
        fprintf('\n');
        for a = 1:numel(arms)
            sg = ~isnan(S(:,a)) & S(:,a)<0.05;
            fprintf('  %-46s sig+ %d  sig- %d  ns %d',arms{a}, ...
                sum(sg & D(:,a)>0),sum(sg & D(:,a)<0),sum(~sg));
            if any(sg & D(:,a)>0)
                fprintf('   | better: %s',strjoin(probs(sg & D(:,a)>0),','));
            end
            if any(sg & D(:,a)<0)
                fprintf('   | worse: %s',strjoin(probs(sg & D(:,a)<0),','));
            end
            fprintf('\n');
        end
    end

    %% 4. two-by-two at both M
    fprintf('\n===== two-by-two module design (16 problems) =====\n');
    corners = { {'REMO_k15','REMO_new2_k15','RMEO_k_CDIS', ...
        'REMO_UniformMix_Pruned_Weighted_Lambdat030'}, ...
        {'REMO_k','REMO_new2_k','RMEO_k_CDIS', ...
        'REMO_UniformMix_Pruned_Weighted_Lambdat030'} };
    labels = {'PAQC|noCand','PAQC|withCand','Cand|noPAQC','Cand|withPAQC'};
    for m = 1:2
        M = objectiveCounts(m);
        A = cell(1,4);
        for j = 1:4, A{j} = getArm(root,M,corners{m}{j},probs,runIds); end
        MM = nan(numel(probs),4);
        for i = 1:numel(probs)
            f = matlab.lang.makeValidName(probs{i});
            for j = 1:4
                v = A{j}.(f);
                if ~isempty(v), MM(i,j) = mean(v); end
            end
        end
        E = nan(numel(probs),4); P = nan(numel(probs),4);
        pr = [1 2; 3 4; 1 3; 2 4];
        E(:,1) = 100*(MM(:,1)-MM(:,2))./MM(:,1);
        E(:,2) = 100*(MM(:,3)-MM(:,4))./MM(:,3);
        E(:,3) = 100*(MM(:,1)-MM(:,3))./MM(:,1);
        E(:,4) = 100*(MM(:,2)-MM(:,4))./MM(:,2);
        for e = 1:4
            for i = 1:numel(probs)
                f = matlab.lang.makeValidName(probs{i});
                x = A{pr(e,1)}.(f); y = A{pr(e,2)}.(f);
                if numel(x)>=3 && numel(y)>=3, P(i,e) = ranksum(x,y); end
            end
        end
        H = nan(numel(probs),4);
        for e = 1:4, H(:,e) = holmCorrect(P(:,e)); end
        fprintf('\n-- M=%d  corners: %s / %s / ours / F --\n',M, ...
            corners{m}{1},corners{m}{2});
        fprintf('%-16s %9s %5s %5s %11s %11s\n','effect','mean%','sig+','sig-', ...
            'DTLZmean%','WFGmean%');
        for e = 1:4
            sg = ~isnan(H(:,e)) & H(:,e)<0.05;
            fprintf('%-16s %+9.2f %5d %5d %11.2f %11.2f',labels{e}, ...
                mean(E(~isnan(E(:,e)),e)),sum(sg & E(:,e)>0),sum(sg & E(:,e)<0), ...
                mean(E(isDTLZ(:) & ~isnan(E(:,e)),e)), ...
                mean(E(~isDTLZ(:) & ~isnan(E(:,e)),e)));
            if any(sg & E(:,e)>0)
                fprintf('  | +: %s',strjoin(probs(sg & E(:,e)>0),','));
            end
            if any(sg & E(:,e)<0)
                fprintf('  | -: %s',strjoin(probs(sg & E(:,e)<0),','));
            end
            fprintf('\n');
        end
    end
end

function s = shortName(a)
%shortName Compact column header for an arm name.
    switch a
        case 'REMO', s = 'REMO(k6)';
        case 'REMO_k15', s = 'REMO_k15';
        case 'REMO_k', s = 'REMO_k30';
        case 'REMO_UniformMixCandidate', s = 'UniMixCand';
        otherwise, s = 'F(L030)';
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
