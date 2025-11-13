function Ref = RefSelect(Population,k)
% RefSelect - 使用RSEA策略选择参考解
% 输入参数：
%   Population: 当前种群
%   k: 需要选择的参考解数量
% 输出参数：
%   Ref: 选择的参考解集合

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He

    % 确保k不超过种群大小
    k      = min(k,length(Population));
    
    % 获取种群的目标值矩阵
    PopObj = Population.objs;
    
    % 非支配排序，获取每个解的前沿编号
    % FrontNO: 每个解的前沿编号
    % MaxFNO: 为了选择k个解需要考虑的最大前沿编号
	[FrontNO,MaxFNO] = NDSort(PopObj,k);
    
    % 选择前MaxFNO个前沿中的所有解
    Next = find(FrontNO<=MaxFNO);
    
    % 目标值归一化处理
    Pmin = min(PopObj,[],1) + 1e-6;  % 最小值（加小量避免除零错误）
    Pmax = max(PopObj,[],1);          % 最大值
    
    % 如果最大值大于最小值，则进行归一化
    if Pmax > Pmin
        PopObj = (PopObj-repmat(Pmin,size(PopObj,1),1))./repmat(Pmax-Pmin,size(PopObj,1),1);
    end
    
    %% 环境选择
    % 使用LastSelection函数从候选解中选择k个解
    % 参数说明：
    %   PopObj(Next,:): 候选解的目标值
    %   ismember(Next,find(FrontNO<MaxFNO)): 标记哪些解属于前MaxFNO-1个前沿（这些解肯定会被选中）
    %   ceil(sqrt(k)): 雷达网格的划分数量
    %   k: 需要选择的解的数量
    Choose = LastSelection(PopObj(Next,:),ismember(Next,find(FrontNO<MaxFNO)),ceil(sqrt(k)),k);
    
    % 根据选择结果获取参考解
    Ref    = Population(Next(Choose));
end
    
function Choose = LastSelection(PopObj,Choose,div,k)
% LastSelection - 基于雷达网格选择部分解决方案
% 输入参数：
%   PopObj: 候选解的目标值矩阵
%   Choose: 初始选择标记向量
%   div: 雷达网格的划分数量
%   k: 需要选择的解的数量
% 输出参数：
%   Choose: 更新后的选择标记向量
    
    %% 识别极端解
    % 使用PBI（基于惩罚的边界交叉）方法计算极端点
    % 这里通过计算每个解到正理想点的距离和角度的乘积来衡量极端性
	[~,Extreme] = min(sqrt(sum(PopObj.^2,2)).*sqrt(1-(1-pdist2(PopObj,ones(1,size(PopObj,2)),'cosine')).^2),[],1);
    
    % 确保极端解被选中
    Choose      = Choose | ismember(1:size(PopObj,1),Extreme);

    %% 计算每个解的收敛性
    % 这里使用目标值的和作为收敛性指标
	Con = sum(PopObj.^1,2).^1;
    Con = Con./max(Con);  % 归一化到[0,1]范围
    
    %% 计算每个解的雷达网格位置
    [Site,RLoc] = RadarGrid(PopObj,div);  % Site是网格索引，RLoc是雷达坐标
    
    % 计算雷达坐标系下各解之间的距离矩阵
    RDis = pdist2(RLoc,RLoc);
    % 将对角线元素设为无穷大（排除自身距离）
    RDis(logical(eye(length(RDis)))) = inf;
    
    % 计算每个网格中的拥挤度
    CrowdG = zeros(1,max(Site));  % 初始化每个网格的拥挤度为0
    temp = tabulate(Site(Choose));  % 统计每个网格中已选中的解数量
    CrowdG(temp(:,1)) = temp(:,2);  % 更新每个网格的拥挤度

    %% 选择k个解
    while sum(Choose) < k
        % 找出未被选中的解
        remainS = find(~Choose);
        
        % 找出未被选中的解所在的网格
        remainG = unique(Site(remainS));
        
        % 找出拥挤度最小的网格
        bestG = CrowdG(remainG) == min(CrowdG(remainG));
        
        % 找出这些网格中的所有未被选中的解
        current = remainS(ismember(Site(remainS),remainG(bestG)));
        
        % 计算适应度：收敛性越好（越小）且与已选中解的距离越远越好
        fitness = 0.1.*size(PopObj,2).*Con(current) - min(RDis(current,Choose),[],2);
        
        % 选择适应度最小的解
        [~,best] = min(fitness);
        
        % 更新选择标记和网格拥挤度
        Choose(current(best)) = true;
        CrowdG(Site(current(best))) = CrowdG(Site(current(best))) + 1;
    end
end