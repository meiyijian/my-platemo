function [W,ideal] = IdentifyW(DB,N,M)
% 识别最远权重向量：用于指导局部搜索的方向
% 输入：
%   DB - 真实评估的种群
%   N  - 种群规模
%   M  - 目标函数数量
% 输出：
%   W     - 识别出的最远权重向量
%   ideal - 理想点

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: z.zhang0@csu.edu.cn)

    %% 数据准备
    V      = UniformPoint(10*N,M); % 生成10*N个均匀分布的权重向量
    A2Obj  = DB.objs; % 获取真实评估种群的目标函数值
    [F_,~] = NDSort(A2Obj,1); % 非支配排序，获取第一前沿
    A2Obj  = A2Obj(F_==1,:); % 仅保留第一前沿的解

    %% 坐标转换
    nadir = max(A2Obj,[],1); % 计算最低点
    ideal = min(A2Obj,[],1); % 计算理想点
    ideal = ideal - (nadir-ideal)/10 - 0.1*ones(1,M); % 调整理想点，确保搜索空间充足
    A2Obj = A2Obj - ideal; % 将所有解平移到以调整后的理想点为原点的坐标系
    
    %% 计算权重向量与解之间的角度
    Angle  = acos(1-pdist2(V,A2Obj,'cosine')); % 计算每个权重向量与每个解之间的角度
    Angle_ = sort(Angle,2); % 对每个权重向量，按角度从小到大排序
    index  = find(Angle_(:,1)==max(Angle_(:,1))); % 找出与最近解夹角最大的权重向量
    
    %% 确定最远的权重向量
    if length(index) > 1 % 如果有多个权重向量具有相同的最大最小角度
        index = index(randperm(length(index),1)); % 随机选择一个
    end
    W = V(index,:); % 返回识别出的最远权重向量  
end