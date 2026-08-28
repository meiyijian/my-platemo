function Fitness = calFitness_SDE(PopObj, Lp)
% calFitness_SDE - 移位密度估计 + Minkowski(Lp) 退化
%
% SDE（Shift-based Density Estimation）是 PIEA 所采用的一种移位密度估计方法
% 核心思想：不仅考虑解之间的距离，还考虑解之间的"方向"
%
% 传统密度估计的问题：
%   在高维目标空间中，两个解可能在数值上很近，但在方向上完全不同
%   传统密度估计会认为它们"拥挤"，但实际上它们代表不同的区域
%
% SDE 的改进：
%   对于解 i 和解 j，不是直接计算 ||i - j||，
%   而是计算 ||i - max(i, j)||，其中 max 是逐元素取最大值
%   这样只有当 j 在所有目标上都优于 i 时，距离才为 0
%
% 退化机制：
%   当前实现对 SDE 得分小于 1e-4 的个体，使用 Minkowski(Lp) 理想点距离替换其得分；
%   这不等同于对整个指标自动切换。
%
% 输入：
%   PopObj : N×M 目标值
%   Lp     : Shape_Estimate 从当前非支配近似集拟合的 Lp 参数
%
% 输出：
%   Fitness : N×1，越大越好
%
% 来源：PIEA/PIEA.m calFitness_SDE 子函数

    N      = size(PopObj, 1);
    % 归一化到 [0,1]
    fmax   = max(PopObj, [], 1);
    fmin   = min(PopObj, [], 1);
    PopObj = (PopObj - repmat(fmin, N, 1)) ./ repmat(fmax - fmin + eps, N, 1);

    % 计算 SDE 距离矩阵
    Dis = inf(N);
    for i = 1 : N
        % 对于解 i，计算它到其他解的"移位距离"
        SPopObj = max(PopObj, repmat(PopObj(i, :), N, 1));
        for j = [1 : i - 1, i + 1 : N]
            Dis(i, j) = norm(PopObj(i, :) - SPopObj(j, :));
        end
    end
    % SDE 密度 = 最近邻的移位距离
    Fitness = min(Dis, [], 2);
    % 归一化到 [0,3]
    Fitness = 3 / (max(Fitness) + eps - min(Fitness)) * (Fitness - min(Fitness));

    % SDE 失效（值<1e-4）时退化为 Minkowski(Lp) 距离至理想点
    dis = pdist2(PopObj, min(PopObj), 'minkowski', Lp);
    dis = -3 / (max(dis) + eps - min(dis)) * (dis - min(dis));
    Fitness(Fitness < 1e-4) = dis(Fitness < 1e-4);

    % tanh sigmoid 缩放到 [-1,1]
    Fitness = tansig(Fitness);
end

