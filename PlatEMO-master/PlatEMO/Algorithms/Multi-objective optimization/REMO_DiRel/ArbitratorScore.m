function scores = ArbitratorScore(Smodel, Candidates)
% ArbitratorScore - 模块③核心：双尺度仲裁打分
%
% 对每个候选解 x：
%   1. 用 net_F 集成（K 个网络）算每个网络的 scalarScore_F(x)
%      → 均值 mu_F, 方差 sigma2_F
%   2. 用 net_S 集成算 scalarScore_S(x)
%      → 均值 mu_S, 方差 sigma2_S
%   3. 在归一化后的 sigma 上应用 inverse-variance weighting：
%      w_F = (1/sigma2_F) / (1/sigma2_F + 1/sigma2_S)
%   4. 冲突分支：当 (mu_F, mu_S) 异号且不确定性差异显著时，让低不确定性模型主导；
%      两边都不确定且异号时，弃权（得分 0）。
%
% 输入：
%   Smodel : struct
%     .X        : 训练样本决策变量
%     .Y_F      : 全目标 Catalog（1/0/-1）
%     .Y_S      : 子目标 Catalog
%     .DualNet  : 含 nets_F, nets_S, mp_struct_F, mp_struct_S
%     .tau_conf : 不确定性阈值（归一化后）
%   Candidates : nCand × D
%
% 输出：
%   scores : nCand × 1 仲裁后的最终得分

    nCand = size(Candidates, 1);
    if nCand == 0
        scores = zeros(0, 1);
        return;
    end

    % ---- 全目标支线 ----
    [mu_F, sigma2_F] = scoreAllByEnsemble( ...
        Smodel.X, Smodel.Y_F, Smodel.DualNet.nets_F, ...
        Smodel.DualNet.mp_struct_F, Candidates);

    % ---- 子目标支线 ----
    [mu_S, sigma2_S] = scoreAllByEnsemble( ...
        Smodel.X, Smodel.Y_S, Smodel.DualNet.nets_S, ...
        Smodel.DualNet.mp_struct_S, Candidates);

    % ---- 不确定性归一化 ----
    s_F = sqrt(max(sigma2_F, 0));
    s_S = sqrt(max(sigma2_S, 0));
    n_F = minmaxNorm(s_F);
    n_S = minmaxNorm(s_S);

    % ---- 得分归一化（用于仲裁权重稳定）----
    tildeS_F = minmaxNormScore(mu_F);   % min-max 到 [0,1]，再线性映射到原 score 范围
    tildeS_S = minmaxNormScore(mu_S);

    % ---- inverse-variance weighting ----
    eps_v   = 1e-6;
    invF    = 1 ./ (s_F.^2 + eps_v);
    invS    = 1 ./ (s_S.^2 + eps_v);
    w_F     = invF ./ (invF + invS);
    w_S     = 1 - w_F;

    % ---- 基础混合得分 ----
    base = w_F .* tildeS_F + w_S .* tildeS_S;

    % ---- 冲突分支微调 ----
    tau = Smodel.tau_conf;
    signF = sign(mu_F);
    signS = sign(mu_S);
    conflict = (signF .* signS) < 0;   % 异号

    % 完全打架（异号且两边都不确定）→ 得分置零（弃权）
    both_uncertain = (n_F > tau) & (n_S > tau);
    abstain = conflict & both_uncertain;
    base(abstain) = 0;

    % 子目标主导冲突（mu_S>0, mu_F<0, sigma_F >> sigma_S）→ 加多样性奖励
    subwin = conflict & (mu_S > 0) & (mu_F < 0) & (n_F > tau) & (n_S <= tau);
    if any(subwin)
        % 多样性奖励 = 候选解在自身集合中的平均距离（粗略近似）
        D_pairs = pdist2(Candidates, Candidates);
        D_pairs(logical(eye(nCand))) = inf;
        novelty = min(D_pairs, [], 2);    % 到最近邻的距离
        novelty = minmaxNorm(novelty);    % [0,1]
        base(subwin) = base(subwin) + 0.5 .* novelty(subwin);
    end

    scores = base;
end

