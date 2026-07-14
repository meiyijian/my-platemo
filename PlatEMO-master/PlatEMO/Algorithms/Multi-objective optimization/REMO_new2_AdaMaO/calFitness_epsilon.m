function Fitness = calFitness_epsilon(PopObj, kappa)
% calFitness_epsilon - 加性 I_epsilon+ 指标
%
% I_epsilon+ 是 IBEA（Indicator-Based Evolutionary Algorithm）提出的指标
% 衡量"解 i 转换到解 j 至少需要在某一目标上恶化多少"
%
% 数学定义：
%   I_epsilon+(i, j) = max over all objectives m of (f_m(i) - f_m(j))
%
% 含义：
%   如果 I_epsilon+(i, j) < 0，说明 i 在所有目标上都优于 j
%   如果 I_epsilon+(i, j) > 0，说明 i 至少在一个目标上比 j 差 I_epsilon+(i, j)
%
% 适用场景：
%   对超多目标场景下"互不支配但仍有强弱"的解有较好区分度
%   比如两个解 A 和 B 互不支配，但 A 比 B 在某个目标上好很多，而 B 只比 A 在另一个目标上好一点点
%   I_epsilon+ 能识别出 A 比 B "更强"
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
    % 归一化到 [0,1]
    PopObj = (PopObj - repmat(min(PopObj), N, 1)) ./ ...
             (repmat(max(PopObj) - min(PopObj) + eps, N, 1));

    % 计算 I_epsilon+ 矩阵
    I = zeros(N);
    for i = 1 : N
        for j = 1 : N
            I(i, j) = max(PopObj(i, :) - PopObj(j, :));
        end
    end
    % 归一化因子
    C = max(abs(I));
    % 计算适应度（使用指数变换）
    Fitness = sum(-exp(-I ./ repmat(C + eps, N, 1) / kappa)) + 1;
    Fitness = Fitness(:);
end
