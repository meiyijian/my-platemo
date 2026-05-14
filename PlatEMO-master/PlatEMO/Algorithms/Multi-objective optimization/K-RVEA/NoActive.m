function [num,active] = NoActive(PopObj,V)
% Detect inactive reference vectors

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
% 【作用】统计"不活跃参考向量"——即没有任何解关联到它的参考向量。
% 【为什么重要】
%   不活跃数 = 参考向量被浪费的程度 = 当前种群多样性的代理指标。
%   K-RVEA 的模型管理就用"不活跃数的变化"做 explore/exploit 切换 (见 KrigingSelect)。
% 【输入】
%   PopObj —— 解集目标值 (N×M)
%   V      —— 参考向量集 (NV×M)
% 【输出】
%   num    —— 不活跃参考向量的数量 (越大说明多样性越差)
%   active —— 活跃参考向量的编号列表 (有解关联的)
% =========================================================================

    [N,~] = size(PopObj);
    NV    = size(V,1);

    %% Translate the population
    % 平移到原点，避免目标值整体偏移影响夹角计算
    PopObj = PopObj - repmat(min(PopObj,[],1),N,1);

    %% Associate each solution to a reference vector
    % 每个解关联到夹角最近的参考向量
    Angle         = acos(1-pdist2(PopObj,V,'cosine'));
    [~,associate] = min(Angle,[],2);
    active        = unique(associate);   % 实际被"用上"的参考向量编号
    num           = NV-length(active);   % 不活跃数 = 总数 - 活跃数
end
