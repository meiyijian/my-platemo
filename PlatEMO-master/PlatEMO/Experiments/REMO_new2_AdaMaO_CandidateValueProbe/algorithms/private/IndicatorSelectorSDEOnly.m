function [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp_prev)
%IndicatorSelectorSDEOnly Evaluate the population with the fixed SDE score.
%
%   [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp_prev) estimates
%   the current Pareto-front shape and evaluates every solution with the
%   existing SDE-based fitness. The function contains no indicator roulette
%   and consumes no random numbers.

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
