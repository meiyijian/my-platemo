function Anchors = SelectRelationAnchors(ArchDec, ArchObj, cfg)
% SelectRelationAnchors - 选择用于关系评分的 anchor 解
%
% 与旧 ArbitratorScore::selectAnchors 的根本区别：
%   旧版：从 pair 训练集中按 Y==1 / Y~=1 选 anchor，pair-level 和 individual-level 混淆
%   本版：直接从 archive / population 选 individual anchors
%       1. 优先 nondominated 解作为 elite anchor
%       2. 按 archive 的目标空间均匀采样保留 diverse anchor
%       3. 少量保留 dominated 但多样的解，用于对比
%
% 输入：
%   ArchDec  - N×D archive 决策变量
%   ArchObj  - N×M archive 目标值
%   cfg      - .anchorMax       anchor 上限（按类别），默认 30
%              .nondomRatio     nondominated 占比，默认 0.6
%
% 输出：
%   Anchors  - 结构体：
%       .elite      n_e × D nondominated/elite 解（用作"好" anchor）
%       .diverse    n_d × D 多样性 anchor（包含部分 dominated）
%       .eliteObj   对应目标
%       .diverseObj 对应目标

    if nargin < 3 || isempty(cfg), cfg = struct(); end
    if ~isfield(cfg, 'anchorMax'), cfg.anchorMax = 30; end
    if ~isfield(cfg, 'nondomRatio'), cfg.nondomRatio = 0.6; end

    Anchors = struct('elite', [], 'diverse', [], 'eliteObj', [], 'diverseObj', []);
    [N, D] = size(ArchDec);
    if N == 0
        return;
    end

    % --- 1. nondominated 排序 ---
    % 用 PlatEMO 的 NDSort 如果存在；否则手写
    try
        [FrontNo, ~] = NDSort(ArchObj, N);
    catch
        FrontNo = simpleND(ArchObj);
    end

    nondomIdx = find(FrontNo == 1);
    if isempty(nondomIdx)
        nondomIdx = 1:N;
    end

    % elite: nondominated 中均匀采样
    n_e = min(numel(nondomIdx), ceil(cfg.anchorMax * cfg.nondomRatio));
    if numel(nondomIdx) > n_e
        % crowding-like 均匀采样：按目标空间 farthest-first
        eliteIdx = uniformSample(ArchObj(nondomIdx, :), n_e);
        eliteIdx = nondomIdx(eliteIdx);
    else
        eliteIdx = nondomIdx;
    end

    Anchors.elite    = ArchDec(eliteIdx, :);
    Anchors.eliteObj = ArchObj(eliteIdx, :);

    % --- 2. diverse: 余下数量从其他解中选最分散 ---
    n_d = cfg.anchorMax - numel(eliteIdx);
    if n_d > 0
        otherIdx = setdiff(1:N, eliteIdx, 'stable');
        if numel(otherIdx) > n_d
            divIdx = uniformSample(ArchObj(otherIdx, :), n_d);
            divIdx = otherIdx(divIdx);
        else
            divIdx = otherIdx;
        end
        Anchors.diverse    = ArchDec(divIdx, :);
        Anchors.diverseObj = ArchObj(divIdx, :);
    end
end

% ===========================================================
function pick = uniformSample(F, k)
% farthest-first traversal in objective space
    n = size(F, 1);
    if k >= n
        pick = 1:n;
        return;
    end
    % normalize
    Fmin = min(F, [], 1); Fmax = max(F, [], 1);
    span = max(Fmax - Fmin, 1e-12);
    Fn = (F - Fmin) ./ span;

    pick = zeros(1, k);
    pick(1) = 1;
    dist = sqrt(sum((Fn - Fn(1, :)).^2, 2));
    for i = 2:k
        [~, idx] = max(dist);
        pick(i) = idx;
        newD = sqrt(sum((Fn - Fn(idx, :)).^2, 2));
        dist = min(dist, newD);
    end
end

function FrontNo = simpleND(Obj)
% 简易非支配排序（仅在 NDSort 不可用时 fallback）
    N = size(Obj, 1);
    FrontNo = inf(1, N);
    rem = true(1, N);
    front = 0;
    while any(rem)
        front = front + 1;
        idx = find(rem);
        domByOther = false(1, numel(idx));
        for i = 1:numel(idx)
            for j = 1:numel(idx)
                if i == j, continue; end
                a = Obj(idx(i), :); b = Obj(idx(j), :);
                if all(b <= a) && any(b < a)
                    domByOther(i) = true; break;
                end
            end
        end
        FrontNo(idx(~domByOther)) = front;
        rem(idx(~domByOther)) = false;
    end
end
