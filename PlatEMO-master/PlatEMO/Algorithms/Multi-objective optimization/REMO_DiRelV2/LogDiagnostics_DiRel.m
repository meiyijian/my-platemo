function Diag = LogDiagnostics_DiRel(Diag, gen, DiffState, SubsetInfo, PairBank, ...
                                     Experts, scoreDbg, selIdx, Cand, Archive, runtime)
% LogDiagnostics_DiRel - 收集每代诊断信息，便于后续画图/分析
%
% Diag 是一个累积结构体，第一次传入空 struct 即可。
% 每代调用一次，把本代的状态 append 进去。
%
% 字段（全部按代累积）：
%   .gen                   1×G
%   .M                     标量
%   .difficulty            M×G   D_total 历史
%   .Dprog, Dlearn, Dconf, Dsens, Dspan : M×G
%   .subsetSizes           K×G
%   .subsetIndices         1×G cell of cell
%   .labelHist             G×1 cell of (K×3) label histograms
%   .expertValErr          K×G
%   .expertBrier           K×G
%   .expertValid           K×G (logical)
%   .scoreStats            G×6 [meanR, meanU, meanNov, meanDisagree, meanWeighted, std]
%   .nCandidates           1×G
%   .nSelected             1×G
%   .runtime               1×G
%   .archiveSize           1×G
%   .archiveMinObjs        M×G  archive 各目标当前 min
%   .archiveMedObjs        M×G  各目标中位数
%
% 用法：
%   Diag = LogDiagnostics_DiRel(Diag, gen, ..., toc);

    if isempty(Diag) || ~isstruct(Diag)
        Diag = struct();
    end

    Diag = appendCol(Diag, 'gen', gen);
    Diag = appendCol(Diag, 'difficulty', DiffState.total(:));
    Diag = appendCol(Diag, 'Dprog',  DiffState.Dprog(:));
    Diag = appendCol(Diag, 'Dlearn', DiffState.Dlearn(:));
    Diag = appendCol(Diag, 'Dconf',  DiffState.Dconf(:));
    Diag = appendCol(Diag, 'Dsens',  DiffState.Dsens(:));
    Diag = appendCol(Diag, 'Dspan',  DiffState.Dspan(:));

    if ~isempty(SubsetInfo)
        sizes = arrayfun(@(s) s.size, SubsetInfo)';
        Diag = appendCol(Diag, 'subsetSizes', sizes);
    end

    % label histogram per expert
    if ~isempty(PairBank)
        K = numel(PairBank);
        labelHist = zeros(K, 3);
        paretoRatio = zeros(K, 1);
        for k = 1:K
            if ~isempty(PairBank(k).stats)
                labelHist(k, :) = PairBank(k).stats.labelHist;
                paretoRatio(k) = PairBank(k).stats.paretoRatio;
            end
        end
        Diag = appendCell(Diag, 'labelHist', labelHist);
        Diag = appendCol(Diag, 'paretoRatio', paretoRatio);
    end

    % expert
    if ~isempty(Experts)
        K = numel(Experts);
        valErr = arrayfun(@(e) e.valError, Experts)';
        brier  = arrayfun(@(e) e.brier, Experts)';
        valid  = arrayfun(@(e) double(e.valid), Experts)';
        Diag = appendCol(Diag, 'expertValErr', valErr);
        Diag = appendCol(Diag, 'expertBrier', brier);
        Diag = appendCol(Diag, 'expertValid', valid);
    end

    % score stats
    if ~isempty(scoreDbg) && isfield(scoreDbg, 'R') && ~isempty(scoreDbg.R)
        stats = [meanSafe(scoreDbg.weightedR), meanSafe(scoreDbg.U), ...
                 meanSafe(scoreDbg.Nov),       meanSafe(scoreDbg.Disagree), ...
                 meanSafe(scoreDbg.weightedR), stdSafe(scoreDbg.weightedR)];
        Diag = appendCol(Diag, 'scoreStats', stats(:));
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
    if ~isfield(S, name)
        S.(name) = col(:);
    else
        cur = S.(name);
        if size(cur, 1) ~= numel(col) && ~isscalar(col)
            % 行/列不一致：fallback to cell
            if ~iscell(cur)
                S.(name) = {cur};
            end
            S.(name){end+1} = col;
        else
            S.(name) = [cur, col(:)];
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
    if isempty(x), m = NaN; else, m = mean(x(:), 'omitnan'); end
end

function s = stdSafe(x)
    if isempty(x) || numel(x) < 2, s = 0; else, s = std(x(:), 'omitnan'); end
end
