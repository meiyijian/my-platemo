function p = Shape_Estimate(Population, N)
% Shape_Estimate - 从当前非支配近似集拟合形状参数 Lp
%
% 本函数来自 PIEA（2024），用于拟合当前非支配近似集的广义 Lp 等值面
% 按多目标优化常用 PF 命名：
%   p < 1：convex PF（凸）
%   p = 1：linear PF（线性）
%   p > 1：concave PF（凹，如球面式 PF）
%
% 估计原理：
%   - 使用当前非支配解（NDSort 第一层）作为未知 PF 的有限近似
%   - 从 17 个候选 Lp ∈ [0.27, 6.5] 中选标准差最小的
%   - 标准差衡量"PF 上的解到原点的 Lp 范数"是否一致
%   - 如果某个 Lp 与当前近似集匹配，其归一化 Lp 范数的离散程度较小
%
% 输入：
%   Population : 种群（含真实评估解）
%   N          : NDSort 的层数限制
%
% 输出：
%   p : 当前非支配近似集的 Lp 拟合指数
%
% 来源：
%   Y. Li, W. Li, S. Li, Y. Zhao. PIEA. Information Sciences, 2024.

    % 非支配排序，取第一层
    [FrontNo, ~] = NDSort(Population.objs, N);
    Pop = Population(FrontNo <= 1);
    % 如果非支配解太少，回退到线性（p=1）
    if length(Pop) < 20
        p = 1;
        return;
    end
    PopObj = Pop.objs;
    [Np, ~] = size(PopObj);

    % 归一化到 [0,1]
    fmin = min(PopObj, [], 1);
    fmax = max(PopObj, [], 1);
    PopObj = (PopObj - repmat(fmin, Np, 1)) ./ repmat(fmax - fmin + eps, Np, 1);

    % 箱线图离群因子
    k = 1.5;
    % 17 个候选 Lp 值
    CP = [0.27 0.36 0.43 0.5 0.57 0.66 0.75 0.86 1 1.15 1.35 1.6 2 2.4 3.1 4.2 6.5];
    Vp = zeros(1, length(CP));
    for i = 1 : length(CP)
        % 计算 Lp 范数
        Gp   = (sum(PopObj .^ CP(i), 2)) .^ (1 / CP(i));
        temp = sort(Gp);
        Q1   = temp(max(fix(Np * 0.25), 1));
        Q3   = temp(max(fix(Np * 0.75), 1));
        Max  = Q3 + k * (Q3 - Q1);
        % 用箱线图剔除离群点
        Gp(Gp > Max) = [];
        % 计算归一化后的标准差
        Vp(i) = std(Gp ./ max(Gp));
    end
    % 选择标准差最小的 Lp
    [~, idx] = min(Vp);
    p = CP(idx);
end

