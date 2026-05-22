function diag = compute_obj_separation(PopObj, Catalog, gen)
% compute_obj_separation - 计算每个目标上好/坏解的分离度。
%
% 输入：
%   PopObj  - N x M 目标值矩阵
%   Catalog - N x 1 分类标签（1=好，~=1=坏）
%   gen     - 当前代数
%
% 输出：
%   diag - 结构体，包含每代的诊断信息

    [N, M] = size(PopObj);
    good   = (Catalog == 1);
    bad    = ~good;
    n_good = sum(good);
    n_bad  = sum(bad);

    diag.gen       = gen;
    diag.M         = M;
    diag.N         = N;
    diag.n_good    = n_good;
    diag.n_bad     = n_bad;
    diag.good_ratio = n_good / N;

    %% Per-objective separation gap (Cohen's d)
    gap   = zeros(1, M);
    mu_g  = zeros(1, M);
    mu_b  = zeros(1, M);
    std_g = zeros(1, M);
    std_b = zeros(1, M);
    range_m = zeros(1, M);

    for m = 1:M
        vals_g = PopObj(good, m);
        vals_b = PopObj(bad, m);

        mu_g(m)  = mean(vals_g);
        mu_b(m)  = mean(vals_b);
        std_g(m) = std(vals_g);
        std_b(m) = std(vals_b);

        pooled_std = sqrt((std_g(m)^2 + std_b(m)^2) / 2);
        gap(m) = abs(mu_g(m) - mu_b(m)) / (pooled_std + eps);

        range_m(m) = max(PopObj(:, m)) - min(PopObj(:, m));
    end

    diag.gap     = gap;
    diag.mu_good = mu_g;
    diag.mu_bad  = mu_b;
    diag.std_good = std_g;
    diag.std_bad  = std_b;
    diag.range    = range_m;

    %% Coefficient of variation of gap (how uneven across objectives)
    if mean(gap) > eps
        diag.gap_cv = std(gap) / mean(gap);
    else
        diag.gap_cv = NaN;
    end

    %% Per-objective dominance contribution
    % For each objective, compute how often good solutions beat bad solutions
    dom_rate = zeros(1, M);
    for m = 1:M
        vals_g = PopObj(good, m);
        vals_b = PopObj(bad, m);
        if isempty(vals_g) || isempty(vals_b)
            dom_rate(m) = NaN;
            continue;
        end
        % Pairwise: fraction of (good,bad) pairs where good < bad on obj m
        comp = bsxfun(@lt, vals_g(:)', vals_b(:));
        dom_rate(m) = mean(comp(:));
    end
    diag.dom_rate = dom_rate;

    %% Ideal and nadir point distance
    diag.ideal_dist = min(PopObj, [], 1);
    diag.nadir_dist = max(PopObj, [], 1);
end
