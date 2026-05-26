function PairBank = BuildPairBank_ParetoPBI(PopDec, PopObj, Subsets, RefCell, cfg)
% BuildPairBank_ParetoPBI - 真实 pairwise subset Pareto + PBI 关系标签
%
% 与旧版 GetRelationPairsBudgeted 的根本区别：
%   旧版：对每个解先用 GetOutput_PBI 分成正类/负类，再两类之间凑 +1/-1
%         pair 标签来自 Catalog 诱导，没有真正在"目标子集 S 下"做支配比较
%   本版：对每一对 (xa, xb)：
%         (1) 先做 subset Pareto：若 xa 在 S 上严格支配 xb，则 y=+1；反之 y=-1
%         (2) 互不支配时用 PBI fallback：算 min_v PBI(F, v)，比较 PBI 值
%         (3) PBI 差距 < tieMargin 视为 tie，标 0 或低权重
%   这样同一对解在不同 subset 下标签可以不同，才真正表达"多尺度关系"。
%
% 输入：
%   PopDec   - N×D 决策变量
%   PopObj   - N×M 目标值（最小化方向）
%   Subsets  - 1×K cell，每个元素是目标索引向量，例如 {[1 2 3],[1 2 3 5 7],1:M}
%   RefCell  - 1×K cell，每个元素是该 subset 下的参考向量 (numRef × |S|)
%   cfg      - 配置结构体，字段：
%       .pairMaxPerExpert  每个 expert 的最大 pair 数 (默认 6000)
%       .thetaPBI          PBI 罚因子 (默认 5)
%       .tieMargin         PBI 差距小于此值视为 tie (默认 1e-3，相对值)
%       .pairFeatureType   'concat' 或 'diffabs' (默认 'concat')
%       .balanceLabels     是否在三类标签间做平衡采样 (默认 true)
%       .useLabelWeight    是否给 PBI fallback 低 margin pair 低权重 (默认 true)
%
% 输出：
%   PairBank - 1×K 结构体数组，每个元素：
%       .subset       目标索引向量
%       .X            n×(2D) 或 n×D 关系对特征矩阵
%       .Y            n×1 ∈ {+1, 0, -1}
%       .W            n×1 ∈ [0,1] 置信度权重
%       .stats        struct，记录三类标签数、PBI fallback 比例、低 margin 比例

    % ===================== 默认配置 =====================
    if nargin < 5 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'pairMaxPerExpert', 6000);
    cfg = setIfMissing(cfg, 'thetaPBI',         5);
    cfg = setIfMissing(cfg, 'tieMargin',        1e-3);
    cfg = setIfMissing(cfg, 'pairFeatureType',  'concat');
    cfg = setIfMissing(cfg, 'balanceLabels',    true);
    cfg = setIfMissing(cfg, 'useLabelWeight',   true);

    K = numel(Subsets);
    PairBank = repmat(struct( ...
        'subset', [], 'X', [], 'Y', [], 'W', [], 'stats', struct()), 1, K);

    [N, ~] = size(PopDec);
    if N < 2
        for k = 1:K
            PairBank(k).subset = Subsets{k};
            PairBank(k).stats  = emptyStats();
        end
        return;
    end

    % ===================== 对每个 subset 构造 PairBank =====================
    for k = 1:K
        S    = Subsets{k}(:)';
        Fsub = PopObj(:, S);
        V    = RefCell{k};

        % 子集下的归一化范围：用 q10/q90 而非 min/max，对离群点更鲁棒
        Pmin = quantile(Fsub, 0.10, 1);
        Pmax = quantile(Fsub, 0.90, 1);
        Pspan = max(Pmax - Pmin, 1e-12);
        Fnorm = (Fsub - Pmin) ./ Pspan;

        % 预算分配：每类最多 perClass
        budget = max(3, cfg.pairMaxPerExpert);

        % --------- 阶段 1：列举 pair 候选并打标签 ---------
        % 完整枚举 O(N^2) 太贵，N>120 时分阶段采样
        if N <= 120
            [ia, ib] = meshgrid(1:N, 1:N);
            ia = ia(:); ib = ib(:);
            keep = ia ~= ib;
            ia = ia(keep); ib = ib(keep);
        else
            % 上限 4*budget 个候选 pair
            nSample = min(4*budget, N*(N-1));
            ia = randi(N, nSample, 1);
            ib = randi(N, nSample, 1);
            mask = ia ~= ib;
            ia = ia(mask); ib = ib(mask);
        end

        nPair = numel(ia);
        Y = zeros(nPair, 1);
        W = ones(nPair, 1);
        srcPareto = false(nPair, 1);   % 是否由 Pareto 决定的标签

        Fa = Fsub(ia, :);   Fb = Fsub(ib, :);
        Fna = Fnorm(ia, :); Fnb = Fnorm(ib, :);

        % subset Pareto 比较（最小化方向）：xa 支配 xb 当且仅当
        % all(Fa <= Fb) && any(Fa < Fb)
        leqAll = all(Fa <= Fb, 2);
        ltAny  = any(Fa <  Fb, 2);
        geqAll = all(Fa >= Fb, 2);
        gtAny  = any(Fa >  Fb, 2);

        aDomb = leqAll & ltAny;
        bDoma = geqAll & gtAny;
        nondom = ~(aDomb | bDoma);

        Y(aDomb) = +1;
        Y(bDoma) = -1;
        srcPareto(aDomb | bDoma) = true;

        % --------- 阶段 2：互不支配 pair 用 PBI fallback ---------
        idxNd = find(nondom);
        if ~isempty(idxNd)
            % 计算 PBI(Fnorm_i, V) 矩阵，再取每行最小作为 g_i
            % gA, gB 是每个候选 pair 的两端 PBI 值
            gA = minPBI(Fna(idxNd, :), V, cfg.thetaPBI);
            gB = minPBI(Fnb(idxNd, :), V, cfg.thetaPBI);

            % 相对 margin
            scale = max(max(abs(gA), abs(gB)), 1e-12);
            relDiff = (gB - gA) ./ scale;  % 正 = a 更好（PBI 小）

            yPBI = zeros(numel(idxNd), 1);
            wPBI = ones(numel(idxNd), 1);

            yPBI(relDiff > cfg.tieMargin)  = +1;
            yPBI(relDiff < -cfg.tieMargin) = -1;
            % 中间一段为 0

            % 低 margin pair 给低权重（线性映射）
            if cfg.useLabelWeight
                wPBI = min(1, abs(relDiff) ./ (5*cfg.tieMargin));
                wPBI = max(wPBI, 0.1);   % 最低 0.1 保底
            end

            Y(idxNd) = yPBI;
            W(idxNd) = wPBI;
        end

        % --------- 阶段 3：按预算平衡采样 ---------
        idxP = find(Y == +1);
        idxN = find(Y == -1);
        idxZ = find(Y == 0);

        if cfg.balanceLabels
            perClass = max(1, floor(budget/3));
            idxP = sampleRand(idxP, perClass);
            idxN = sampleRand(idxN, perClass);
            idxZ = sampleRand(idxZ, perClass);
        else
            % 不平衡也要做硬上限
            allIdx = [idxP; idxN; idxZ];
            if numel(allIdx) > budget
                allIdx = allIdx(randperm(numel(allIdx), budget));
            end
            idxP = intersect(allIdx, idxP);
            idxN = intersect(allIdx, idxN);
            idxZ = intersect(allIdx, idxZ);
        end

        finalIdx = [idxP; idxN; idxZ];
        finalIdx = finalIdx(randperm(numel(finalIdx)));

        % --------- 阶段 4：构造 pair 特征 ---------
        Xa = PopDec(ia(finalIdx), :);
        Xb = PopDec(ib(finalIdx), :);
        switch lower(cfg.pairFeatureType)
            case 'diffabs'
                X = abs(Xa - Xb);
            otherwise % 'concat'
                X = [Xa, Xb];
        end

        % --------- 输出 ---------
        PairBank(k).subset = S;
        PairBank(k).X = X;
        PairBank(k).Y = Y(finalIdx);
        PairBank(k).W = W(finalIdx);

        % 统计
        st.subsetSize    = numel(S);
        st.nPosRaw       = numel(idxP);
        st.nNegRaw       = numel(idxN);
        st.nZeroRaw      = numel(idxZ);
        st.paretoRatio   = mean(srcPareto);              % 由 Pareto 直接定标签的比例
        st.lowMarginRate = mean(W(idxNd) < 0.5);
        st.totalPair     = numel(finalIdx);
        st.labelHist     = [sum(PairBank(k).Y == +1), ...
                            sum(PairBank(k).Y == 0), ...
                            sum(PairBank(k).Y == -1)];
        PairBank(k).stats = st;
    end
