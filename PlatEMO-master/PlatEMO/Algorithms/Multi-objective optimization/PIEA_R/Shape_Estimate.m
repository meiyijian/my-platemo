function p = Shape_Estimate(Population, N)
% Shape_Estimate - 估计 Pareto 前沿的形状参数 Lp（来自 PIEA）
%
% 输入：
%   Population : 种群（含真实评估解）
%   N          : NDSort 的层数限制
%
% 输出：
%   p : Lp 范数指数（决定 Minkowski 距离形状）
%       p < 1：concave PF（凹）
%       p = 1：linear PF
%       p > 1：convex PF（凸）
%
% 实现逻辑（与 PIEA/Shape_Estimate.m 一致）：
%   - 用非支配解（NDSort 第一层）
%   - 从 17 个候选 Lp ∈ [0.27, 6.5] 中选标准差最小的
%   - 标准差衡量"PF 上的解到原点的 Lp 范数"是否一致
%
% 来源：
%   Y. Li, W. Li, S. Li, Y. Zhao. PIEA. Information Sciences, 2024.

    [FrontNo, ~] = NDSort(Population.objs, N);
    Pop = Population(FrontNo <= 1);
    if length(Pop) < 20
        p = 1;
        return;
    end
    PopObj = Pop.objs;
    [Np, ~] = size(PopObj);

    % 归一化
    fmin = min(PopObj, [], 1);
    fmax = max(PopObj, [], 1);
    PopObj = (PopObj - repmat(fmin, Np, 1)) ./ repmat(fmax - fmin + eps, Np, 1);

    k = 1.5;   % 箱线图离群因子
    CP = [0.27 0.36 0.43 0.5 0.57 0.66 0.75 0.86 1 1.15 1.35 1.6 2 2.4 3.1 4.2 6.5];
    Vp = zeros(1, length(CP));
    for i = 1 : length(CP)
        Gp   = (sum(PopObj .^ CP(i), 2)) .^ (1 / CP(i));
        temp = sort(Gp);
        Q1   = temp(max(fix(Np * 0.25), 1));
        Q3   = temp(max(fix(Np * 0.75), 1));
        Max  = Q3 + k * (Q3 - Q1);
        Gp(Gp > Max) = [];   % 用箱线图剔除离群点
        Vp(i) = std(Gp ./ max(Gp));
    end
    [~, idx] = min(Vp);
    p = CP(idx);
end
