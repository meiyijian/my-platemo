function [FrontNo, MaxFNo] = NDSort_SDR(Population, nSort)
% NDSort_SDR - 强支配关系（Strengthened Dominance Relation）非支配排序
%
% 比标准 NDSort 引入角度阈值 Theta，使支配关系在多目标下更严格
% 用于 PIEA 的"hierarchical evaluation"：判断新解是否真正"脱颖而出"
%
% 与标准 NDSort 的区别：
%   标准 NDSort: 解 A 支配解 B，当且仅当 A 在所有目标上都不差于 B，且至少在一个目标上严格优于 B
%   NDSort_SDR: 在此基础上，引入角度阈值 Theta，使支配关系更严格
%
% 支配关系公式：
%   NormP(i) * Theta(i,j) < NormP(j)  →  i 支配 j
%
% 其中：
%   NormP(i) = sum(PopObj(i,:))  // 解 i 的目标值之和（归一化后）
%   Theta(i,j) = (Angle(i,j) / minA)^1  // 角度阈值
%   Angle(i,j) = arccos(cosine_similarity(i,j))  // 两解之间的角度
%   minA = 种群中最小角度的中位数
%
% 设计动机：
%   在高维目标空间中，标准支配关系可能过于宽松
%   SDR 通过角度阈值使支配关系更严格，筛选出真正优秀的解
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
    % 当 Angle > minA 时，Theta > 1，支配关系更严格
    Theta = max(1, (Angle ./ minA) .^ 1);

    % 角度加权的支配关系
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
        % 找到当前层没有被任何解支配的解
        current = ~any(dominate, 1) & FrontNo == inf;
        FrontNo(current)    = MaxFNo;
        % 移除这些解对其他解的支配关系
        dominate(current, :) = false;
    end
end
