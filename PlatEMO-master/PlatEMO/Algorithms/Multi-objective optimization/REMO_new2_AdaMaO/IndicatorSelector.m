function [Fitness, flag, Lp] = IndicatorSelector(Population, indicator, Lp_prev)
% IndicatorSelector - PIEA 风格的指标轮盘选择 + Lp 形状自适应
%
% 本函数实现了 PIEA（2024）的指标选择思想：
%   使用三种性能指标来评估种群，根据历史表现动态调整选择概率
%
% 三种指标：
%   1. SDE（移位密度估计）：
%      - 适合分布均匀的前沿
%      - 当解相互聚集时自动退化为 Minkowski 距离
%
%   2. I_epsilon+（加性 epsilon 指标）：
%      - 衡量"解 i 转换到解 j 至少需要在某一目标上恶化多少"
%      - 对超多目标场景下"互不支配但仍有强弱"的解有较好区分度
%
%   3. Minkowski（Minkowski 距离至理想点）：
%      - 当 PF 形状被 Lp 准确估计时，能将 PF 上的解映射到等高线上
%      - Lp=1：曼哈顿距离（适合 linear PF）
%      - Lp=2：欧氏距离（适合凸 PF）
%      - Lp<1：偏向凹 PF
%
% 轮盘选择机制：
%   每个指标被选中的概率 Pw 基于历史表现（Win_record / Choose_record）
%   表现好的指标会被更频繁地选择
%
% 输入：
%   Population : 当前种群（含真实评估值）
%   indicator  : struct(3,1)，每个含 Pw（被选概率）等字段
%   Lp_prev    : 上一代的 Lp（如果 Shape_Estimate 失败时回退用）
%
% 输出：
%   Fitness : N×1 当代的性能指标值（越大越好）
%   flag    : 1=SDE / 2=I_eps+ / 3=MD（用于 UpdateInformation 反馈）
%   Lp      : 当代估计的 PF 形状参数
%
% 设计要点：
%   - Lp 每代重新估计（PIEA 思想：PF 形状随进化变化）
%   - 三指标按 Pw 概率轮盘选择
%   - SDE 退化时也会用 Lp，因此 Lp 估计影响所有指标

    PopObj = Population.objs;
    N      = length(Population);

    %% ============ 估计 PF 形状 ============
    % Shape_Estimate 从非支配解中估计 Lp（Minkowski 距离的指数）
    % Lp 决定了 PF 的形状：
    %   p < 1：凹 PF（concave）
    %   p = 1：线性 PF（linear）
    %   p > 1：凸 PF（convex）
    try
        Lp = Shape_Estimate(Population, N);
    catch
        Lp = Lp_prev;
    end
    % 防御：Lp 无效时回退到 1（线性）
    if isempty(Lp) || isnan(Lp) || Lp <= 0
        Lp = 1;
    end

    %% ============ 轮盘选择指标 ============
    % 根据三个指标的 Pw 概率随机选择一个
    r = rand;
    if r < indicator(1).Pw
        % 选择 SDE 指标
        Fitness = calFitness_SDE(PopObj, Lp);
        flag = 1;
    elseif r < indicator(1).Pw + indicator(2).Pw
        % 选择 I_epsilon+ 指标
        Fitness = calFitness_epsilon(PopObj, 0.05);
        flag = 2;
    else
        % 选择 Minkowski 距离指标
        Fitness = calFitness_MD(PopObj, Lp);
        flag = 3;
    end

    %% ============ 兜底：若全为 NaN/Inf，回退到 SDE ============
    if any(isnan(Fitness)) || any(isinf(Fitness))
        Fitness = calFitness_SDE(PopObj, Lp);
        flag = 1;
    end
end
