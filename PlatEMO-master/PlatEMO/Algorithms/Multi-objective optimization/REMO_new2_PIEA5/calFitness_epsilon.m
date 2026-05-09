function Fitness = calFitness_epsilon(PopObj, kappa)
% calFitness_epsilon - I_epsilon+ 不可加性指标（来自 PIEA）
%
% 衡量"解 i 转换到解 j 至少需要在某一目标上恶化多少"
% 对超多目标场景下"互不支配但仍有强弱"的解有较好区分度
%
% 输入：
%   PopObj : N×M 目标值
%   kappa  : 平滑因子（PIEA 默认 0.05）
%
% 输出：
%   Fitness : N×1，越大越好
%
% 来源：PIEA/PIEA.m CalFitness_epsilon 子函数（IBEA 衍生）

    if nargin < 2
        kappa = 0.05;
    end

    N = size(PopObj, 1);
    PopObj = (PopObj - repmat(min(PopObj), N, 1)) ./ ...
             (repmat(max(PopObj) - min(PopObj) + eps, N, 1));

    I = zeros(N);
    for i = 1 : N
        for j = 1 : N
            I(i, j) = max(PopObj(i, :) - PopObj(j, :));
        end
    end
    C = max(abs(I));
    Fitness = sum(-exp(-I ./ repmat(C + eps, N, 1) / kappa)) + 1;
    Fitness = Fitness(:);
end
