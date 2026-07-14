function [FrontNo, MaxFNo] = NDSort_SDR(Population, nSort)
% NDSort_SDR - 目标和与夹角驱动的替代关系排序（沿用 SDR 名称）
%
% 本函数不检查逐目标 Pareto 支配，而是用归一化目标和与两解夹角构造有向关系。
% 它可用于标准 Pareto 第一前沿内部的二次排序，但不是标准支配关系的严格子集。
%
% 与标准 NDSort 的区别：
%   标准 NDSort: 依据逐目标 Pareto 支配
%   本函数: 仅依据 NormP(i)*Theta(i,j) < NormP(j)，可能比较两个互不支配的权衡解
%
% 替代关系公式：
%   NormP(i) * Theta(i,j) < NormP(j)  →  记录 i 指向 j 的优先关系
%
% 其中：
%   NormP(i) = sum(PopObj(i,:))  // 解 i 的目标值之和（归一化后）
%   Theta(i,j) = (Angle(i,j) / minA)^1  // 角度阈值
%   Angle(i,j) = arccos(cosine_similarity(i,j))  // 两解之间的角度
%   minA = 种群中最小角度的中位数
%
% 设计动机：
%   在标准 Pareto 支配区分力较弱的高目标维场景中，使用目标和与夹角提供额外排序压力。
%   该关系会引入不同于 Pareto 支配的偏好，不能解释为“更严格的 Pareto 支配”。
%
% 输入：
%   Population : 种群
%   nSort      : 至少排序到第几层（PIEA 中用 1）
%
% 输出：
%   FrontNo : N×1，每个解的层数（inf 表示未排到）
%   MaxFNo  : 排出的最大层数
%
% 来源：PIEA/NDSort_SDR.m

    % 归一化目标值到 [0,1]
    zmax   = max(Population.objs);
    zmin   = min(Population.objs);
    PopObj = (Population.objs - zmin) ./ (zmax - zmin + eps);
    N      = size(PopObj, 1);
    % 计算每个解的目标值之和
    NormP  = sum(PopObj, 2);

    % 计算解之间的余弦相似度和角度
    cosine = 1 - pdist2(PopObj, PopObj, 'cosine');
    cosine(logical(eye(length(cosine)))) = 0;
    Angle  = acos(max(min(cosine, 1), -1));

    % 计算角度阈值 Theta
    % minA = 种群中最小角度的中位数
    temp = sort(unique(min(Angle, [], 2)));
    if isempty(temp)
        minA = 1;
    else
        minA = temp(min(ceil(N / 2), end));
    end
    if minA == 0
        minA = eps;
    end
    % Theta = (Angle / minA)^1
    % 当 Angle = minA 时，Theta = 1，退化为标准支配关系
    % 当 Angle > minA 时，Theta > 1，建立 i→j 关系所需的目标和优势更大
    Theta = max(1, (Angle ./ minA) .^ 1);

    % 角度修正的替代优先关系
    dominate = false(N);
    for i = 1 : N - 1
        for j = i + 1 : N
            if NormP(i) * Theta(i, j) < NormP(j)
                dominate(i, j) = true;
            elseif NormP(j) * Theta(j, i) < NormP(i)
                dominate(j, i) = true;
            end
        end
    end

    % 非支配排序
    FrontNo = inf(1, N);
    MaxFNo  = 0;
    while sum(FrontNo ~= inf) < min(nSort, N)
        MaxFNo = MaxFNo + 1;
        % 找到当前层没有被该替代关系中其他解指向的解
        current = ~any(dominate, 1) & FrontNo == inf;
        FrontNo(current)    = MaxFNo;
        % 移除这些解对其他解的有向优先关系
        dominate(current, :) = false;
    end
end
