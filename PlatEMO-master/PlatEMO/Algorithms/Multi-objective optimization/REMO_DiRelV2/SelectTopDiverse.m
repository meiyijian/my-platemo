function selIdx = SelectTopDiverse(Cand, scores, ArchDec, q, cfg)
% SelectTopDiverse - 在 score 排序基础上做最小距离约束
%
% 与"取 score>3.9"或"top-q"的根本区别：
%   纯 top-q：可能选出 q 个几乎相同的候选解（高分聚集）
%   纯阈值：批次相对，代间不可比
%   本版：top-q + greedy 最小决策距离约束（避免和 archive 已有点撞上）
%
% 算法（greedy）：
%   1. 按 score 降序排序候选
%   2. 维护已选集 sel，从高到低逐个尝试加入：
%      - 与 archive 任一解的归一化决策距离 < minDistArchive 时 reject
%      - 与 sel 任一解的距离 < minDistCand 时 reject
%   3. 若选满 q 个或扫完候选则结束
%   4. 兜底：不足 q 个时，按 score 顺序补齐到 q
%
% 输入：
%   Cand     - nC × D 候选解
%   scores   - nC × 1 得分（越大越好）
%   ArchDec  - 已评估 archive
%   q        - 期望返回个数
%   cfg      - .minDistArchive 0.02 (归一化距离阈值)
%              .minDistCand    0.03
%              .Lower, .Upper  决策变量边界
%
% 输出：
%   selIdx   - 1×q（或更短）被选中的索引

    if nargin < 5 || isempty(cfg), cfg = struct(); end
    if ~isfield(cfg, 'minDistArchive'), cfg.minDistArchive = 0.02; end
    if ~isfield(cfg, 'minDistCand'),    cfg.minDistCand    = 0.03; end
    if ~isfield(cfg, 'Lower'), cfg.Lower = []; end
    if ~isfield(cfg, 'Upper'), cfg.Upper = []; end

    nC = size(Cand, 1);
    if nC == 0 || q <= 0
        selIdx = []; return;
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

        % 与 archive 距离
        if size(An, 1) > 0
            d_arch = min(sqrt(sum((An - x).^2, 2)));
            if d_arch < cfg.minDistArchive
                rejected(end+1) = idx; %#ok<AGROW>
                continue;
            end
        end

        % 与已选 cand 距离
        if ~isempty(selIdx)
            sub = Cn(selIdx, :);
            d_sel = min(sqrt(sum((sub - x).^2, 2)));
            if d_sel < cfg.minDistCand
                rejected(end+1) = idx; %#ok<AGROW>
                continue;
            end
        end

        selIdx(end+1) = idx; %#ok<AGROW>
        if numel(selIdx) >= q
            return;
        end
    end

    % 兜底：不足 q 个时从 rejected 中按 score 补齐
    if numel(selIdx) < q && ~isempty(rejected)
        rs = scores(rejected);
        [~, ord2] = sort(rs, 'descend');
        for i = 1:numel(ord2)
            selIdx(end+1) = rejected(ord2(i)); %#ok<AGROW>
            if numel(selIdx) >= q, break; end
        end
    end
end
