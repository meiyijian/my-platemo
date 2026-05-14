function [d_score, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy)
% DifficultyProfiler - 模块①：目标难度量化器
%
% 综合 GP 留一 NRMSE（可建模度）与 Spearman 冲突度，给每个目标输出一个 [0,1] 难度分。
% 用 win_K=size(H,2) 代滑动平均抑制单代波动，输出最易的 k_easy 个目标索引。
%
% 输入：
%   Population : PlatEMO 种群对象
%   H          : 难度历史结构体，含 d_score / nrmse / conf (M × win_K)
%   gen        : 当前代数（用于循环填充滑动窗口）
%   alpha      : NRMSE 项的权重，(1-alpha) 给冲突度项
%   k_easy     : 易目标子集大小
%
% 输出：
%   d_score : M × 1 当前代的滑动平均难度分（越小越易）
%   H       : 更新后的难度历史
%   S_easy  : 1 × k_easy 易目标索引（已做反向冗余检查）

    PopDec = Population.decs;
    PopObj = Population.objs;
    [N, M] = size(PopObj);
    win_K  = size(H.d_score, 2);

    % ---- 指标 1：每个目标的 K-fold GP NRMSE ----
    nrmse_raw = zeros(M,1);
    for j = 1:M
        nrmse_raw(j) = KrigingNRMSE(PopDec, PopObj(:,j));
    end

    % ---- 指标 2：每个目标的冲突度（Spearman 冲突） ----
    conf_raw = ConflictDegree(PopObj);   % M × 1, 越大越冲突

    % ---- 两者各自 min-max 归一化到 [0,1] ----
    nrmse_n = minmaxNorm(nrmse_raw);     % 越大越难建模
    conf_n  = minmaxNorm(conf_raw);      % 越大越冲突 → 越"独立"（贡献信息）

    % ---- 当代难度（高 NRMSE 难、低冲突度难） ----
    d_now = alpha .* nrmse_n + (1-alpha) .* (1 - conf_n);

    % ---- 更新滑动窗口（按 gen mod win_K 循环写入） ----
    col = mod(gen-1, win_K) + 1;
    H.nrmse(:, col)   = nrmse_n;
    H.conf(:, col)    = conf_n;
    H.d_score(:, col) = d_now;

    % ---- 滑动平均（忽略 NaN） ----
    d_score = nanmean(H.d_score, 2);

    % ---- 选取最易的 k_easy 个目标 + 反向冗余检查 ----
    [~, ord] = sort(d_score, 'ascend');
    S_cand   = ord(1:k_easy);
    S_easy   = RefineEasySubset(S_cand, PopObj, d_score, k_easy);
end

function y = minmaxNorm(x)
% 安全 min-max 归一化：所有值相同时返回 0 向量
    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if span < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end
