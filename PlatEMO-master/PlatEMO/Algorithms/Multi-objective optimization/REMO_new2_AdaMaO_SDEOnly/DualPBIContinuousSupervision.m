function [Catalog,agreement,Ref,score] = DualPBIContinuousSupervision( ...
    Population,ratio,Nref,k,theta)
%DualPBIContinuousSupervision Build relation supervision from continuous PBI views.
%   The population-wide reference-direction view and representative-solution
%   view are converted to rank utilities before progress-based blending.

    PopObj = Population.objs;
    M = size(PopObj,2);

    globalDirections = UniformPoint(Nref,M,'ILD');
    directionNorm = vecnorm(globalDirections,2,2);
    globalDirections = globalDirections(directionNorm > 0,:)./ ...
        directionNorm(directionNorm > 0);

    Ref = RefSelect(Population,k);
    [score,detail] = ComputeSDEFactorialContinuousScore( ...
        PopObj,Ref.objs,globalDirections,ratio,theta);

    [~,order] = sort(score,'descend');
    goodCount = ceil(numel(score)/4);
    Catalog = false(numel(score),1);
    Catalog(order(1:goodCount)) = true;

    agreement = 1-abs(detail.globalScore-detail.localScore);
    agreement = min(1,max(0,agreement));
end
