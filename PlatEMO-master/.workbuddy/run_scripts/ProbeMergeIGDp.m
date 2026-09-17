function ProbeMergeIGDp()
%ProbeMergeIGDp Check how one IGD+ product maps onto the raw run files.
%   Read-only. Prints the metric fields of a raw file and the length of the
%   IGD+ trace stored for the same run, so the merge can be validated before
%   anything is written.

    rawRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    outBase = 'C:\Users\lsx\Desktop\AdaMao实验表';
    algs = {'REMO_UniformMix_Pruned_Weighted_Lambdat030','REMO','PIEA', ...
            'CSEA','PCSAEA_N100','KRVEA_100','MCEAD'};
    cases = {10,'DTLZ1','30'; 10,'WFG2','31'; 15,'WFG5','30'; 20,'WFG7','30'; 20,'WFG3','31'};

    for c = 1:size(cases, 1)
        M = cases{c,1}; prob = cases{c,2}; D = str2double(cases{c,3});
        fprintf('\n===== M=%d  %s  D=%d\n', M, prob, D);
        for a = 1:numel(algs)
            alg = algs{a};
            if M == 10
                rawDir = fullfile(rawRoot, '10目标', 'n30', alg);
            else
                rawDir = fullfile(rawRoot, sprintf('%d目标', M), alg);
            end
            rawFile = fullfile(rawDir, sprintf('%s_%s_M%d_D%d_1.mat', alg, prob, M, D));
            prodFile = fullfile(outBase, sprintf('IGDplus_M%d', M), alg, ...
                sprintf('%s_IGDp_M%d.mat', prob, M));
            rawOK = isfile(rawFile); prodOK = isfile(prodFile);
            fprintf('%-45s raw=%d prod=%d', alg, rawOK, prodOK);
            if rawOK
                S = load(rawFile);
                fn = fieldnames(S);
                mf = fieldnames(S.metric);
                fprintf(' | raw vars=[%s] metric=[%s]', strjoin(fn', ','), strjoin(mf', ','));
                if isfield(S, 'result')
                    fprintf(' nSnap=%d', size(S.result, 1));
                end
                if isfield(S.metric, 'IGD')
                    fprintf(' IGD=%dx%d', size(S.metric.IGD, 1), size(S.metric.IGD, 2));
                end
            end
            if prodOK
                P = load(prodFile);
                fprintf(' | prod runIds=%d-%d traceLen(run1)=%d', ...
                    min(P.runIds), max(P.runIds), numel(P.IGDpCell{1}));
            end
            fprintf('\n');
        end
    end
    fprintf('\nPROBE MERGE DONE\n');
end
