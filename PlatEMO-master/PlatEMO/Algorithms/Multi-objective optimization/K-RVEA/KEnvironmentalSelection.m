function index = KEnvironmentalSelection(PopObj,V,theta)
% The environmental selection of K-RVEA

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He
% 中文注释作者：李盛薪 (2026-05-14)

% =========================================================================
% 【作用】RVEA 的环境选择：从大种群里挑出代表性子集（每个参考向量挑 1 个最佳）。
% 【输入】
%   PopObj —— 候选解的目标值矩阵 (N×M)，可以是真实值也可以是 Kriging 预测均值
%   V      —— 当前参考向量集 (NV×M)
%   theta  —— APD 中的时变惩罚因子 = (w/wmax)^alpha
% 【输出】
%   index  —— 被选中的解在 PopObj 中的行下标
%
% 【核心公式：APD = (1 + M·theta·angle/gamma) · ||F-z*||】
%   ||F-z*||           —— 收敛距离 (越小越靠近理想点)
%   angle              —— 解到关联参考向量的夹角 (越小越贴方向)
%   gamma              —— 该参考向量到最近邻参考向量的夹角 (用作归一化)
%   1 + M·theta·angle/gamma —— 角度惩罚项；theta 越大越偏多样性
% =========================================================================

    [N,M] = size(PopObj);     % N 个解，M 个目标
    NV    = size(V,1);        % NV 个参考向量

    %% Translate the population
    % 把种群平移到原点 (理想点 z* 近似为 min)，使 APD 的"模长"才有意义
    PopObj = PopObj - repmat(min(PopObj,[],1),N,1);

    %% Calculate the smallest angle value between each vector and others
    % 计算每个参考向量到"其他参考向量"的最小夹角 gamma_i
    % pdist2(V,V,'cosine') = 1 - cos(angle)，所以 1 - 该值 = cos(angle)
    cosine = 1 - pdist2(V,V,'cosine');
    cosine(logical(eye(length(cosine)))) = 0;   % 自己与自己夹角不算 (eye 是单位阵 → 对角线置零)
    gamma  = min(acos(cosine),[],2);            % 每行取最小，即最近邻参考向量的夹角

    %% Associate each solution to a reference vector
    % 把每个解关联到角度最近的那个参考向量 (RVEA 的"分区"步骤)
    Angle         = acos(1-pdist2(PopObj,V,'cosine'));   % 解 × 向量 的夹角矩阵
    [~,associate] = min(Angle,[],2);                     % 每个解关联到夹角最小的向量编号

    %% Select one solution for each reference vector
    Next = zeros(1,NV);                          % 每个参考向量留 1 个胜出者，初始化为 0
    % unique(associate)' 取出实际有解关联的那些参考向量编号
    % 注意撇号 ' 是为了把列向量转成行向量供 for 循环遍历
    for i = unique(associate)'
        current = find(associate==i);            % 找出关联到向量 i 的所有解
        % APD 公式实现：每个解算一个 APD 值，越小越好
        APD = (1+M*theta*Angle(current,i)/gamma(i)).*sqrt(sum(PopObj(current,:).^2,2));
        % 在该参考向量下的所有候选中，挑 APD 最小的胜出
        [~,best] = min(APD);
        Next(i)  = current(best);
    end
    % 没有解关联的参考向量留 0，这里去掉
    index = Next(Next~=0);
end
