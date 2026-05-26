function [scores, dbg] = ScoreCandidates_DiRel(Candidates, Anchors, Experts, ArchiveDec, cfg)
% ScoreCandidates_DiRel - Reliability-calibrated relation acquisition
%
% 与旧 ArbitratorScore 的根本区别：
%   旧版：mu_F / mu_S 分别 min-max 到 [0,4]，逆方差融合，固定 3.9 阈值
%         没有 archive novelty，没有 disagreement 显式信号
%   本版：
%     Score(x) = sum_e w_e(x) * R_e(x) + beta*U(x) + gamma*Nov(x) - lambda*Disagree(x)
%       R_e(x)      : expected-win on anchors，单位无关于 batch
%       w_e(x)      : 全局可靠性 * 局部置信度，full expert 设最低权重下限
%       U(x)        : ensemble 内方差
%       Nov(x)      : archive-aware novelty （决策空间归一化最小距离）
%       Disagree(x) : full expert 与 subset experts 方向冲突惩罚
%
% 输入：
%   Candidates - nC × D 候选解决策变量
%   Anchors    - 来自 SelectRelationAnchors，含 elite / diverse
%   Experts    - 来自 TrainRelationExperts，最后一个被视为 full expert
%   ArchiveDec - 归一化用：archive 决策变量
%   cfg        - 字段：
%       .beta              U 权重，默认 0.10
%       .gamma             Novelty 权重，默认 0.15
%       .lambda            Disagree 惩罚，默认 0.25
%       .minFullWeight     full expert 最低权重，默认 0.30
%       .pairFeatureType   与 PairBank 一致，默认 'concat'
%       .Lower, .Upper     决策变量边界（用于 novelty 归一化）
%
% 输出：
%   scores - nC × 1 综合得分，越大越好
%   dbg    - 诊断字段：
%       .R   nC × K      每 expert 的 anchor expected-win
%       .U   nC × 1      ensemble variance
%       .Nov nC × 1
%       .Disagree nC × 1
%       .weights nC × K  每候选的 expert 权重
%       .localConf nC × K
%       .globalRel 1 × K

    if nargin < 5 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'beta', 0.10);
    cfg = setIfMissing(cfg, 'gamma', 0.15);
    cfg = setIfMissing(cfg, 'lambda', 0.25);
    cfg = setIfMissing(cfg, 'minFullWeight', 0.30);
    cfg = setIfMissing(cfg, 'pairFeatureType', 'concat');
    cfg = setIfMissing(cfg, 'Lower', []);
    cfg = setIfMissing(cfg, 'Upper', []);

    [nC, D] = size(Candidates);
    K = numel(Experts);
    if nC == 0
        scores = zeros(0, 1);
        dbg = emptyDbg(K);
        return;
    end

    % 没有有效 expert 时，全部返回 0（让上层 fallback 接管）
    validMask = false(1, K);
    for k = 1:K, validMask(k) = Experts(k).valid; end
    if ~any(validMask)
        scores = zeros(nC, 1);
        dbg = emptyDbg(K);
        return;
    end

    fullIdx = K;   % 约定：最后一个是 full expert

    % ============================================================
    % 1. 准备 anchor 集合
    % ============================================================
    anchorDec = [Anchors.elite; Anchors.diverse];
    eliteFlag = [true(size(Anchors.elite, 1), 1); false(size(Anchors.diverse, 1), 1)];
    nA = size(anchorDec, 1);
    if nA == 0
        scores = zeros(nC, 1);
        dbg = emptyDbg(K);
        return;
    end

    % ============================================================
    % 2. 对每个 expert 计算 R(x), U(x), localConf(x)
    % ============================================================
    R         = zeros(nC, K);
    U_perExp  = zeros(nC, K);
    localConf = zeros(nC, K);
    globalRel = zeros(1, K);

    for k = 1:K
        if ~Experts(k).valid
            globalRel(k) = 0; continue;
        end
        e = Experts(k);
        globalRel(k) = max(0, 1 - e.valError);   % 1 - error rate

        [Rk, Uk, Ck] = expertScore(Candidates, anchorDec, eliteFlag, e, cfg);
        R(:, k)         = Rk;
        U_perExp(:, k)  = Uk;
        localConf(:, k) = Ck;
    end

    % ============================================================
    % 3. 计算每候选的 expert 权重
    % ============================================================
    weights = zeros(nC, K);
    for k = 1:K
        weights(:, k) = globalRel(k) .* localConf(:, k);
    end
    % full expert 最低权重保护
    if validMask(fullIdx)
        fullMin = cfg.minFullWeight * (sum(weights, 2) + 1e-12);
        weights(:, fullIdx) = max(weights(:, fullIdx), fullMin);
    end
    % 归一化
    sumW = sum(weights, 2);
    sumW(sumW < 1e-12) = 1;
    weights = weights ./ sumW;

    % ============================================================
    % 4. 加权 R + 不确定度 U
    % ============================================================
    weightedR = sum(weights .* R, 2);
    U_overall = sum(weights .* U_perExp, 2);

    % ============================================================
    % 5. Archive-aware novelty
    % ============================================================
    Nov = archiveNovelty(Candidates, ArchiveDec, cfg.Lower, cfg.Upper);

    % ============================================================
    % 6. Full vs subset disagreement
    % ============================================================
    if validMask(fullIdx) && sum(validMask) >= 2
        Rfull = R(:, fullIdx);
        % 加权平均 subset expert R
        subMask = validMask;
        subMask(fullIdx) = false;
        if any(subMask)
            wSub = weights(:, subMask);
            wSub = wSub ./ max(sum(wSub, 2), 1e-12);
            Rsub = sum(wSub .* R(:, subMask), 2);
            % 反向程度：sign 不同且都置信
            cf_full = localConf(:, fullIdx);
            cf_sub  = mean(localConf(:, subMask), 2);
            Disagree = max(0, -Rfull .* Rsub) .* cf_full .* cf_sub;
            % 归一化到 [0,1]
            Disagree = Disagree ./ max(max(Disagree), 1e-12);
        else
            Disagree = zeros(nC, 1);
        end
    else
        Disagree = zeros(nC, 1);
    end

    % ============================================================
    % 7. 最终 score
    % ============================================================
    scores = weightedR + cfg.beta * U_overall + cfg.gamma * Nov - cfg.lambda * Disagree;

    % ============================================================
    % 诊断
    % ============================================================
    dbg = struct();
    dbg.R         = R;
    dbg.U         = U_overall;
    dbg.U_perExp  = U_perExp;
    dbg.Nov       = Nov;
    dbg.Disagree  = Disagree;
    dbg.weights   = weights;
    dbg.localConf = localConf;
    dbg.globalRel = globalRel;
    dbg.weightedR = weightedR;
