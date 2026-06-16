function selIdx = SelectTopDiverse_SGDA(Cand, scores, ArchDec, q, cfg)
% SelectTopDiverse_SGDA - Top score with archive/candidate distance guard.

    if nargin < 5 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'minDistArchive', 0.02);
    cfg = setIfMissing(cfg, 'minDistCand', 0.03);
    cfg = setIfMissing(cfg, 'Lower', []);
    cfg = setIfMissing(cfg, 'Upper', []);

    nC = size(Cand, 1);
    if nC == 0 || q <= 0
        selIdx = [];
        return;
    end

    if isempty(cfg.Lower) || isempty(cfg.Upper)
        cfg.Lower = min(Cand, [], 1);
        cfg.Upper = max(Cand, [], 1);
    end
    span = max(cfg.Upper - cfg.Lower, 1e-12);
    Cn = (Cand - cfg.Lower) ./ span;
    if isempty(ArchDec)
        An = zeros(0, size(Cand, 2));
    else
        An = (ArchDec - cfg.Lower) ./ span;
    end

    [~, ord] = sort(scores, 'descend');
    selIdx = [];
    rejected = [];
    for i = 1:nC
        idx = ord(i);
        x = Cn(idx, :);
        if ~isempty(An)
            dArch = min(sqrt(sum((An - x).^2, 2)));
            if dArch < cfg.minDistArchive
                rejected(end+1) = idx; %#ok<AGROW>
                continue;
            end
        end
        if ~isempty(selIdx)
            dSel = min(sqrt(sum((Cn(selIdx, :) - x).^2, 2)));
            if dSel < cfg.minDistCand
                rejected(end+1) = idx; %#ok<AGROW>
                continue;
            end
        end
        selIdx(end+1) = idx; %#ok<AGROW>
        if numel(selIdx) >= q
            return;
        end
    end

    if numel(selIdx) < q && ~isempty(rejected)
        [~, ord2] = sort(scores(rejected), 'descend');
        for i = 1:numel(ord2)
            selIdx(end+1) = rejected(ord2(i)); %#ok<AGROW>
            if numel(selIdx) >= q
                break;
            end
        end
    end
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
