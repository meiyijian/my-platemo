function Ref = RefSelect(Population,k)
% 参考解选择函数：从种群中选出 k 个最具代表性的解作为参考解
% 使用 RSEA（Reference Solutions Evolutionary Algorithm）策略
%
% Population - 当前种群（包含多个解）
% k          - 要选择的参考解数量
% Ref        - 选出的参考解

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 如果要选的解比总解数还多，就只选总解数个
    k      = min(k,length(Population));
    PopObj = Population.objs;  % 获取所有解的目标函数值

    % NDSort = 非支配排序（Pareto前沿排序）
    % 把所有解按"支配关系"分层，FrontNO=每层编号，MaxFNO=最大层编号
    [FrontNO,MaxFNO] = NDSort(PopObj,k);
    % 选前 MaxFNO 层的解作为候选
    Next = find(FrontNO<=MaxFNO);

    % 目标值归一化到[0,1]范围，方便比较
    Pmin = min(PopObj,[],1) + 1e-6;  % 每个目标的最小值（加小量避免除零）
    Pmax = max(PopObj,[],1);          % 每个目标的最大值
    if Pmax > Pmin
        % (值-最小值)/(最大值-最小值) 将数据映射到[0,1]
        PopObj = (PopObj-repmat(Pmin,size(PopObj,1),1))./repmat(Pmax-Pmin,size(PopObj,1),1);
    end

    %% Environmental selection（环境选择——从候选中筛选出最终参考解）
    % ismember(Next,find(FrontNO<MaxFNO)) = 找出在更好前沿中的解（优先保留）
    % div = ceil(sqrt(k)) = 雷达网格的划分数量
    Choose = LastSelection(PopObj(Next,:),ismember(Next,find(FrontNO<MaxFNO)),ceil(sqrt(k)),k);
    Ref    = Population(Next(Choose));
end

function Choose = LastSelection(PopObj,Choose,div,k)
% 基于雷达网格的最终选择策略
% PopObj  - 归一化后的目标值
% Choose  - 当前已选中的解（逻辑数组，true=已选）
% div     - 网格划分精度
% k       - 需要选择的解的数量

    %% Identify the extreme solutions（找出极端解——在每个目标上表现最好的解）
    % 基于PBI方法计算每个目标维度上的极端点
    [~,Extreme] = min(sqrt(sum(PopObj.^2,2)).*sqrt(1-(1-pdist2(PopObj,ones(1,size(PopObj,2)),'cosine')).^2),[],1);
    % 把极端解也加入已选集合（保证极端解不会被淘汰）
    Choose      = Choose | ismember(1:size(PopObj,1),Extreme);

    %% Calculate the convergence of each solution（计算每个解的收敛性——值越小越好）
    Con = sum(PopObj.^1,2).^1;
    Con = Con./max(Con);  % 归一化到[0,1]

    %% Calculate the radar grid of each solution（计算雷达网格——衡量多样性）
    % RadarGrid = 将解映射到雷达图上，按角度和半径划分网格
    % Site = 每个解所在的网格编号，RLoc = 雷达坐标
    [Site,RLoc] = RadarGrid(PopObj,div);
    % 计算解之间的欧式距离（用于衡量拥挤程度）
    RDis        = pdist2(RLoc,RLoc);
    RDis(logical(eye(length(RDis)))) = inf;  % 自己到自己的距离设为无穷大
    % 统计每个网格中已选解的数量（拥挤度）
    CrowdG      = zeros(1,max(Site));
    temp        = tabulate(Site(Choose));
    CrowdG(temp(:,1)) = temp(:,2);

    %% Select k solutions（逐次选择，直到选够 k 个）
    while sum(Choose) < k
        % 找出未被选中的解中，网格拥挤度最小的那些（优先选稀疏区域的解）
        remainS  = find(~Choose);                    % 未被选中的解
        remainG  = unique(Site(remainS));            % 这些解所在的网格
        bestG    = CrowdG(remainG) == min(CrowdG(remainG));  % 拥挤度最小的网格
        current  = remainS(ismember(Site(remainS),remainG(bestG)));
        % 适应度 = 收敛性 - 与已选解的距离
        % 这样选择：既收敛好，又远离已选解（兼顾收敛性和多样性）
        fitness  = 0.1.*size(PopObj,2).*Con(current) - min(RDis(current,Choose),[],2);
        [~,best] = min(fitness);  % 适应度最小的解被选中
        Choose(current(best))       = true;
        CrowdG(Site(current(best))) = CrowdG(Site(current(best))) + 1;  % 更新网格拥挤度
    end
end

function [Site,RLoc] = RadarGrid(P,div)
% 雷达网格映射：将多目标解映射到2D雷达坐标，并划分网格
% P   - 目标值矩阵（N行M列，N个解，M个目标）
% div - 每个维度的网格划分数
% Site - 每个解所属的网格编号
% RLoc - 每个解的雷达坐标(x,y)

    [N,M] = size(P);

    %% Calculate the radar coordinate of each solution（计算每个解的雷达坐标）
    % theta = 将M个目标均匀分布在[0, 2π]的角度上
    theta     = 0 : 2*pi/M : 2*pi/M*(M-1);
    % 雷达坐标转换：把M维目标值映射到2D平面
    % x = sum(值*cos(角度))/sum(值)，y = sum(值*sin(角度))/sum(值)
    RLoc(:,1) = sum(P.*repmat(cos(theta),N,1),2)./sum(P,2);
    RLoc(:,2) = sum(P.*repmat(sin(theta),N,1),2)./sum(P,2);
    RLoc      = (RLoc+1)/2;   % 映射到[0,1]范围
    YL        = min(RLoc,[],1);                              % 每列最小值
    YU        = max(RLoc,[],1);                              % 每列最大值
    NRLoc     = (RLoc-repmat(YL,N,1))./repmat(YU-YL,N,1);    % 归一化到[0,1]

    %% Identify the index of grid of each solution（确定每个解在哪个网格中）
    GLoc            = floor(NRLoc.*div);       % 向下取整，得到网格坐标
    GLoc(GLoc>=div) = div - 1;                 % 边界处理（防止越界）
    UniqueGLoc      = sortrows(unique(GLoc,'rows'));  % 所有不重复的网格坐标
    [~,Site]        = ismember(GLoc,UniqueGLoc,'rows');  % 每个解对应的网格编号
end
