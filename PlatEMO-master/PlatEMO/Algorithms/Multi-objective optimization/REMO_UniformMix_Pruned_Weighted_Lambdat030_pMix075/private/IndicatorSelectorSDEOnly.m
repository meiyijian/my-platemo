function [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp_prev)
%IndicatorSelectorSDEOnly 计算用于指标代理训练的 SDE 适应度。
%   [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp_prev) 根据当前
%   已评价种群估计 Lp 形状参数并计算每个解的 SDE 指标值。
%   形状估计异常时使用 Lp_prev；参数无效时使用 Lp=1。
%   Fitness 作为 RBF-SVR 的训练目标，供 CDIS 的指标准则使用。

    PopObj = Population.objs;
    N      = length(Population);

    try
        Lp = Shape_Estimate(Population,N);
    catch
        Lp = Lp_prev;
    end
    if isempty(Lp) || ~isscalar(Lp) || isnan(Lp) || isinf(Lp) || Lp <= 0
        Lp = 1;
    end

    Fitness = calFitness_SDE(PopObj,Lp);
end
