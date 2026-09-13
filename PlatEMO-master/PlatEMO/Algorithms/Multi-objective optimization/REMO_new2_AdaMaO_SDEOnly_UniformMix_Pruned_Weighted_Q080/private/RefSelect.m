function Ref = RefSelect(Population,k)
%RefSelect 按非支配排序和径向网格选择参考解或下一代种群。
%   Ref = RefSelect(Population,K) 从已评价种群中选择至多 K 个解。
%   PAQC 使用该过程选择参考解；主循环对累计档案使用同一过程执行环境选择。
%   参考解数量由调用方提供：主入口使用随目标数调整的 k_eff，_k6 入口使用 6。
%   环境选择的请求数量为 Problem.N。
%
%   先保留较优非支配前沿，在截断前沿使用二维径向网格的已选解计数、
%   归一化目标和与投影距离选择剩余解。该操作沿用 RSEA 的径向网格选择。

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
    % 取前若干前沿，直到累计已排序解数达到 k
    [FrontNO,MaxFNO] = NDSort(PopObj,k);
    Next = find(FrontNO<=MaxFNO);  % 保留的解索引

    %% ============ 按各目标取值范围缩放 ============
    Pmin = min(PopObj,[],1) + 1e-6;  % 最小目标值偏移量
    Pmax = max(PopObj,[],1);
    if Pmax > Pmin
        PopObj = (PopObj-repmat(Pmin,size(PopObj,1),1))./repmat(Pmax-Pmin,size(PopObj,1),1);
    end

    %% ============ 环境选择 ============
    % div = ceil(sqrt(k)) 用于径向网格的分辨率
    Choose = LastSelection(PopObj(Next,:),ismember(Next,find(FrontNO<MaxFNO)),ceil(sqrt(k)),k);
    Ref    = Population(Next(Choose));
end
%% ============ 内部函数：基于径向网格的环境选择 ============
function Choose = LastSelection(PopObj,Choose,div,k)
%LastSelection 根据径向网格占用、目标和与投影距离补足选择集合。

    %% ---- 识别全目标均衡方向参考解 ----
    % 选择到 (1,1,...,1) 对角方向垂直距离最小的一个解。
    % 将该解加入已选集合，用于后续径向网格选择。
    [~,Extreme] = min(sqrt(sum(PopObj.^2,2)).* ...
        sqrt(1-(1-pdist2(PopObj,ones(1,size(PopObj,2)),'cosine')).^2),[],1);
    Choose = Choose | ismember(1:size(PopObj,1),Extreme);

    %% ---- 计算收敛性 ----
    % Con 为缩放后的目标值之和，再除以当前集合中的最大值。
    Con = sum(PopObj.^1,2).^1;
    Con = Con./max(Con);

    %% ---- 计算径向网格 ----
    % 将 M 维目标空间映射到 2 维径向投影坐标
    [Site,RLoc] = RadarGrid(PopObj,div);
    % 计算各解二维径向投影坐标之间的欧氏距离。
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

        % 适应度 = 0.1*M*归一化目标和 - 与已选解的最小二维投影距离
        % 含义：在当前候选集合中兼顾较小目标和与较远二维投影距离
        fitness  = 0.1.*size(PopObj,2).*Con(current) - min(RDis(current,Choose),[],2);
        [~,best] = min(fitness);

        % 选中并更新网格计数
        Choose(current(best))       = true;
        CrowdG(Site(current(best))) = CrowdG(Site(current(best))) + 1;
    end
end

%% ============ 内部函数：径向网格映射 ============
function [Site,RLoc] = RadarGrid(P,div)
%RadarGrid 将目标向量转换为二维径向投影坐标并分配网格编号。
%   Site 返回每个解的网格编号，RLoc 返回投影坐标；div 指定各维网格分辨率。

    [N,M] = size(P);

    %% ---- 计算径向投影坐标 ----
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
