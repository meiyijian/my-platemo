function Ref = RefSelect(Population,k)
% 参考解选择（RSEA 策略：Radar grid based Selection Evolutionary Algorithm）
% 从种群中选出 k 个有代表性的解，用于：
% 1. HPC 内部的 PBI 标签计算（k=6）
% 2. 主流程末尾的环境选择（k=Problem.N）
%
% 输入:
%   Population - 种群对象
%   k          - 需要选出的解数量
% 输出:
%   Ref        - 选出的 k 个解

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % k 不能超过种群规模
    k      = min(k,length(Population));
    PopObj = Population.objs;  % N x M 目标值矩阵

    %% ============ 非支配排序 ============
    % 取前若干前沿，直到累计解数 >= k
    [FrontNO,MaxFNO] = NDSort(PopObj,k);
    Next = find(FrontNO<=MaxFNO);  % 保留的解索引

    %% ============ 目标值归一化到 [0,1] ============
    Pmin = min(PopObj,[],1) + 1e-6;  % 加小常数避免除零
    Pmax = max(PopObj,[],1);
    if Pmax > Pmin
        PopObj = (PopObj-repmat(Pmin,size(PopObj,1),1))./repmat(Pmax-Pmin,size(PopObj,1),1);
    end

    %% ============ 环境选择 ============
    % div = ceil(sqrt(k)) 用于雷达网格的分辨率
    Choose = LastSelection(PopObj(Next,:),ismember(Next,find(FrontNO<MaxFNO)),ceil(sqrt(k)),k);
    Ref    = Population(Next(Choose));
end

%% ============ 内部函数：基于雷达网格的环境选择 ============
function Choose = LastSelection(PopObj,Choose,div,k)
% 基于雷达网格策略选择 k 个解
% 输入:
%   PopObj  - 归一化后的目标值
%   Choose  - 逻辑向量，已确定保留的解（极端解+前前沿）
%   div     - 网格分辨率
%   k       - 需要选出的总数

    %% ---- 识别极端解 ----
    % 极端解：在 PBI 投影到 (1,1,...,1) 方向上最近的解
    % 这些解保证 Pareto 前沿的边界被覆盖
    [~,Extreme] = min(sqrt(sum(PopObj.^2,2)).* ...
        sqrt(1-(1-pdist2(PopObj,ones(1,size(PopObj,2)),'cosine')).^2),[],1);
    Choose = Choose | ismember(1:size(PopObj,1),Extreme);

    %% ---- 计算收敛性 ----
    % 收敛性 = 到原点的距离（归一化后），越小越好
    Con = sum(PopObj.^1,2).^1;
    Con = Con./max(Con);

    %% ---- 计算雷达网格 ----
    % 将 M 维目标空间映射到 2 维雷达坐标
    [Site,RLoc] = RadarGrid(PopObj,div);
    % 计算网格中心之间的距离
    RDis        = pdist2(RLoc,RLoc);
    RDis(logical(eye(length(RDis)))) = inf;  % 对角线设为无穷

    % 统计每个网格中的已选解数量
    CrowdG      = zeros(1,max(Site));
    temp        = tabulate(Site(Choose));
    CrowdG(temp(:,1)) = temp(:,2);

    %% ---- 迭代选择直到选满 k 个 ----
    while sum(Choose) < k
        % 找到最稀疏的网格
        remainS  = find(~Choose);           % 未选中的解
        remainG  = unique(Site(remainS));   % 未选中解所在的网格
        bestG    = CrowdG(remainG) == min(CrowdG(remainG));  % 最稀疏的网格
        current  = remainS(ismember(Site(remainS),remainG(bestG)));

        % 适应度 = 0.1*M*收敛性 - 与已选解的最小网格距离
        % 含义：优先选收敛性好且与已选解距离远的解
        fitness  = 0.1.*size(PopObj,2).*Con(current) - min(RDis(current,Choose),[],2);
        [~,best] = min(fitness);

        % 选中并更新网格计数
        Choose(current(best))       = true;
        CrowdG(Site(current(best))) = CrowdG(Site(current(best))) + 1;
    end
end

%% ============ 内部函数：雷达网格映射 ============
function [Site,RLoc] = RadarGrid(P,div)
% 将 M 维目标空间映射到 2 维雷达坐标，并划分网格
% 输入:
%   P   - N x M 归一化目标值
%   div - 网格分辨率
% 输出:
%   Site - N x 1 每个解所属的网格编号
%   RLoc - 网格中心的 2D 坐标

    [N,M] = size(P);

    %% ---- 计算雷达坐标 ----
    % theta: M 个等间隔角度
    theta     = 0 : 2*pi/M : 2*pi/M*(M-1);
    % x 坐标 = 目标值加权余弦和 / 目标值和
    RLoc(:,1) = sum(P.*repmat(cos(theta),N,1),2)./sum(P,2);
    % y 坐标 = 目标值加权正弦和 / 目标值和
    RLoc(:,2) = sum(P.*repmat(sin(theta),N,1),2)./sum(P,2);
    % 映射到 [0,1]
    RLoc      = (RLoc+1)/2;

    %% ---- 归一化到 [0,1] ----
    YL        = min(RLoc,[],1);                             % 下界
    YU        = max(RLoc,[],1);                             % 上界
    NRLoc     = (RLoc-repmat(YL,N,1))./repmat(YU-YL,N,1);  % 归一化

    %% ---- 划分网格 ----
    % 将 [0,1] 均匀划分为 div x div 网格
    GLoc            = floor(NRLoc.*div);
    GLoc(GLoc>=div) = div - 1;  % 边界处理

    % 唯一网格编号
    UniqueGLoc      = sortrows(unique(GLoc,'rows'));
    [~,Site]        = ismember(GLoc,UniqueGLoc,'rows');
end