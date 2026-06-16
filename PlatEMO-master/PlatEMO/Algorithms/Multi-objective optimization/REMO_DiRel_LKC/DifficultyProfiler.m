function [d_score, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy)
% DifficultyProfiler - 目标难度在线排序（模块①）
%
% 功能概述：
%   计算每个优化目标的"建模难度"，选出最易建模的目标子集 S_easy
%   这是 REMO_DiRel 的第一个核心创新：难度感知目标子集选择
%
% 为什么需要难度排序？
%   在超多目标优化中，不同目标的建模难度差异巨大：
%   - 易目标：值域跨度小、单调改进、与其他目标正相关
%   - 难目标：值域跨度大、改进停滞、与其他目标负相关
%   传统方法固定使用所有目标，难目标会拖累易目标的建模准确性
%
% 难度计算公式：
%   d = α × 建模难度 + (1-α) × 冲突难度
%   其中：
%     建模难度 = 0.5 × 目标值跨度分 + 0.5 × 改进停滞分
%     冲突难度 = 1 - Spearman冲突度
%
% 输入：
%   Population - 种群对象，包含所有解的决策变量和目标值
%   H          - 历史记录结构体，存储前几代的难度信息
%   gen        - 当前代数（从1开始）
%   alpha      - 建模难度的权重，默认0.6
%   k_easy     - 易目标子集大小，例如M=10时k_easy=5
%
% 输出：
%   d_score - M×1 向量，各目标的难度分数（越小越易建模）
%   H       - 更新后的历史记录结构体
%   S_easy  - 1×k_easy 向量，易目标子集的索引，例如 [1, 3, 5, 7, 9]
%
% 调用示例：
%   [d_score, H, S_easy] = DifficultyProfiler(Population, H, 1, 0.6, 5)

    % ===================================================================
    % 第一步：提取基本信息
    % ===================================================================
    PopObj = Population.objs;   % N×M 矩阵，N个解的M个目标值
    [~, M] = size(PopObj);      % M = 目标数量
    win_K  = size(H.d_score, 2);  % 滑动窗口大小（默认3代）

    % ===================================================================
    % 第二步：计算轻量建模难度（替代昂贵的Kriging交叉验证）
    % ===================================================================

    % --- 2.1 目标值跨度分 spanScore ---
    % 逻辑：目标值跨度越大 → 值域越分散 → 越难精确建模
    % log1p 是 log(1+x)，用于平滑大跨度值
    bestNow = min(PopObj, [], 1)';   % M×1，当前代各目标的最优值
    spanRaw = (max(PopObj, [], 1) - min(PopObj, [], 1))';  % M×1，各目标值跨度
    spanScore = minmaxNorm(log1p(max(spanRaw, 0)));  % 归一化到 [0,1]

    % --- 2.2 改进停滞分 improveScore ---
    % 逻辑：连续多代没有改进 → 优化陷入困境 → 难建模
    if ~isfield(H, 'best') || numel(H.best) ~= M || all(isnan(H.best))
        % 第一代：没有历史信息，假设都在停滞
        improveScore = ones(M, 1);
    else
        % 计算相对改进率
        % baseImprove 是分母，防止除零
        baseImprove  = max(abs(H.best), 1e-12);
        % relImprove = (上代最优 - 本代最优) / 上代最优
        % max(..., 0) 确保只考虑正向改进（值变小）
        relImprove   = max((H.best - bestNow) ./ baseImprove, 0);
        % 停滞分 = 1 - 归一化的改进率
        % 改进越大 → relImprove越大 → improveScore越小 → 越容易
        improveScore = 1 - minmaxNorm(relImprove);
    end
    H.best = bestNow;  % 更新历史最优值

    % --- 2.3 联合建模难度 ---
    modelDifficulty = 0.5 .* spanScore + 0.5 .* improveScore;

    % ===================================================================
    % 第三步：计算Spearman冲突度
    % ===================================================================
    % ConflictDegree 计算每个目标与其他目标的平均冲突度
    % 冲突度 = mean(1 - |ρ_j,others|)
    % ρ是Spearman秩相关系数，范围[-1,1]
    % |ρ|越接近1 → 高度相关 → 冲突度低（信息冗余）
    % |ρ|越接近0 → 不相关 → 冲突度高
    % ρ为负 → 负相关 → 冲突度最高
    confRaw = ConflictDegree(PopObj);   % M×1 冲突度
    confN   = minmaxNorm(confRaw);       % 归一化到 [0,1]

    % 冲突难度 = 1 - 冲突度
    % 逻辑：与其他目标冲突越大 → 越难建模
    conflictDifficulty = 1 - confN;

    % ===================================================================
    % 第四步：联合难度 + 滑动窗口平滑
    % ===================================================================
    % 联合难度公式：d = α × 建模难度 + (1-α) × 冲突难度
    % alpha=0.6 表示建模难度权重更大
    d_now = alpha .* modelDifficulty + (1-alpha) .* conflictDifficulty;

    % 滑动窗口平滑：取最近 win_K 代的平均值
    % 目的：平滑单代噪声，使难度排序更稳定
    col = mod(gen-1, win_K) + 1;   % 循环索引：1,2,3,1,2,3,...
    H.model(:, col)   = modelDifficulty;
    H.improve(:, col) = improveScore;
    H.conf(:, col)    = confN;
    H.d_score(:, col) = d_now;

    % meanNoNan 是自定义函数，忽略NaN求均值
    d_score = meanNoNan(H.d_score, 2);   % M×1

    % ===================================================================
    % 第五步：选择易目标子集
    % ===================================================================
    % 按难度升序排列（小的在前 = 易的在前）
    [~, ord] = sort(d_score, 'ascend');

    % 取前 k_easy 个作为候选
    S_cand = ord(1:min(k_easy, numel(ord)));

    % RefineEasySubset 做反向冗余检查：
    % 如果候选子集内任意两目标 |ρ| > 0.95（高度冗余），
    % 剔除难度大的那个，补入次易的目标
    S_easy = RefineEasySubset(S_cand, PopObj, d_score, k_easy);
end


%% ========================================================================
%  局部辅助函数
%  ========================================================================

function y = minmaxNorm(x)
% minmaxNorm - Min-Max归一化到 [0, 1]
%
% 公式：y = (x - min) / (max - min)
% 如果所有值相同（max=min），返回全零向量
%
% 输入：x - 任意维度的数值数组
% 输出：y - 归一化后的数组，范围 [0, 1]

    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if span < 1e-12
        % 所有值几乎相同，避免除零
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end


function y = meanNoNan(X, dim)
% meanNoNan - 忽略NaN的均值计算
%
% MATLAB内置的 mean(..., 'omitnan') 功能类似
% 这里手动实现是为了兼容性
%
% 输入：
%   X   - 任意维度的数值数组（可能含NaN）
%   dim - 沿哪个维度求均值（1=列，2=行）
%
% 输出：
%   y   - 忽略NaN后的均值

    mask = ~isnan(X);          % 逻辑数组，非NaN位置为true
    cnt  = sum(mask, dim);     % 每列/行的非NaN个数
    X(~mask) = 0;              % 将NaN替换为0，方便求和
    y = sum(X, dim) ./ max(cnt, 1);  % 求和 / 有效个数
end
