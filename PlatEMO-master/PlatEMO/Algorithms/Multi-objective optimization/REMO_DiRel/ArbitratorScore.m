function scores = ArbitratorScore(Smodel, Candidates)
%ArbitratorScore - Dual-scale inverse-variance arbitration.
%
% Scores each candidate with the full-objective and easy-subset relation
% ensembles, then combines them with per-candidate inverse-variance weights.
% Candidate scoring is anchor-budgeted: each class contributes at most
% Smodel.anchorMax representatives.

    nCand = size(Candidates, 1);
    if nCand == 0
        scores = zeros(0, 1);
        return;
    end

    [mu_F, sigma2_F] = scoreAllByEnsemble( ...
        Smodel.X, Smodel.Y_F, Smodel.DualNet.nets_F, ...
        Smodel.DualNet.mp_struct_F, Candidates, Smodel.anchorMax);

    [mu_S, sigma2_S] = scoreAllByEnsemble( ...
        Smodel.X, Smodel.Y_S, Smodel.DualNet.nets_S, ...
        Smodel.DualNet.mp_struct_S, Candidates, Smodel.anchorMax);

    s_F = sqrt(max(sigma2_F, 0));
    s_S = sqrt(max(sigma2_S, 0));
    n_F = minmaxNorm(s_F);
    n_S = minmaxNorm(s_S);

    tildeS_F = minmaxNormScore(mu_F);
    tildeS_S = minmaxNormScore(mu_S);

    eps_v = 1e-6;
    invF  = 1 ./ (s_F.^2 + eps_v);
    invS  = 1 ./ (s_S.^2 + eps_v);
    w_F   = invF ./ (invF + invS);
    w_S   = 1 - w_F;

    base = w_F .* tildeS_F + w_S .* tildeS_S;

    tau      = Smodel.tau_conf;
    conflict = (sign(mu_F) .* sign(mu_S)) < 0;
    abstain  = conflict & (n_F > tau) & (n_S > tau);
    base(abstain) = 0;

    subwin = conflict & (mu_S > 0) & (mu_F < 0) & (n_F > tau) & (n_S <= tau);
    if any(subwin)
        D_pairs = pdist2(Candidates, Candidates);
        D_pairs(logical(eye(nCand))) = inf;
        novelty = min(D_pairs, [], 2);
        novelty(~isfinite(novelty)) = 0;
        novelty = minmaxNorm(novelty);
        base(subwin) = base(subwin) + 0.5 .* novelty(subwin);
    end

    scores = base;
end

function [mu, sigma2] = scoreAllByEnsemble(X_train, Y_train, nets, mp_struct, Candidates, anchorMax)
    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    K = numel(nets_v);
    nCand = size(Candidates, 1);

    if K == 0
        mu = zeros(nCand, 1);
        sigma2 = ones(nCand, 1);
        return;
    end

    C1 = selectAnchors(X_train(Y_train == 1, :), anchorMax);
    C2 = selectAnchors(X_train(Y_train ~= 1, :), anchorMax);

    sample_scores = zeros(nCand, K);
    for kk = 1:K
        sample_scores(:, kk) = scoreOneNet(C1, C2, nets_v{kk}, mp_struct, Candidates);
    end

    mu = mean(sample_scores, 2);
    if K >= 2
        sigma2 = var(sample_scores, 0, 2);
    else
        sigma2 = ones(nCand, 1);
    end
end

function X = selectAnchors(X, anchorMax)
    n = size(X, 1);
    if n <= anchorMax
        return;
    end
    idx = unique(round(linspace(1, n, anchorMax)), 'stable');
    X = X(idx, :);
end

function scoreVec = scoreOneNet(C1, C2, net, mp_struct, Candidates)
    n1 = size(C1, 1);
    n2 = size(C2, 1);
    nCand = size(Candidates, 1);

    if nCand == 0 || (n1 + n2) == 0
        scoreVec = zeros(nCand, 1);
        return;
    end

    D = size(Candidates, 2);
    rowCount = 2 * (n1 + n2) * nCand;
    all_pairs = zeros(rowCount, 2 * D);

    for i = 1:nCand
        base = (i-1) * 2 * (n1 + n2);
        if n1 > 0
            Xi = repmat(Candidates(i, :), n1, 1);
            all_pairs(base+1 : base+n1, :)      = [C1, Xi];
            all_pairs(base+1+n1 : base+2*n1, :) = [Xi, C1];
        end
        if n2 > 0
            Xi = repmat(Candidates(i, :), n2, 1);
            p0 = base + 2*n1;
            all_pairs(p0+1 : p0+n2, :)      = [C2, Xi];
            all_pairs(p0+1+n2 : p0+2*n2, :) = [Xi, C2];
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
            p0 = base + 2*n1;
            pre_C2Xi = sum(pre_out(p0+1 : p0+n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_C2Xi(3);
            Cscore(2) = Cscore(2) + pre_C2Xi(2) + pre_C2Xi(1);

            pre_XiC2 = sum(pre_out(p0+1+n2 : p0+2*n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_XiC2(1);
            Cscore(2) = Cscore(2) + pre_XiC2(2) + pre_XiC2(3);
        end

        scoreVec(i) = Cscore(1) - Cscore(2);
    end
end

function y = minmaxNorm(x)
    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if span < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end

function y = minmaxNormScore(x)
    y = minmaxNorm(x) .* 4;
end
