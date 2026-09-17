function MergeIGDpIntoRaw(Mlist, maxFiles)
%MergeIGDpIntoRaw Append the IGD+ trace of every run to its own raw result file.
%   The IGD+ values live per problem in the IGDplus_M* products; here they are
%   distributed back to the individual run files, which is exactly what the
%   PlatEMO Experiment module does when a new metric is computed for stored
%   results (module_exp.m writes metric with '-append').
%
%   Safety rules applied to every single file:
%     1. only the 'metric' variable is loaded and only 'metric' is written back,
%        so result and metadata are never touched. The write is idempotent:
%        a second pass over the same file produces the same bytes for metric.
%     2. after writing, the file is re-read and the stored IGDp is compared
%        with the intended trace; any mismatch aborts the whole run, so a
%        silent corruption cannot pass unnoticed.
%     3. a file whose stored IGDp already matches is skipped without writing.
%   Files are processed one at a time on purpose: bulk concurrent MATLAB
%   writes have previously been linked to heap corruption on this machine.
%
%   MergeIGDpIntoRaw(Mlist, maxFiles) limits the work to the first maxFiles
%   result files, which is meant for a dry trial before the full pass.

    if nargin < 1 || isempty(Mlist), Mlist = [10 15 20]; end
    if nargin < 2, maxFiles = inf; end

    rawRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    outBase = 'C:\Users\lsx\Desktop\AdaMao实验表';
    algs = {'REMO_UniformMix_Pruned_Weighted_Lambdat030','REMO','PIEA', ...
            'CSEA','PCSAEA_N100','KRVEA_100','MCEAD'};
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    nWritten = 0; nSkipped = 0; nMissing = 0; nChecked = 0;
    tAll = tic;
    for mi = 1:numel(Mlist)
        M = Mlist(mi);
        for a = 1:numel(algs)
            alg = algs{a};
            if M == 10
                rawDir = fullfile(rawRoot, '10目标', 'n30', alg);
            else
                rawDir = fullfile(rawRoot, sprintf('%d目标', M), alg);
            end
            for p = 1:numel(problems)
                prob = problems{p};
                prod = fullfile(outBase, sprintf('IGDplus_M%d', M), alg, ...
                    sprintf('%s_IGDp_M%d.mat', prob, M));
                if ~isfile(prod)
                    fprintf('[M%d %s %s] no product, skipped\n', M, alg, prob);
                    continue;
                end
                P = load(prod, 'IGDpCell', 'runIds');
                for i = 1:numel(P.runIds)
                    run = P.runIds(i);
                    d = dir(fullfile(rawDir, sprintf('%s_%s_M%d_D*_%d.mat', alg, prob, M, run)));
                    if isempty(d)
                        fprintf('  MISSING raw file: %s %s M%d run %d\n', alg, prob, M, run);
                        nMissing = nMissing + 1;
                        continue;
                    end
                    file = fullfile(d(1).folder, d(1).name);
                    want = P.IGDpCell{i}(:);
                    S = load(file, 'metric');
                    if isfield(S.metric, 'IGDp') && isequal(S.metric.IGDp(:), want)
                        nSkipped = nSkipped + 1;
                        continue;
                    end
                    metric = S.metric; %#ok<NASGU>
                    metric.IGDp = want;
                    save(file, 'metric', '-append');
                    V = load(file, 'metric');
                    if ~isequal(V.metric.IGDp(:), want)
                        error('MergeIGDp:verifyFail', 'IGDp mismatch after write: %s', file);
                    end
                    nWritten = nWritten + 1;
                    nChecked = nChecked + 1;
                    if mod(nWritten, 200) == 0
                        fprintf('  ... %d written, %.1f min\n', nWritten, toc(tAll)/60);
                    end
                    if nWritten >= maxFiles
                        fprintf('\nTRUNCATED at maxFiles=%d\n', maxFiles);
                        fprintf('written %d, skipped %d, missing %d, checked %d, %.1f min\n', ...
                            nWritten, nSkipped, nMissing, nChecked, toc(tAll)/60);
                        return;
                    end
                end
            end
        end
    end
    fprintf('\nMERGE DONE: written %d, skipped %d, missing %d, verified %d, %.1f min\n', ...
        nWritten, nSkipped, nMissing, nChecked, toc(tAll)/60);
end
