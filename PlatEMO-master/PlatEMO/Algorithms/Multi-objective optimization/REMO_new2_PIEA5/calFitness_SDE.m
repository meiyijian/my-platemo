function Fitness = calFitness_SDE(PopObj, Lp)
% calFitness_SDE - 移位密度估计 + Minkowski(Lp) 退化（来自 PIEA）
%
% 当 SDE 失去区分度（解相互聚集）时，自动退化为 Lp 距离至理想点
%
% 输入：
%   PopObj : N×M 目标值
%   Lp     : Shape_Estimate 估计的 PF 形状参数
%
% 输出：
%   Fitness : N×1，越大越好
%
% 来源：PIEA/PIEA.m calFitness_SDE 子函数

    N      = size(PopObj, 1);
    fmax   = max(PopObj, [], 1);
    fmin   = min(PopObj, [], 1);
    PopObj = (PopObj - repmat(fmin, N, 1)) ./ repmat(fmax - fmin + eps, N, 1);

    Dis = inf(N);
    for i = 1 : N
        SPopObj = max(PopObj, repmat(PopObj(i, :), N, 1));
        for j = [1 : i - 1, i + 1 : N]
            Dis(i, j) = norm(PopObj(i, :) - SPopObj(j, :));
        end
    end
    Fitness = min(Dis, [], 2);
    Fitness = 3 / (max(Fitness) + eps - min(Fitness)) * (Fitness - min(Fitness));

    % SDE 失效（值<1e-4）时退化为 Minkowski(Lp) 距离至理想点
    dis = pdist2(PopObj, min(PopObj), 'minkowski', Lp);
    dis = -3 / (max(dis) + eps - min(dis)) * (dis - min(dis));
    Fitness(Fitness < 1e-4) = dis(Fitness < 1e-4);

    Fitness = tansig(Fitness);   % tanh sigmoid 缩放到 [-1,1]
end
