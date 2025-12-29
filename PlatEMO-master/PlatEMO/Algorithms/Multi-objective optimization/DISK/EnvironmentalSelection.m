function Next = EnvironmentalSelection(PopObj,N)
% 环境选择：基于非支配排序和分布信息选择优秀个体，保持种群规模
% 输入：
%   PopObj - 目标函数值矩阵
%   N      - 目标种群规模
% 输出：
%   Next   - 选择结果的逻辑向量

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: z.zhang0@csu.edu.cn)

    %% Non-dominated sorting
    zmin   = min(PopObj); % 计算理想点
    zmax   = max(PopObj); % 计算最低点
    PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10); % 归一化处理，避免数值问题
    [FrontNo,MaxFNo] = NDSort(PopObj,N); % 非支配排序，得到每个解的前沿编号和最大前沿编号
    Next   = FrontNo < MaxFNo; % 初始选择所有非最后前沿的解
    Last   = find(FrontNo == MaxFNo); % 最后一个前沿的解索引

    %% Select the solutions in the last front
    if MaxFNo == 1 % 如果所有解都在同一前沿（单前沿情况）
        Del = Truncation(PopObj(Last,:),N); % 截断选择
        Next(Last(Del)) = true; % 更新选择结果
    else % 多前沿情况
        Choose = Dist_Selection(PopObj(Next,:),PopObj(Last,:),N - sum(Next)); % 基于分布的选择
        Next(Last(Choose)) = true; % 更新选择结果
    end
end

function Choose = Dist_Selection(PopObj1,PopObj2,mu)
% 基于分布的选择：从PopObj2中选择mu个解，使它们与PopObj1的分布距离最大
% 输入：
%   PopObj1 - 已选择的解的目标函数值
%   PopObj2 - 待选择的解的目标函数值
%   mu      - 待选择的解的数量
% 输出：
%   Choose  - PopObj2中被选择的解的索引
    PopObj = [PopObj1;PopObj2]; % 合并所有解
    N      = size(PopObj,1); % 总解数
    N1     = size(PopObj1,1); % 已选择的解数
    
    %% Calculate the angle-based distance between each two solutions
    Distance = acos(1-pdist2(PopObj,PopObj,'cosine')); % 计算基于余弦相似度的角度距离
    Distance(logical(eye(length(Distance)))) = inf; % 自身距离设为无穷大
    
    %% 选择距离已选解最远的解
    Next1 = 1 : N1; % 已选择的解索引
    Next2 = N1+1 : N; % 待选择的解索引
    for i = 1 : mu % 循环选择mu个解
        Distance1 = sort(Distance(Next2,Next1),2); % 计算每个待选解与已选解的最近距离
        [~,index] = max(Distance1(:,1)); % 选择最近距离最大的解
        Next1     = [Next1,Next2(index)]; % 将该解加入已选择集合
        Next2(index) = []; % 从待选择集合中移除该解
    end
    Choose = Next1(N1+1:end) - N1; % 转换为PopObj2中的相对索引
end

function Del = Truncation(PopObj,K)
% 截断选择：当所有解都在同一前沿时，选择K个最具代表性的解
% 输入：
%   PopObj - 目标函数值矩阵
%   K      - 目标选择数量
% 输出：
%   Del    - 被删除解的逻辑向量（true表示保留，false表示删除）
    %% Select part of the solutions by truncation
    [N,~] = size(PopObj); % 总解数
    
    %% Calculate the angle-based distance between each two solutions
    Distance = acos(1-pdist2(PopObj,PopObj,'cosine')); % 计算基于余弦相似度的角度距离
    
    %% 截断选择过程
    Distance(logical(eye(length(Distance)))) = inf; % 自身距离设为无穷大
    Del = true(1,N); % 初始化保留所有解
    while sum(Del) > K % 当保留的解数超过K时
        Remain   = find(Del); % 当前保留的解索引
        Temp     = sort(Distance(Remain,Remain),2); % 计算每个解与其他解的距离并排序
        [~,Rank] = sortrows(Temp); % 根据距离矩阵排序，找出最拥挤的解
        Del(Remain(Rank(1))) = false; % 删除最拥挤的解
    end
end