end

% ===========================================================
%  局部工具
% ===========================================================

function g = minPBI(F, V, theta)
% PBI scalarizing value, then take min over reference vectors.
% F : n × m (normalized to [0,1] roughly)
% V : R × m reference vectors (unit-length recommended)
% theta : penalty factor
    if isempty(V) || size(V, 2) ~= size(F, 2)
        % fallback: weighted L1
        g = sum(F, 2);
        return;
    end
    % normalize V to unit length row-wise
    Vn = V ./ max(sqrt(sum(V.^2, 2)), 1e-12);
    % d1 = projection length, d2 = perpendicular distance
    n = size(F, 1);
    R = size(Vn, 1);
    g = inf(n, 1);
    for r = 1:R
        v = Vn(r, :);
        d1 = F * v';                       % n × 1
        proj = d1 * v;                     % n × m
        d2 = sqrt(sum((F - proj).^2, 2));  % n × 1
        gr = d1 + theta * d2;
        g = min(g, gr);
    end
end

function s = sampleRand(idx, n)
    if isempty(idx) || n <= 0
        s = zeros(0, 1); return;
    end
    if numel(idx) <= n
        s = idx(:);
    else
        s = idx(randperm(numel(idx), n));
        s = s(:);
    end
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end

function s = emptyStats()
    s = struct('subsetSize', 0, 'nPosRaw', 0, 'nNegRaw', 0, 'nZeroRaw', 0, ...
        'paretoRatio', 0, 'lowMarginRate', 0, 'totalPair', 0, 'labelHist', [0 0 0]);
end
