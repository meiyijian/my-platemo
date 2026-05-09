function fitness = R2Fitness(PopObj, W, Z)
% 基于 R2 指标的解适应度（用于比较解的综合质量）
%   PopObj  : N×M 目标值矩阵
%   W       : nW×M 权重向量（单位向量）
%   Z       : 理想点（各目标最小值）
%   fitness : N×1 向量，值越大代表解越好

    N = size(PopObj,1);
    nW = size(W,1);
    bestIdx = zeros(nW,1);

    for i = 1:nW
        w = W(i,:);
        % 切比雪夫标量化距离
        chebyDist = max((PopObj - Z) .* w, [], 2);
        [~, bestIdx(i)] = min(chebyDist);
    end

    % 统计每个解成为最佳解的次数（频率），并以此作为适应度
    fitness = histcounts(bestIdx, 1:N+1)' / nW;
end