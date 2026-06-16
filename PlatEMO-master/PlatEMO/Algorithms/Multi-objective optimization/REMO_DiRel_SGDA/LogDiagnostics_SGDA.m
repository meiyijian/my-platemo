function Diag = LogDiagnostics_SGDA(Diag, gen, DiffState, Groups, GroupInfo, ...
                                    PairBank, Experts, scoreDbg, selIdx, Cand, Archive, runtime)
% LogDiagnostics_SGDA - Per-generation diagnostics for SGDA experiments.

    if isempty(Diag) || ~isstruct(Diag)
        Diag = struct();
    end

    Diag = appendCol(Diag, 'gen', gen);
    Diag = appendCol(Diag, 'difficulty', DiffState.total(:));
    Diag = appendCol(Diag, 'Dprog', DiffState.Dprog(:));
    Diag = appendCol(Diag, 'Dlearn', DiffState.Dlearn(:));
    Diag = appendCol(Diag, 'Dconf', DiffState.Dconf(:));
    Diag = appendCol(Diag, 'Dsens', DiffState.Dsens(:));
    Diag = appendCol(Diag, 'Dspan', DiffState.Dspan(:));

    Diag = appendCell(Diag, 'groups', Groups);
    Diag = appendCol(Diag, 'groupSizes', GroupInfo.groupSizes(:));
    Diag = appendCol(Diag, 'groupDifficulty', GroupInfo.groupDifficulty(:));
    Diag = appendCol(Diag, 'groupReliability', GroupInfo.groupReliability(:));
    Diag = appendCell(Diag, 'groupSimilarity', GroupInfo.similarity);

    if ~isempty(PairBank)
        K = numel(PairBank);
        labelHist = zeros(K, 3);
        paretoRatio = zeros(K, 1);
        for k = 1:K
            if isfield(PairBank(k), 'stats') && ~isempty(PairBank(k).stats)
                labelHist(k, :) = PairBank(k).stats.labelHist;
                paretoRatio(k) = PairBank(k).stats.paretoRatio;
            end
        end
        Diag = appendCell(Diag, 'labelHist', labelHist);
        Diag = appendCol(Diag, 'paretoRatio', paretoRatio);
    end

    if ~isempty(Experts)
        valErr = arrayfun(@(e) e.valError, Experts)';
        brier = arrayfun(@(e) e.brier, Experts)';
        valid = arrayfun(@(e) double(e.valid), Experts)';
        rel = arrayfun(@(e) e.groupReliability, Experts)';
        Diag = appendCol(Diag, 'expertValErr', valErr);
        Diag = appendCol(Diag, 'expertBrier', brier);
        Diag = appendCol(Diag, 'expertValid', valid);
        Diag = appendCol(Diag, 'expertGroupReliability', rel);
    end

    if ~isempty(scoreDbg) && isfield(scoreDbg, 'fusedScore') && ~isempty(scoreDbg.fusedScore)
        fullUncertainRatio = mean(scoreDbg.fullUncertain);
        tieBreakRatio = mean(scoreDbg.tieActive);
        groupConflictRatio = mean(scoreDbg.groupConflict);
        scoreStats = [meanSafe(scoreDbg.fullOnlyScore), varSafe(scoreDbg.fullOnlyScore), ...
                      meanSafe(scoreDbg.groupOnlyScore), varSafe(scoreDbg.groupOnlyScore), ...
                      meanSafe(scoreDbg.fusedScore), varSafe(scoreDbg.fusedScore)];
        Diag = appendCol(Diag, 'fullUncertainRatio', fullUncertainRatio);
        Diag = appendCol(Diag, 'tieBreakRatio', tieBreakRatio);
        Diag = appendCol(Diag, 'groupConflictRatio', groupConflictRatio);
        Diag = appendCol(Diag, 'scoreStatsSGDA', scoreStats(:));

        modeHist = zeros(3, 1);
        if ~isempty(selIdx)
            m = scoreDbg.mode(selIdx);
            modeHist = [sum(m == 1); sum(m == 2); sum(m == 0)];
        end
        Diag = appendCol(Diag, 'selectedModeHist', modeHist);
    end

    if ~isempty(Cand)
        Diag = appendCol(Diag, 'nCandidates', size(Cand, 1));
    end
    Diag = appendCol(Diag, 'nSelected', numel(selIdx));
    Diag = appendCol(Diag, 'runtime', runtime);
    if ~isempty(Archive)
        Diag = appendCol(Diag, 'archiveSize', length(Archive));
        Diag = appendCol(Diag, 'archiveMinObjs', min(Archive.objs, [], 1)');
        Diag = appendCol(Diag, 'archiveMedObjs', median(Archive.objs, 1)');
    end
end

function S = appendCol(S, name, col)
    col = col(:);
    if ~isfield(S, name)
        S.(name) = col;
    else
        cur = S.(name);
        if size(cur, 1) ~= numel(col)
            if ~iscell(cur)
                S.(name) = {cur};
            end
            S.(name){end+1} = col;
        else
            S.(name) = [cur, col];
        end
    end
end

function S = appendCell(S, name, val)
    if ~isfield(S, name)
        S.(name) = {val};
    else
        S.(name){end+1} = val;
    end
end

function m = meanSafe(x)
    if isempty(x)
        m = NaN;
    else
        m = mean(x(:), 'omitnan');
    end
end

function v = varSafe(x)
    if isempty(x) || numel(x) < 2
        v = 0;
    else
        v = var(x(:), 'omitnan');
    end
end
