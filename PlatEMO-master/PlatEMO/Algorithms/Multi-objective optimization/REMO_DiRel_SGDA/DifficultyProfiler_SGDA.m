function [DiffState, H] = DifficultyProfiler_SGDA(Population, Archive, H, gen, cfg)
% DifficultyProfiler_SGDA - Lightweight multi-component objective difficulty.
%
% Smaller values mean easier objectives. The profiler follows the V2 idea:
% progress stagnation, optional learnability memory, negative-correlation
% conflict, relation sensitivity, and robust objective span.

    if nargin < 5 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'w_prog', 0.35);
    cfg = setIfMissing(cfg, 'w_learn', 0.25);
    cfg = setIfMissing(cfg, 'w_conf', 0.20);
    cfg = setIfMissing(cfg, 'w_sens', 0.15);
    cfg = setIfMissing(cfg, 'w_span', 0.05);
    cfg = setIfMissing(cfg, 'emaAlpha', 0.5);
    cfg = setIfMissing(cfg, 'doKriging', false);
    cfg = setIfMissing(cfg, 'nSubArch', 60);

    PopObj  = Population.objs;
    ArchObj = Archive.objs;
    ArchDec = Archive.decs;
    [N, M] = size(PopObj);

    q10_now = quantile(ArchObj, 0.10, 1)';
    min_now = min(ArchObj, [], 1)';
    if isfield(H, 'best_q10') && numel(H.best_q10) == M && ~all(isnan(H.best_q10))
        base = max(abs(H.best_q10), 1e-12);
        relImp = max((H.best_q10 - q10_now) ./ base, 0);
        Dprog = 1 - minmaxNorm(relImp);
    else
        Dprog = ones(M, 1) * 0.5;
    end
    H.best_q10 = q10_now;
    H.best_min = min_now;

    if cfg.doKriging && size(ArchObj, 1) >= 15 && exist('KrigingNRMSE', 'file') == 2
        Dlearn = zeros(M, 1);
        nSub = min(cfg.nSubArch, size(ArchDec, 1));
        idx = randperm(size(ArchDec, 1), nSub);
        Xsub = ArchDec(idx, :);
        for j = 1:M
            try
                Dlearn(j) = KrigingNRMSE(Xsub, ArchObj(idx, j));
            catch
                Dlearn(j) = 0.5;
            end
        end
        Dlearn = minmaxNorm(Dlearn);
        H.Dlearn_last = Dlearn;
    elseif isfield(H, 'Dlearn_last') && numel(H.Dlearn_last) == M
        Dlearn = H.Dlearn_last;
    else
        Dlearn = ones(M, 1) * 0.5;
    end

    if N >= 3 && M >= 2
        try
            rho = corr(PopObj, 'type', 'Spearman', 'rows', 'pairwise');
        catch
            rho = corrcoef(PopObj);
        end
        rho(isnan(rho)) = 0;
    else
        rho = eye(M);
    end

    Dconf = zeros(M, 1);
    for j = 1:M
        others = setdiff(1:M, j);
        if isempty(others)
            Dconf(j) = 0;
        else
            Dconf(j) = mean(max(0, -rho(j, others)));
        end
    end
    Dconf = minmaxNorm(Dconf);

    Dsens = relationSensitivity(PopObj);

    spanRaw = (quantile(ArchObj, 0.90, 1) - quantile(ArchObj, 0.10, 1))';
    Dspan = minmaxNorm(log1p(max(spanRaw, 0)));

    w = [cfg.w_prog, cfg.w_learn, cfg.w_conf, cfg.w_sens, cfg.w_span];
    if ~cfg.doKriging && ~isfield(H, 'Dlearn_last')
        w(1) = w(1) + 0.6*w(2);
        w(4) = w(4) + 0.4*w(2);
        w(2) = 0;
    end
    w = w ./ max(sum(w), 1e-12);

    Draw = w(1)*Dprog + w(2)*Dlearn + w(3)*Dconf + w(4)*Dsens + w(5)*Dspan;
    if isfield(H, 'D_total_prev') && numel(H.D_total_prev) == M && ~all(isnan(H.D_total_prev))
        Dtotal = cfg.emaAlpha * Draw + (1 - cfg.emaAlpha) * H.D_total_prev;
    else
        Dtotal = Draw;
    end
    H.D_total_prev = Dtotal;
    H.gen = gen;

    DiffState = struct();
    DiffState.total = Dtotal;
    DiffState.raw = Draw;
    DiffState.Dprog = Dprog;
    DiffState.Dlearn = Dlearn;
    DiffState.Dconf = Dconf;
    DiffState.Dsens = Dsens;
    DiffState.Dspan = Dspan;
    DiffState.rho = rho;
    DiffState.weights = w;
end

function Dsens = relationSensitivity(PopObj)
    [N, M] = size(PopObj);
    if M < 3 || N < 4
        Dsens = ones(M, 1) * 0.5;
        return;
    end
    nPair = min(300, N*(N-1));
    ia = randi(N, nPair, 1);
    ib = randi(N, nPair, 1);
    keep = ia ~= ib;
    ia = ia(keep);
    ib = ib(keep);
    Fa = PopObj(ia, :);
    Fb = PopObj(ib, :);
    yFull = paretoLabel(Fa, Fb);
    Dsens = zeros(M, 1);
    for j = 1:M
        cols = [1:j-1, j+1:M];
        ySub = paretoLabel(Fa(:, cols), Fb(:, cols));
        Dsens(j) = mean(yFull ~= ySub);
    end
    Dsens = minmaxNorm(Dsens);
end

function y = paretoLabel(Fa, Fb)
    leqAll = all(Fa <= Fb, 2);
    ltAny  = any(Fa <  Fb, 2);
    geqAll = all(Fa >= Fb, 2);
    gtAny  = any(Fa >  Fb, 2);
    y = zeros(size(Fa, 1), 1);
    y(leqAll & ltAny) = +1;
    y(geqAll & gtAny) = -1;
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

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
