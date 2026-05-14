function scores = ArbitratorScore_FullArb(Smodel, Candidates)
% ArbitratorScore_FullArb - 消融变体核心：全局 stateWeights 仲裁
%
% 与 ArbitratorScore 的唯一差异：
%   原版 w_F(x) 是逐候选解的（依赖该候选解上的 sigma_F^2(x) / sigma_S^2(x)）
%   此版 w_F 是全局标量（用整批候选 sigma^2 的均值）
%
% 模仿 SRMaO 的 stateWeights 思路。冲突分支保留。

    nCand = size(Candidates, 1);
    if nCand == 0
        scores = zeros(0, 1);
        return;
    end

    [mu_F, sigma2_F] = scoreAllByEnsembleLocal( ...
        Smodel.X, Smodel.Y_F, Smodel.DualNet.nets_F, ...
        Smodel.DualNet.mp_struct_F, Candidates);
    [mu_S, sigma2_S] = scoreAllByEnsembleLocal( ...
        Smodel.X, Smodel.Y_S, Smodel.DualNet.nets_S, ...
        Smodel.DualNet.mp_struct_S, Candidates);

    s_F = sqrt(max(sigma2_F, 0));
    s_S = sqrt(max(sigma2_S, 0));
    n_F = minmaxNormLocal(s_F);
    n_S = minmaxNormLocal(s_S);

    tildeS_F = minmaxNormLocal(mu_F) .* 4;
    tildeS_S = minmaxNormLocal(mu_S) .* 4;

    % ---- 消融差异：全局标量权重 ----
    eps_v = 1e-6;
    mean_sF2 = mean(s_F.^2) + eps_v;
    mean_sS2 = mean(s_S.^2) + eps_v;
    w_F_global = (1/mean_sF2) / (1/mean_sF2 + 1/mean_sS2);
    w_S_global = 1 - w_F_global;
    base = w_F_global .* tildeS_F + w_S_global .* tildeS_S;

    tau = Smodel.tau_conf;
    signF = sign(mu_F);
    signS = sign(mu_S);
    conflict = (signF .* signS) < 0;
    both_uncertain = (n_F > tau) & (n_S > tau);
    abstain = conflict & both_uncertain;
    base(abstain) = 0;

    scores = base;
end

function [mu, sigma2] = scoreAllByEnsembleLocal(X_train, Y_train, nets, mp_struct, Candidates)
    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    K = numel(nets_v);
    nCand = size(Candidates, 1);
    if K == 0
        mu = zeros(nCand, 1);
        sigma2 = ones(nCand, 1);
        return;
    end
    sample_scores = zeros(nCand, K);
    for kk = 1:K
        sample_scores(:, kk) = scoreOneNetLocal(X_train, Y_train, nets_v{kk}, mp_struct, Candidates);
    end
    mu = mean(sample_scores, 2);
    if K >= 2
        sigma2 = var(sample_scores, 0, 2);
    else
        sigma2 = ones(nCand, 1);
    end
end

function scoreVec = scoreOneNetLocal(X_train, Y_train, net, mp_struct, Candidates)
    C1 = X_train(Y_train == 1, :);
    C2 = X_train(Y_train ~= 1, :);
    n1 = size(C1, 1);
    n2 = size(C2, 1);
    nCand = size(Candidates, 1);
    if nCand == 0 || (n1 + n2) == 0
        scoreVec = zeros(nCand, 1);
        return;
    end
    D = max(size(C1, 2), size(C2, 2));
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
            all_pairs(base+1 : base+n1, :)          = [C1, Xi];
            all_pairs(base+1+n1 : base+2*n1, :)     = [Xi, C1];
        end
        Xi = repmat(Candidates(i, :), n2, 1);
        if n2 > 0
            all_pairs(base+1+2*n1 : base+2*n1+n2, :)      = [C2, Xi];
            all_pairs(base+1+2*n1+n2 : base+2*n1+2*n2, :) = [Xi, C2];
        end
    end
    try
        TestIn_nor = mapminmax('apply', all_pairs', mp_struct)';
        pre_out = net(TestIn_nor')';
    catch
        scoreVec = zeros(nCand, 1);
        return;
    end
    scoreVec = zeros(nCand, 1);
    for i = 1:nCand
        base = (i-1) * 2 * (n1 + n2);
        Cscore = [0, 0];
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

function y = minmaxNormLocal(x)
    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if span < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end
