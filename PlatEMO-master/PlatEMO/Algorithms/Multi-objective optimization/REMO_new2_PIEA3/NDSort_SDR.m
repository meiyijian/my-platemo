function [FrontNo, MaxFNo] = NDSort_SDR(Population, nSort)
% NDSort_SDR - 强支配关系（Strengthened Dominance Relation）非支配排序
%
% 比标准 NDSort 引入角度阈值 Theta，使支配关系在多目标下更严格
% 用于 PIEA 的"hierarchical evaluation"：判断新解是否真正"脱颖而出"
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

    zmax   = max(Population.objs);
    zmin   = min(Population.objs);
    PopObj = (Population.objs - zmin) ./ (zmax - zmin + eps);
    N      = size(PopObj, 1);
    NormP  = sum(PopObj, 2);

    cosine = 1 - pdist2(PopObj, PopObj, 'cosine');
    cosine(logical(eye(length(cosine)))) = 0;
    Angle  = acos(max(min(cosine, 1), -1));

    % 角度阈值：种群中最小角度的中位数
    temp = sort(unique(min(Angle, [], 2)));
    if isempty(temp)
        minA = 1;
    else
        minA = temp(min(ceil(N / 2), end));
    end
    if minA == 0
        minA = eps;
    end
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

    FrontNo = inf(1, N);
    MaxFNo  = 0;
    while sum(FrontNo ~= inf) < min(nSort, N)
        MaxFNo = MaxFNo + 1;
        current = ~any(dominate, 1) & FrontNo == inf;
        FrontNo(current)    = MaxFNo;
        dominate(current, :) = false;
    end
end
