function [DiffState, H] = DifficultyProfilerV2(Population, Archive, H, gen, cfg)
% DifficultyProfilerV2 - 多分量目标难度估计
%
% 与旧 DifficultyProfiler 的根本区别：
%   旧版：difficulty = 0.6*(0.5*span + 0.5*improve) + 0.4*(1 - |rho|_mean)
%         问题：span 占比 30%, conflict 由 |rho| 推得，强负相关被压平
%   本版：5 分量加权
%         D_prog  停滞进展（基于 archive 的 q10/q20 改进率）
%         D_learn 可学习性（KrigingNRMSE 低频运行，可关闭）
%         D_conf  冲突（仅来自 max(0, -rho)，强负相关 → 高冲突）
%         D_sens  关系敏感性（删除目标 j 前后 pair 标签翻转率，轻量近似）
%         D_span  鲁棒跨度（q90-q10，小权重）
%         + EMA 平滑（保留历史趋势）
%
% 输入：
%   Population - 当前种群 (PlatEMO SOLUTION 数组)
%   Archive    - 已评估所有解
%   H          - 历史记录结构体，字段：
%       .best_q10  M×1 之前最优 q10
%       .best_min  M×1 之前最优 min
%       .D_total_prev  M×1 上一代 difficulty（用于 EMA）
%       .gen       上次更新代数
%   gen        - 当前代数
%   cfg        - 配置：
%       .w_prog   默认 0.35
%       .w_learn  默认 0.25 （若 doKriging=false 则会重新归一化）
%       .w_conf   默认 0.20
%       .w_sens   默认 0.15
%       .w_span   默认 0.05
%       .emaAlpha EMA 平滑因子，默认 0.5（新值占比）
%       .doKriging 是否本代执行 Kriging NRMSE
%       .nSubArch  Kriging 子采样大小，默认 60
%
% 输出：
%   DiffState - 结构体：
%       .total   M×1 综合难度（EMA 平滑后）
%       .raw     M×1 综合难度（本代未平滑）
%       .Dprog, Dlearn, Dconf, Dsens, Dspan : M×1 各分量
%       .rho     M×M Spearman 相关矩阵
%   H         - 更新后的历史记录

    if nargin < 5 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'w_prog',   0.35);
    cfg = setIfMissing(cfg, 'w_learn',  0.25);
    cfg = setIfMissing(cfg, 'w_conf',   0.20);
    cfg = setIfMissing(cfg, 'w_sens',   0.15);
    cfg = setIfMissing(cfg, 'w_span',   0.05);
    cfg = setIfMissing(cfg, 'emaAlpha', 0.5);
    cfg = setIfMissing(cfg, 'doKriging', false);
    cfg = setIfMissing(cfg, 'nSubArch',  60);

    PopObj  = Population.objs;
    ArchObj = Archive.objs;
    ArchDec = Archive.decs;
    [N, M] = size(PopObj);

    % ============================================================
    % 1. D_prog: 用 archive 的 q10 改进率
    % ============================================================
    q10_now = quantile(ArchObj, 0.10, 1)';   % M×1
    min_now = min(ArchObj, [], 1)';

    if isfield(H, 'best_q10') && numel(H.best_q10) == M && ~all(isnan(H.best_q10))
        base = max(abs(H.best_q10), 1e-12);
        relImp = max((H.best_q10 - q10_now) ./ base, 0);
        Dprog = 1 - minmaxNorm(relImp);     % 改进越大 → Dprog 越小
    else
        Dprog = ones(M, 1) * 0.5;
    end
    H.best_q10 = q10_now;
    H.best_min = min_now;

    % ============================================================
    % 2. D_learn: 可学习性（Kriging NRMSE，低频）
    % ============================================================
    if cfg.doKriging && size(ArchObj, 1) >= 15
        Dlearn = zeros(M, 1);
        nSub = min(cfg.nSubArch, size(ArchDec, 1));
        idx = randperm(size(ArchDec, 1), nSub);
        Xsub = ArchDec(idx, :);
        for j = 1:M
            try
                yj = ArchObj(idx, j);
                nrmse_j = KrigingNRMSE(Xsub, yj);
                Dlearn(j) = nrmse_j;
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

    % ============================================================
    % 3. D_conf: 冲突难度 —— 仅来自 max(0, -rho)
    % ============================================================
    if N >= 3 && M >= 2
        rho = corr(PopObj, 'type', 'Spearman');
        rho(isnan(rho)) = 0;
    else
        rho = eye(M);
    end

    Dconf = zeros(M, 1);
    for j = 1:M
        others = setdiff(1:M, j);
        if isempty(others)
            Dconf(j) = 0; continue;
        end
        negPart = max(0, -rho(j, others));   % 负相关强度
        Dconf(j) = mean(negPart);
    end
    Dconf = minmaxNorm(Dconf);

    % ============================================================
    % 4. D_sens: 关系敏感性（轻量近似）
    %    对一组随机 pair 计算 full Pareto 标签 vs 去掉目标 j 后的 Pareto 标签
    %    翻转率越高，目标 j 越关键。
    % ============================================================
    Dsens = zeros(M, 1);
    if M >= 3 && N >= 4
        nPair = min(300, N*(N-1));
        ia = randi(N, nPair, 1);
        ib = randi(N, nPair, 1);
        mask = ia ~= ib;
        ia = ia(mask); ib = ib(mask);

        Fa = PopObj(ia, :); Fb = PopObj(ib, :);
        % full label
        y_full = paretoLabel(Fa, Fb);

        for j = 1:M
            cols = [1:j-1, j+1:M];
            y_j = paretoLabel(Fa(:, cols), Fb(:, cols));
            % 翻转：full ≠ subset 的比例
            Dsens(j) = mean(y_full ~= y_j);
        end
        Dsens = minmaxNorm(Dsens);
    else
        Dsens = ones(M, 1) * 0.5;
    end

    % ============================================================
    % 5. D_span: 鲁棒跨度（小权重）
    % ============================================================
    spanRaw = (quantile(ArchObj, 0.90, 1) - quantile(ArchObj, 0.10, 1))';
    Dspan = minmaxNorm(log1p(max(spanRaw, 0)));

    % ============================================================
    % 6. 合成并 EMA 平滑
    % ============================================================
    w = [cfg.w_prog, cfg.w_learn, cfg.w_conf, cfg.w_sens, cfg.w_span];
    if ~cfg.doKriging && ~isfield(H, 'Dlearn_last')
        % 完全没 Dlearn 时把权重转移到 prog & sens
        w(1) = w(1) + w(2)*0.6;
        w(4) = w(4) + w(2)*0.4;
        w(2) = 0;
    end
    w = w / sum(w);

    Draw = w(1)*Dprog + w(2)*Dlearn + w(3)*Dconf + w(4)*Dsens + w(5)*Dspan;

    if isfield(H, 'D_total_prev') && numel(H.D_total_prev) == M && ~all(isnan(H.D_total_prev))
        Dtotal = cfg.emaAlpha * Draw + (1 - cfg.emaAlpha) * H.D_total_prev;
    else
        Dtotal = Draw;
    end
    H.D_total_prev = Dtotal;
    H.gen = gen;

    % ============================================================
    % 输出
    % ============================================================
    DiffState = struct();
    DiffState.total  = Dtotal;
    DiffState.raw    = Draw;
    DiffState.Dprog  = Dprog;
    DiffState.Dlearn = Dlearn;
    DiffState.Dconf  = Dconf;
    DiffState.Dsens  = Dsens;
    DiffState.Dspan  = Dspan;
    DiffState.rho    = rho;
    DiffState.weights = w;
end

% ===========================================================
function y = paretoLabel(Fa, Fb)
% Pareto dominance label for pair: +1 if a dominates b, -1 if b dominates a, 0 otherwise
    leqAll = all(Fa <= Fb, 2);  ltAny = any(Fa < Fb, 2);
    geqAll = all(Fa >= Fb, 2);  gtAny = any(Fa > Fb, 2);
    y = zeros(size(Fa, 1), 1);
    y(leqAll & ltAny) = +1;
    y(geqAll & gtAny) = -1;
end

function y = minmaxNorm(x)
    xmin = min(x); xmax = max(x); span = xmax - xmin;
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
