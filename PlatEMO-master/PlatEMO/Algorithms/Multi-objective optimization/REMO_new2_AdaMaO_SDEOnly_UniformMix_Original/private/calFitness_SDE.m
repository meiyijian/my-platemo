function Fitness = calFitness_SDE(PopObj, Lp)
%calFitness_SDE 计算移位密度指标并用 Lp 距离细化近零得分。
%   Fitness = calFitness_SDE(PopObj,Lp) 先对 N×M 目标矩阵进行归一化，
%   再按逐目标取大的规则将解 j 移位为 max(f_i,f_j)，计算其到解 i 的距离。
%   每个解取最近邻移位距离作为 SDE 得分。
%
%   得分归一化后，小于 1e-4 的位置使用负向归一化的 Lp 理想点距离细化，
%   最后通过 tansig 缩放。Fitness 越大，在指标准则中的排序优先级越高。
%   Lp 由 Shape_Estimate 根据当前非支配解集估计。
%   本实现沿用 PIEA 中的 SDE 指标计算过程。

    N      = size(PopObj, 1);
    % 归一化到 [0,1]
    fmax   = max(PopObj, [], 1);
    fmin   = min(PopObj, [], 1);
    PopObj = (PopObj - repmat(fmin, N, 1)) ./ repmat(fmax - fmin + eps, N, 1);

    % 计算 SDE 距离矩阵
    Dis = inf(N);
    for i = 1 : N
        % 对于解 i，计算它到其他解的移位距离
        SPopObj = max(PopObj, repmat(PopObj(i, :), N, 1));
        for j = [1 : i - 1, i + 1 : N]
            Dis(i, j) = norm(PopObj(i, :) - SPopObj(j, :));
        end
    end
    % SDE 得分取每个解的最近邻移位距离。
    Fitness = min(Dis, [], 2);
    % 归一化到 [0,3]
    Fitness = 3 / (max(Fitness) + eps - min(Fitness)) * (Fitness - min(Fitness));

    % 对归一化 SDE 得分小于 1e-4 的解，使用负向 Lp 理想点距离细化。
    dis = pdist2(PopObj, min(PopObj), 'minkowski', Lp);
    dis = -3 / (max(dis) + eps - min(dis)) * (dis - min(dis));
    Fitness(Fitness < 1e-4) = dis(Fitness < 1e-4);

    % tanh sigmoid 缩放到 [-1,1]
    Fitness = tansig(Fitness);
end