% ============================================================
function [mu, sigma2] = scoreAllByEnsemble(X_train, Y_train, nets, mp_struct, Candidates)
% 对 nets 集成中的每个网络分别算 scalarScore，再取均值和方差
%
% 输出：
%   mu     : nCand × 1 集成均值
%   sigma2 : nCand × 1 集成方差

    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    K = numel(nets_v);
    nCand = size(Candidates, 1);

    if K == 0
        mu = zeros(nCand, 1);
        sigma2 = ones(nCand, 1);   % 全不确定
        return;
    end

    sample_scores = zeros(nCand, K);
    for kk = 1:K
        sample_scores(:, kk) = scoreOneNet(X_train, Y_train, nets_v{kk}, mp_struct, Candidates);
    end

    mu = mean(sample_scores, 2);
    if K >= 2
        sigma2 = var(sample_scores, 0, 2);
    else
        % 单网络无方差信息：用预测置信度的代理作为不确定性
        sigma2 = ones(nCand, 1);
    end
end

% ============================================================
function scoreVec = scoreOneNet(X_train, Y_train, net, mp_struct, Candidates)
% 沿用 REMO/RSurrogateAssistedSelection.model_select 的打分公式
% 对单个网络给出每个候选解的 scalarScore
    C1 = X_train(Y_train == 1, :);
    C2 = X_train(Y_train ~= 1, :);
    n1 = size(C1, 1);
    n2 = size(C2, 1);
    nCand = size(Candidates, 1);

    if nCand == 0 || (n1 + n2) == 0
        scoreVec = zeros(nCand, 1);
        return;
    end

    % 构造所有配对（与 REMO 完全一致的顺序）
    D = size(C1, 2);
    if D == 0
        D = size(C2, 2);
    end
    rowCount = 2 * (n1 + n2) * nCand;
    if rowCount == 0
        scoreVec = zeros(nCand, 1);
        return;
    end
    all_pairs = zeros(rowCount, 2 * D);

    for i = 1:nCand
        base = (i-1) * 2 * (n1 + n2);
        Xi   = repmat(Candidates(i, :), n1, 1);
        if n1 > 0
            all_pairs(base+1 : base+n1, :)              = [C1, Xi];
            all_pairs(base+1+n1 : base+2*n1, :)         = [Xi, C1];
        end
        Xi = repmat(Candidates(i, :), n2, 1);
        if n2 > 0
            all_pairs(base+1+2*n1 : base+2*n1+n2, :)        = [C2, Xi];
            all_pairs(base+1+2*n1+n2 : base+2*n1+2*n2, :)   = [Xi, C2];
        end
    end

    % 归一化 + 网络预测
    try
        TestIn_nor = mapminmax('apply', all_pairs', mp_struct)';
        pre_out = net(TestIn_nor')';     % nRow × 3
    catch
        scoreVec = zeros(nCand, 1);
        return;
    end

    % 累加 scalarScore（与 REMO 一致）
    scoreVec = zeros(nCand, 1);
    for i = 1:nCand
        base = (i-1) * 2 * (n1 + n2);
        Cscore = [0, 0];   % [好类证据, 差类证据]

        if n1 > 0
            pre_C1Xi = sum(pre_out(base+1 : base+n1, :), 1) ./ n1;
            Cscore(1) = Cscore(1) + pre_C1Xi(2) + pre_C1Xi(3);
            Cscore(2) = Cscore(2) + pre_C1Xi(1);

            pre_XiC1 = sum(pre_out(base+1+n1 : base+2*n1, :), 1) ./ n1;
            Cscore(1) = Cscore(1) + pre_XiC1(2) + pre_XiC1(1);
            Cscore(2) = Cscore(2) + pre_XiC1(3);
        end

        if n2 > 0
            pre_C2Xi = sum(pre_out(base+1+2*n1 : base+2*n1+n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_C2Xi(3);
            Cscore(2) = Cscore(2) + pre_C2Xi(2) + pre_C2Xi(1);

            pre_XiC2 = sum(pre_out(base+1+2*n1+n2 : base+2*n1+2*n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_XiC2(1);
            Cscore(2) = Cscore(2) + pre_XiC2(2) + pre_XiC2(3);
        end

        scoreVec(i) = Cscore(1) - Cscore(2);
    end
end

% ============================================================
function y = minmaxNorm(x)
% 安全 min-max 归一化到 [0,1]
    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if span < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end

% ============================================================
function y = minmaxNormScore(x)
% 把 scalarScore 范围对齐：先归一化到 [0,1]，再线性映射到与 REMO 一致的 [0,4]
% （因为 REMO 用 score>3.9 做阈值筛选，保持兼容）
    y = minmaxNorm(x) .* 4;
end
