function [Fitness, flag, Lp] = IndicatorSelector(Population, indicator, Lp_prev)
% IndicatorSelector - PIEA 风格的指标轮盘选择 + Lp 形状自适应
%
% 本函数实现 PIEA 风格的指标抽样：
%   使用三种标量指标评估当前种群，并按轮盘概率抽取一个指标。
%   当前主程序的反馈可能来自未实际使用该指标的候选模式，因此概率不能直接解释为指标因果贡献。
%
% 三种指标：
%   1. SDE（移位密度估计）：
%      - 使用移位距离同时体现收敛和密度信息
%      - 当前实现仅对 SDE 得分接近 0 的个体改用 Minkowski 距离
%
%   2. I_epsilon+（加性 epsilon 指标）：
%      - 衡量"解 i 转换到解 j 至少需要在某一目标上恶化多少"
%      - 为互不支配解提供基于加性 epsilon 关系的标量区分
%
%   3. Minkowski（Minkowski 距离至理想点）：
%      - 使用当前非支配近似集估计的 Lp 计算到理想点的距离
%      - Lp=1：线性广义等值面
%      - 按多目标优化常用 PF 命名，Lp>1 通常对应球面式 concave 形状，Lp<1 通常对应 convex 形状
%
% 轮盘选择机制：
%   每个指标被选中的概率 Pw 基于窗口内批次反馈（Win_record / Choose_record）
%   该反馈是整批新解结果，且不保证本代最终使用了该指标重排。
%
% 输入：
%   Population : 当前种群（含真实评估值）
%   indicator  : struct(3,1)，每个含 Pw（被选概率）等字段
%   Lp_prev    : 上一代的 Lp（如果 Shape_Estimate 失败时回退用）
%
% 输出：
%   Fitness : N×1 当代的性能指标值（越大越好）
%   flag    : 1=SDE / 2=I_eps+ / 3=MD（用于 UpdateInformation 反馈）
%   Lp      : 当代非支配近似集的 Lp 拟合参数
%
% 设计要点：
%   - Lp 每代从当前非支配近似集重新估计，并不等同于已知真实 PF 形状
%   - 三指标按 Pw 概率轮盘选择
%   - Lp 影响 Minkowski 指标及 SDE 中接近零得分个体的替代值，不影响 epsilon 指标

    PopObj = Population.objs;
    N      = length(Population);

    %% ============ 拟合当前非支配近似集的 Lp 参数 ============
    % Shape_Estimate 从当前非支配解中拟合 Lp（Minkowski 距离指数）
    % 按多目标优化常用 PF 命名：
    %   p < 1：凸 PF（convex）
%   p = 1：线性 PF（linear）
    %   p > 1：凹 PF（concave，如球面式 PF）
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
