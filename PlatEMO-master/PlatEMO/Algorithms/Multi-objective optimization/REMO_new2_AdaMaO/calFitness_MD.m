function Fitness = calFitness_MD(PopObj, Lp)
% calFitness_MD - Minkowski(Lp) 距离至理想点
%
% 当当前非支配近似集可由某个 Lp 等值面较好拟合时，该距离可提供对应标量排序
%
% Lp 的含义：
%   Lp=1：线性广义等值面
%   按常用 PF 命名，Lp>1 通常对应球面式 concave 形状，Lp<1 通常对应 convex 形状
%
% 输入：
%   PopObj : N×M 目标值
%   Lp     : Shape_Estimate 从当前非支配近似集拟合的形状参数
%
% 输出：
%   Fitness : N×1，越大越好
%
% 来源：PIEA/PIEA.m calFitness_MD 子函数

    N       = size(PopObj, 1);
    % 归一化到 [0,1]
    fmax    = max(PopObj, [], 1);
    fmin    = min(PopObj, [], 1);
    PopObj  = (PopObj - repmat(fmin, N, 1)) ./ repmat(fmax - fmin + eps, N, 1);
    % 计算 Minkowski 距离至理想点（原点）
    dis     = pdist2(PopObj, min(PopObj), 'minkowski', Lp);
    % 距离越小越好 → 取负使越大越好
    Fitness = -dis;
end
