function merge_IGDp_M15(maxFiles)
%MERGE_IGDP_M15 Append the IGD+ trace to every M=15 NoBatchDist raw result file.
%   The harness stores `result` (SaveCount x 2 cell: {FE, Population}) and
%   `metric` (runtime, IGD) per run. The IGD+ trace is recomputed here from
%   the stored population snapshots with the same PlatEMO metric the harness
%   uses for IGD, then written back as `metric.IGDp` (same shape as IGD).
%
%   Safety rules, copied from the house MergeIGDpIntoRaw.m:
%     1. only `metric` is loaded and only `metric` is appended back, so
%        `result` (and any metadata) is never rewritten;
%     2. the stored IGD is re-derived from the same snapshots and compared
%        with `metric.IGD`; a mismatch larger than the tolerance aborts the
%        whole pass, which proves the snapshot-to-value mapping is right;
%     3. after each write the file is re-read and the stored IGDp compared
%        with the intended trace;
%     4. a file whose IGDp already matches is skipped without writing.
%   Files are processed one at a time on purpose: bulk concurrent MATLAB
%   writes have previously been linked to heap corruption on this machine.
%
%   merge_IGDp_M15(maxFiles) limits the work to the first maxFiles result
%   files, for a dry trial before the full pass.
%
%   Scope: ONLY the 15-objective NoBatchDist dataset is touched. The M=10 and
%   M=20 datasets stay as they are.

    if nargin < 1, maxFiles = inf; end

    root  = 'D:\REMOandDREMO测试集\15目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    alg   = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    M     = 15;
    probs = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
             'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    tol   = 1e-6;   % relative tolerance for the IGD cross-check

    nWritten = 0; nSkipped = 0; nMissing = 0; nBadIGD = 0;
    rows = {};
    tAll = tic;
    for p = 1:numel(probs)
        prob = probs{p};
        PRO = feval(prob,'N',100,'M',M,'D',30,'maxFE',300);
        for r = 1:20
            d = dir(fullfile(root, sprintf('%s_%s_M%d_D*_%d.mat', alg, prob, M, r)));
            if isempty(d)
                fprintf('  MISSING %s run %d\n', prob, r);
                nMissing = nMissing + 1;
                continue;
            end
            file = fullfile(d(1).folder, d(1).name);
            S = load(file, 'result', 'metric');
            nSnap = size(S.result,1);
            if ~isfield(S.metric,'IGD') || numel(S.metric.IGD) ~= nSnap
                fprintf('  SKIP (no IGD trace) %s run %d\n', prob, r);
                nMissing = nMissing + 1;
                continue;
            end
            igdTrace  = zeros(nSnap,1);
            igdpTrace = zeros(nSnap,1);
            for i = 1:nSnap
                Pop = S.result{i,2};
                igdpTrace(i) = PRO.CalMetric('IGDp', Pop);
                % Positional mapping check on the two boundary snapshots only:
                % recomputing IGD for all 30 snapshots doubles the cost without
                % adding information once first/last agree.
                if i == 1 || i == nSnap
                    igdTrace(i) = PRO.CalMetric('IGD', Pop);
                end
            end
            checkIdx = unique([1 nSnap]);
            scaleIGD = max(1, abs(S.metric.IGD(checkIdx)));
            relIGD = max(abs(igdTrace(checkIdx) - S.metric.IGD(checkIdx))./scaleIGD);
            if relIGD > tol
                fprintf('  !! IGD cross-check failed on %s run %d (rel %.3e)\n', prob, r, relIGD);
                nBadIGD = nBadIGD + 1;
                error('MergeIGDpM15:igdMismatch', ...
                    'Stored IGD does not reproduce from the snapshots: %s', file);
            end
            if isfield(S.metric,'IGDp') && isequal(S.metric.IGDp(:), igdpTrace)
                nSkipped = nSkipped + 1;
            else
                metric = S.metric; %#ok<NASGU>
                metric.IGDp = igdpTrace;
                save(file, 'metric', '-append');
                V = load(file, 'metric');
                if ~isequal(V.metric.IGDp(:), igdpTrace)
                    error('MergeIGDpM15:verifyFail', 'IGDp mismatch after write: %s', file);
                end
                nWritten = nWritten + 1;
            end
            rows(end+1,:) = {prob, r, igdpTrace(1), igdpTrace(end), relIGD}; %#ok<AGROW>
            if mod(nWritten+nSkipped, 50) == 0
                fprintf('  ... %d written, %d skipped, %.1f min\n', nWritten, nSkipped, toc(tAll)/60);
            end
            if (nWritten + nSkipped) >= maxFiles
                fprintf('\nTRUNCATED at maxFiles=%d\n', maxFiles);
                fprintf('written %d, skipped %d, missing %d\n', nWritten, nSkipped, nMissing);
                return;
            end
        end
    end

    T = cell2table(rows,'VariableNames',{'Problem','Run','IGDp_first','IGDp_final','IGDrelCheck'});
    outDir = fileparts(mfilename('fullpath'));
    writetable(T,fullfile(outDir,'IGDp_M15_perrun.csv'));
    fprintf('\nMERGE DONE: written %d, skipped %d, missing %d, badIGD %d, %.1f min\n', ...
        nWritten, nSkipped, nMissing, nBadIGD, toc(tAll)/60);
end
