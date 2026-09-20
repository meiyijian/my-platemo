function CompareFE500Significance()
%CompareFE500Significance Rank sum of the FE500 algorithms against one anchor.
%   Anchor is REMO_new2_AdaMaO_SDEOnly_UniformMix; HES_EA and PIEA are compared
%   to it on the last-snapshot IGD over runs 1-18, with the rule the paper
%   tables use: MATLAB ranksum, p < 0.05, direction from the means
%   (IGD is min-is-better). '+' = the baseline is significantly better than the
%   anchor, '-' = significantly worse, '=' = no significant difference; the
%   anchor column carries no symbol.
    root   = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\FE500';
    anchor = 'REMO_new2_AdaMaO_SDEOnly_UniformMix';
    others = {'HES_EA','PIEA'};
    runs   = 1:18;
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    nO = numel(others);
    cnt = zeros(nO,3);           % + - =
    fprintf('anchor = %s   (runs 1-18, IGD+ is min-is-better)\n\n',anchor);
    hdr = sprintf('%-7s %16s', 'Problem', 'ANCHOR');
    for k = 1:nO, hdr = [hdr sprintf(' %18s', others{k})]; end %#ok<AGROW>
    fprintf('%s\n',hdr);
    fprintf('%s\n',repmat('-',1,numel(hdr)));
    for p = 1:numel(problems)
        prob = problems{p};
        va = readLast(root, anchor, prob, runs);
        assert(numel(va) == numel(runs), '%s %s has %d runs',anchor,prob,numel(va));
        line = sprintf('%-7s %16.6g', prob, mean(va));
        for k = 1:nO
            vb = readLast(root, others{k}, prob, runs);
            assert(numel(vb) == numel(runs), '%s %s has %d runs',others{k},prob,numel(vb));
            pv = ranksum(vb, va);
            if pv >= 0.05 || mean(vb) == mean(va)
                s = '=';
            elseif mean(vb) < mean(va)
                s = '+';
            else
                s = '-';
            end
            cnt(k, find('+-=' == s)) = cnt(k, find('+-=' == s)) + 1;
            line = [line sprintf(' %13.6g %s(p%.4f)', mean(vb), s, pv)]; %#ok<AGROW>
        end
        fprintf('%s\n',line);
    end
    fprintf('\n');
    for k = 1:nO
        fprintf('%-9s vs anchor : + %d / - %d / = %d   -> "%d/%d/%d"\n', ...
            others{k}, cnt(k,1), cnt(k,2), cnt(k,3), cnt(k,1), cnt(k,2), cnt(k,3));
    end
end

function v = readLast(root, alg, prob, runs)
%readLast Last-snapshot IGD of every stored run of one algorithm and problem.
    d = dir(fullfile(root, alg, sprintf('%s_%s_M10_D*_*.mat', alg, prob)));
    v = nan(numel(d),1); rid = nan(numel(d),1);
    for i = 1:numel(d)
        tok = regexp(d(i).name, '_M10_D(\d+)_(\d+)\.mat$', 'tokens', 'once');
        rid(i) = str2double(tok{2});
        S = load(fullfile(root, alg, d(i).name), 'metric');
        igd = S.metric.IGD(:);
        v(i) = igd(end);
    end
    v = v(ismember(rid, runs));
end
