function [scores, info] = ArbitratorScore_LKC(Smodel, Candidates)
% ArbitratorScore_LKC - Full-first arbitration with LKC subspace tie-break.
%
% The sub-network predicts relations only in the easy aggregated objective
% space.  It is used only when the full-objective network is uncertain.

    nCand = size(Candidates, 1);
    info = emptyInfo(nCand);
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

    marginF = getField(Smodel, 'margin_F', 0.15);
    marginS = getField(Smodel, 'margin_S', 0.15);
    uncF    = getField(Smodel, 'uncertainty_F', Smodel.tau_conf.^2);
    uncS    = getField(Smodel, 'uncertainty_S', Smodel.tau_conf.^2);
    tieW    = getField(Smodel, 'tieWeight', 0.5);
    beta    = getField(Smodel, 'betaUncertainty', 0.25);
    lambda  = getField(Smodel, 'lambdaDisagreement', 0.75);
    gamma   = getField(Smodel, 'gammaNovelty', 0.25);

    highF = abs(mu_F) >= marginF & sigma2_F <= uncF;
    highS = abs(mu_S) >= marginS & sigma2_S <= uncS;
    fullUncertain = ~highF;
    triggerSub = fullUncertain & highS;
    disagreement = highS & (sign(mu_F) .* sign(mu_S) < 0);

    baseFull = 2 + 2 .* tanh(mu_F);
    subPreference = max(0, tanh(mu_S));
    uncertaintyPenalty = minmaxNorm(sqrt(max(sigma2_F, 0)));
    novelty = archiveNovelty(Smodel.X, Candidates);

    scores = baseFull ...
           + tieW .* double(triggerSub) .* subPreference ...
           - beta .* uncertaintyPenalty ...
           - lambda .* double(disagreement) ...
           + gamma .* novelty;

    info.mu_F = mu_F;
    info.sigma2_F = sigma2_F;
    info.confidence_F = abs(mu_F) ./ (sqrt(max(sigma2_F, 0)) + 1e-6);
    info.mu_S = mu_S;
    info.sigma2_S = sigma2_S;
    info.confidence_S = abs(mu_S) ./ (sqrt(max(sigma2_S, 0)) + 1e-6);
    info.fullUncertain = fullUncertain;
    info.subTriggered = triggerSub;
    info.disagreement = disagreement;
    info.fullDominated = highF;
    info.subTieBreakDominated = triggerSub & subPreference > 0;
    info.fullUncertainRatio = mean(fullUncertain);
    info.subTriggeredRatio = mean(triggerSub);
    info.disagreementRatio = mean(disagreement);
    info.fullDominatedRatio = mean(info.fullDominated);
    info.subTieBreakDominatedRatio = mean(info.subTieBreakDominated);
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
        base = (i - 1) * 2 * (n1 + n2);
        if n1 > 0
            Xi = repmat(Candidates(i, :), n1, 1);
            all_pairs(base+1:base+n1, :) = [C1, Xi];
            all_pairs(base+1+n1:base+2*n1, :) = [Xi, C1];
        end
        if n2 > 0
            Xi = repmat(Candidates(i, :), n2, 1);
            p0 = base + 2 * n1;
            all_pairs(p0+1:p0+n2, :) = [C2, Xi];
            all_pairs(p0+1+n2:p0+2*n2, :) = [Xi, C2];
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
        base = (i - 1) * 2 * (n1 + n2);
        Cscore = [0, 0];

        if n1 > 0
            pre_C1Xi = sum(pre_out(base+1:base+n1, :), 1) ./ n1;
            Cscore(1) = Cscore(1) + pre_C1Xi(2) + pre_C1Xi(3);
            Cscore(2) = Cscore(2) + pre_C1Xi(1);

            pre_XiC1 = sum(pre_out(base+1+n1:base+2*n1, :), 1) ./ n1;
            Cscore(1) = Cscore(1) + pre_XiC1(2) + pre_XiC1(1);
            Cscore(2) = Cscore(2) + pre_XiC1(3);
        end

        if n2 > 0
            p0 = base + 2 * n1;
            pre_C2Xi = sum(pre_out(p0+1:p0+n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_C2Xi(3);
            Cscore(2) = Cscore(2) + pre_C2Xi(2) + pre_C2Xi(1);

            pre_XiC2 = sum(pre_out(p0+1+n2:p0+2*n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_XiC2(1);
            Cscore(2) = Cscore(2) + pre_XiC2(2) + pre_XiC2(3);
        end

        scoreVec(i) = Cscore(1) - Cscore(2);
    end
end


function novelty = archiveNovelty(X_train, Candidates)
    nCand = size(Candidates, 1);
    novelty = zeros(nCand, 1);
    if isempty(X_train) || isempty(Candidates)
        return;
    end
    for i = 1:nCand
        diff = bsxfun(@minus, X_train, Candidates(i, :));
        novelty(i) = min(sqrt(sum(diff.^2, 2)));
    end
    novelty = minmaxNorm(novelty);
end


function y = minmaxNorm(x)
    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if isempty(x) || span < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end


function value = getField(S, name, defaultValue)
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        value = S.(name);
    else
        value = defaultValue;
    end
end


function info = emptyInfo(nCand)
    z = zeros(nCand, 1);
    info = struct();
    info.mu_F = z;
    info.sigma2_F = z;
    info.confidence_F = z;
    info.mu_S = z;
    info.sigma2_S = z;
    info.confidence_S = z;
    info.fullUncertain = false(nCand, 1);
    info.subTriggered = false(nCand, 1);
    info.disagreement = false(nCand, 1);
    info.fullDominated = false(nCand, 1);
    info.subTieBreakDominated = false(nCand, 1);
    info.fullUncertainRatio = 0;
    info.subTriggeredRatio = 0;
    info.disagreementRatio = 0;
    info.fullDominatedRatio = 0;
    info.subTieBreakDominatedRatio = 0;
end