end

% ===========================================================
%  局部工具
% ===========================================================

function [R, U, conf] = expertScore(Cand, Anc, eliteFlag, expert, cfg)
% 对单个 expert：算每个候选 x 与所有 anchor a 的 expected-win
% R(x) = mean_{a in elite}[P(x≻a) - P(a≻x)] - mean_{a in diverse}[P(a≻x) - P(x≻a)]/2
% 这里把 elite 视为"好对手"，希望 x 战胜它们；diverse 给较小权重
% 同时返回 ensemble 内方差 U(x) 和 prob margin localConf(x)

    nC = size(Cand, 1);
    nA = size(Anc, 1);
    nets = expert.nets;
    valid = ~cellfun(@isempty, nets);
    nets = nets(valid);
    Knet = numel(nets);

    if nA == 0 || Knet == 0 || nC == 0
        R = zeros(nC, 1); U = ones(nC, 1); conf = zeros(nC, 1);
        return;
    end

    % 构造 pair：每个 candidate 与每个 anchor 双向 [x,a] 和 [a,x]
    % 仅支持 'concat' 形状 (2D)；'diffabs' 在 scoring 路径未实现，自动退化
    D = size(Cand, 2);
    pair_xa = zeros(nC * nA, 2*D);
    pair_ax = zeros(nC * nA, 2*D);
    for i = 1:nC
        rng = (i-1)*nA + (1:nA);
        Xi = repmat(Cand(i, :), nA, 1);
        pair_xa(rng, :) = [Xi, Anc];
        pair_ax(rng, :) = [Anc, Xi];
    end

    % mapminmax apply
    mp = expert.mp_struct;
    try
        Pxa = mapminmax('apply', pair_xa', mp)';
        Pax = mapminmax('apply', pair_ax', mp)';
    catch
        R = zeros(nC, 1); U = ones(nC, 1); conf = zeros(nC, 1);
        return;
    end

    % ensemble 概率：均值与方差
    Knet_v = Knet;
    sumP_xa = zeros(size(Pxa, 1), 3);
    sumP_ax = zeros(size(Pax, 1), 3);
    sumP2_xa = zeros(size(Pxa, 1), 1);

    win_per_net = zeros(size(Pxa, 1), Knet_v);

    for kk = 1:Knet_v
        try
            out_xa = nets{kk}(Pxa')';
            out_ax = nets{kk}(Pax')';
        catch
            Knet_v = Knet_v - 1;
            continue;
        end
        % 修正：钳到 [0,1] 并归一化
        out_xa = max(out_xa, 0);
        out_xa = out_xa ./ max(sum(out_xa, 2), 1e-12);
        out_ax = max(out_ax, 0);
        out_ax = out_ax ./ max(sum(out_ax, 2), 1e-12);

        sumP_xa = sumP_xa + out_xa;
        sumP_ax = sumP_ax + out_ax;

        % 此 net 的 expected-win（仅基于 [x,a]）
        % out(:,1) = P(+1) = P(x≻a)，out(:,3) = P(-1) = P(a≻x)
        win_per_net(:, kk) = out_xa(:, 1) - out_xa(:, 3);
    end

    if Knet_v == 0
        R = zeros(nC, 1); U = ones(nC, 1); conf = zeros(nC, 1);
        return;
    end

    avgP_xa = sumP_xa / Knet_v;
    avgP_ax = sumP_ax / Knet_v;

    % 综合双向概率
    % P_win = 0.5 * P_xa(+1) + 0.5 * P_ax(-1)
    P_xWinA = 0.5 * avgP_xa(:, 1) + 0.5 * avgP_ax(:, 3);
    P_aWinX = 0.5 * avgP_xa(:, 3) + 0.5 * avgP_ax(:, 1);
    margin = P_xWinA - P_aWinX;   % ∈ [-1, 1]

    % 局部置信度：双向概率的 max margin
    confPerPair = max(abs(margin), 0);   % anchors-level

    % 重塑为 nC × nA
    M = reshape(margin, nA, nC)';
    Cmat = reshape(confPerPair, nA, nC)';
    eliteRow = eliteFlag(:)';

    % elite anchors: 全部权重 1
    % diverse anchors: 权重 0.5
    w = ones(1, nA);
    w(~eliteRow) = 0.5;
    wSum = sum(w);
    Rscore = (M * w(:)) / wSum;
    confScore = (Cmat * w(:)) / wSum;

    % U: anchor 上方差 + ensemble 方差混合
    varM = var(M, 0, 2);   % candidate 间 anchor variance
    if Knet_v >= 2
        % ensemble 方差
        varEns = reshape(var(win_per_net, 0, 2), nA, nC);
        varEns = mean(varEns, 1)';
    else
        varEns = zeros(nC, 1);
    end
    Uscore = 0.5 * varM + 0.5 * varEns;
    % 归一化到 [0,1]
    if max(Uscore) > 1e-12
        Uscore = Uscore / max(Uscore);
    end

    R    = Rscore;
    U    = Uscore;
    conf = min(1, confScore);   % already in [0,1]
end

function Nov = archiveNovelty(Cand, Arch, Lower, Upper)
% 在归一化决策空间下，求每个 candidate 到 archive 的最小距离
    if isempty(Arch) || size(Arch, 1) == 0
        Nov = ones(size(Cand, 1), 1);
        return;
    end
    if isempty(Lower) || isempty(Upper)
        % fallback: 用 archive 的 q5/q95
        Lower = quantile(Arch, 0.05, 1);
        Upper = quantile(Arch, 0.95, 1);
    end
    span = max(Upper - Lower, 1e-12);
    Cn = (Cand - Lower) ./ span;
    An = (Arch - Lower) ./ span;
    % 分块 pdist2，避免内存爆炸
    nC = size(Cn, 1);
    Nov = zeros(nC, 1);
    block = 500;
    for s = 1:block:nC
        e = min(nC, s + block - 1);
        Dmat = pdist2(Cn(s:e, :), An);
        Nov(s:e) = min(Dmat, [], 2);
    end
    % 归一化到 [0,1]
    Nov = Nov ./ max(max(Nov), 1e-12);
end

function dbg = emptyDbg(K)
    dbg = struct('R', zeros(0, K), 'U', [], 'U_perExp', zeros(0, K), ...
        'Nov', [], 'Disagree', [], 'weights', zeros(0, K), ...
        'localConf', zeros(0, K), 'globalRel', zeros(1, K), 'weightedR', []);
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
