function p = Shape_Estimate(Population, N)
%Shape_Estimate 根据当前非支配解集估计 Lp 形状参数。
%   P = Shape_Estimate(Population,N) 取已评价种群的第一非支配前沿，
%   归一化其目标值，并计算 17 个候选 Lp 参数对应的范数。
%   对每个候选参数，剔除高于 Q3+1.5*(Q3-Q1) 的范数后，比较归一化范数
%   的标准差，选择标准差最小的参数。非支配解少于 20 个时返回 P=1。
%   N 为传给 NDSort 的目标排序解数；本函数只使用第一非支配前沿。
%   所得参数用于 SDE 近零得分的 Lp 距离细化，计算过程沿用 PIEA。

    % 非支配排序，取第一层
    [FrontNo, ~] = NDSort(Population.objs, N);
    Pop = Population(FrontNo <= 1);
    % 非支配解少于 20 个时，使用 Lp=1。
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
        % 剔除高于上侧四分位阈值的范数值。
        Gp(Gp > Max) = [];
        % 计算归一化后的标准差
        Vp(i) = std(Gp ./ max(Gp));
    end
    % 选择标准差最小的 Lp
    [~, idx] = min(Vp);
    p = CP(idx);
end
