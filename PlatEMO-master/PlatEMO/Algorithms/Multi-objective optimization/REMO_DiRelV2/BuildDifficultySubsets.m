function [Subsets, SubsetInfo] = BuildDifficultySubsets(d_score, PopObj, cfg)
% BuildDifficultySubsets - 基于目标难度构造多个子目标 subset
%
% 与旧版 RefineEasySubset 的根本区别：
%   旧版：只产出一个 easy subset，且用 |rho|>0.95 当冗余规则
%         结果：强负相关目标被错误当作冗余删除
%   本版：
%     1. 一次产出 K 个 subset（多尺度 expert bank）
%        M >= 5: S1=ceil(M/3), S2=ceil(2M/3), Sfull=1:M
%        M = 3 or 4: S1=2 easiest, Sfull=1:M
%        M = 2: Sfull=1:M 单一
%     2. 冗余检查只对 rho > 0.95 的强正相关生效
%        rho < -0.95 (强负相关) 不视为冗余 —— 它们是信息互补
%     3. Sfull 总是包含完整目标集（full expert 始终存在）
%
% 输入：
%   d_score - M×1 目标难度分数（越大越难）
%   PopObj  - N×M 目标矩阵（用于冗余检查的 Spearman 相关）
%   cfg     - 配置：
%       .redundancyThresh   强正相关阈值，默认 0.95
%       .minSubsetSize      子集最小尺寸，默认 2
%
% 输出：
%   Subsets    - 1×K cell，每个元素是目标索引行向量
%   SubsetInfo - 1×K 结构体数组，每个元素：
%       .size        子集大小
%       .indices     目标索引
%       .meanDiff    子集平均难度
%       .redundancyRemoved  被冗余移除的目标索引（仅 S1/S2 适用）

    if nargin < 3 || isempty(cfg), cfg = struct(); end
    if ~isfield(cfg, 'redundancyThresh') || isempty(cfg.redundancyThresh)
        cfg.redundancyThresh = 0.95;
    end
    if ~isfield(cfg, 'minSubsetSize') || isempty(cfg.minSubsetSize)
        cfg.minSubsetSize = 2;
    end

    M = numel(d_score);
    d_score = d_score(:);

    % 按难度升序：第一个是最易目标
    [~, ord] = sort(d_score, 'ascend');

    % --- 计算 Spearman 相关矩阵供冗余检查 ---
    if size(PopObj, 1) >= 3 && M >= 2
        rho = corr(PopObj, 'type', 'Spearman');
        rho(isnan(rho)) = 0;
    else
        rho = eye(M);
    end

    % --- 确定 K 个 subset 的尺寸 ---
    if M >= 5
        sizes = [ceil(M/3), ceil(2*M/3), M];
        sizes = unique(min(sizes, M), 'stable');
    elseif M >= 3
        sizes = [max(2, ceil(M/2)), M];
        sizes = unique(min(sizes, M), 'stable');
    else
        sizes = M;
    end

    K = numel(sizes);
    Subsets    = cell(1, K);
    SubsetInfo = repmat(struct( ...
        'size', 0, 'indices', [], 'meanDiff', 0, 'redundancyRemoved', []), 1, K);

    for k = 1:K
        sz = sizes(k);

        if sz >= M
            % Full subset：始终包含所有目标
            S = (1:M);
            removed = [];
        else
            % easy-to-hard 取前 sz 个，再做强正相关冗余检查
            S = ord(1:sz)';
            [S, removed] = pruneStrongPositive(S, rho, d_score, ord, ...
                                              cfg.redundancyThresh, sz);
        end

        Subsets{k} = S(:)';
        SubsetInfo(k).size              = numel(S);
        SubsetInfo(k).indices           = S(:)';
        SubsetInfo(k).meanDiff          = mean(d_score(S));
        SubsetInfo(k).redundancyRemoved = removed(:)';
    end
end

% ===========================================================
function [S, removed] = pruneStrongPositive(S, rho, d_score, ord, thr, targetSize)
% 仅对强正相关 (rho > thr) 的目标对做冗余剔除，保留难度较低者
% 然后从 ord 中按难度顺序补位回 targetSize
    removed = [];
    if numel(S) <= 1
        return;
    end

    pool = ord(:)';
    poolPtr = 1;
    maxIter = 4 * numel(S);
    iter = 0;

    while iter < maxIter
        iter = iter + 1;
        S_changed = false;
        for i = 1:numel(S)
            for j = i+1:numel(S)
                a = S(i); b = S(j);
                if rho(a, b) > thr
                    % 强正相关：保留 d_score 小者
                    if d_score(a) <= d_score(b)
                        drop = b;
                    else
                        drop = a;
                    end
                    removed(end+1) = drop; %#ok<AGROW>
                    S(S == drop) = [];
                    % 补位
                    while poolPtr <= numel(pool)
                        cand = pool(poolPtr);
                        poolPtr = poolPtr + 1;
                        if ~ismember(cand, S) && ~ismember(cand, removed)
                            S(end+1) = cand; %#ok<AGROW>
                            break;
                        end
                    end
                    S_changed = true;
                    break;
                end
            end
            if S_changed, break; end
        end
        if ~S_changed, break; end
    end

    % 兜底
    if numel(S) < min(2, targetSize)
        % 选难度最低的两个
        S = ord(1:min(2, numel(ord)))';
    end
    S = unique(S, 'stable');
    if numel(S) > targetSize
        S = S(1:targetSize);
    end
end
