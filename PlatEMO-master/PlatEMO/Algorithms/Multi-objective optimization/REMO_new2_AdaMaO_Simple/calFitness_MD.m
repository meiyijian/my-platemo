function Fitness = calFitness_MD(PopObj, Lp)
% calFitness_MD - Minkowski(Lp) 距离至理想点
%
% 当 PF 形状被 Lp 准确估计时，此距离能将 PF 上的解映射到等高线上
%
% Lp 的含义：
%   Lp=1：曼哈顿距离（适合 linear PF）
%   Lp=2：欧氏距离（适合凸 PF）
%   Lp<1：偏向凹 PF
%
% 输入：
%   PopObj : N×M 目标值
%   Lp     : Shape_Estimate 估计的形状参数
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
