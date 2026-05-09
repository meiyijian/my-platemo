function [Fitness, flag, Lp] = IndicatorSelector(Population, indicator, Lp_prev)
% IndicatorSelector - PIEA 风格的指标轮盘选择 + Lp 形状自适应
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

    %% 估计 PF 形状（失败时回退）
    try
        Lp = Shape_Estimate(Population, N);
    catch
        Lp = Lp_prev;
    end
    if isempty(Lp) || isnan(Lp) || Lp <= 0
        Lp = 1;
    end

    %% 轮盘选择指标
    r = rand;
    if r < indicator(1).Pw
        Fitness = calFitness_SDE(PopObj, Lp);
        flag = 1;
    elseif r < indicator(1).Pw + indicator(2).Pw
        Fitness = calFitness_epsilon(PopObj, 0.05);
        flag = 2;
    else
        Fitness = calFitness_MD(PopObj, Lp);
        flag = 3;
    end

    %% 兜底：若全为 NaN/Inf，回退到 SDE
    if any(isnan(Fitness)) || any(isinf(Fitness))
        Fitness = calFitness_SDE(PopObj, Lp);
        flag = 1;
    end
end
