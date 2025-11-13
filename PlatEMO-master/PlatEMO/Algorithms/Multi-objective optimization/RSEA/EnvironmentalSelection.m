function [Population,Range] = EnvironmentalSelection(Problem,Population,Range,N)
% RSEA算法的环境选择函数
% 输入参数:
%   Problem: 优化问题对象
%   Population: 当前种群
%   Range: 目标空间范围，Range(1,:)为最小值，Range(2,:)为最大值
%   N: 环境选择后保留的种群大小
% 输出参数:
%   Population: 选择后的种群
%   Range: 更新后的目标空间范围

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% 非支配排序
    % FrontNO: 每个解的前沿编号
    % MaxFNO: 为了选择N个解需要考虑的最大前沿编号
    [FrontNO,MaxFNO] = NDSort(Population.objs,N);
    % Next: 前MaxFNO个前沿中的所有解的索引
    Next             = find(FrontNO<=MaxFNO);
    
    %% 环境选择过程
    % 判断是否需要对目标值进行归一化处理
    % 如果目标空间范围的最小值等于最大值，则直接使用原始目标值
    if any(Range(1,:)==Range(2,:))
        % 调用LastSelection函数进行最终选择
        Choose = LastSelection(Problem,Population(Next).objs,ismember(Next,find(FrontNO<MaxFNO)),N,ceil(sqrt(N)));
    else
        % 否则对目标值进行归一化处理，缩放到[0,1]范围
        % (目标值-最小值)/(最大值-最小值)
        Choose = LastSelection(Problem,(Population(Next).objs-repmat(Range(1,:),length(Next),1))./repmat(Range(2,:)-Range(1,:),length(Next),1),ismember(Next,find(FrontNO<MaxFNO)),N,ceil(sqrt(N))); 
    end
    
    % 根据选择结果更新种群
    Population = Population(Next(Choose));
    
    % 更新目标空间范围
    % 更新最小值范围为当前保留范围和新种群目标值的最小值
	Range(1,:) = min([Range(1,:);Population.objs],[],1);
    % 更新最大值范围为当前种群中最优解（第一前沿）的目标值最大值
    Range(2,:) = max(Population(NDSort(Population.objs,1)==1).objs,[],1);
end

function Choose = LastSelection(Problem,PopObj,Choose,N,div)
% 基于雷达网格的环境选择算法
% 输入参数:
%   Problem: 优化问题对象
%   PopObj: 候选解的目标值矩阵
%   Choose: 初始选择标记向量（true表示已选中）
%   N: 需要选择的解的数量
%   div: 雷达网格的划分数量
% 输出参数:
%   Choose: 更新后的选择标记向量

    %% 识别极端解
    % 使用基于PBI（惩罚边界交叉）的方法计算极端点
    % 计算每个解到各坐标轴方向的PBI值，并选择每个方向上PBI值最小的解作为极端解
    % sqrt(sum(PopObj.^2,2))计算每个解到原点的距离
    % pdist2计算余弦距离，衡量解与坐标轴方向的相似性
    [~,Extreme] = min(repmat(sqrt(sum(PopObj.^2,2)),1,size(PopObj,2)).*sqrt(1-(1-pdist2(PopObj,eye(size(PopObj,2)),'cosine')).^2),[],1);
    
    % 确保极端解被选中
    Choose      = Choose | ismember(1:size(PopObj,1),Extreme);

    %% 计算每个解的收敛性指标
    % 使用目标值的欧几里得范数作为收敛性指标（假设目标是最小化）
	Con = sum(PopObj.^2,2).^0.5;
    % 归一化收敛性指标到[0,1]范围
    Con = Con./max(Con);
    
    %% 计算每个解的雷达网格位置
    % Site: 每个解所在的网格索引
    % RLoc: 每个解的雷达坐标
    [Site,RLoc] = RadarGrid(PopObj,div);
    
    % 计算雷达坐标系下各解之间的距离矩阵
    RDis = pdist2(RLoc,RLoc);
    % 将对角线元素设为无穷大（排除解与自身的距离）
    RDis(logical(eye(length(RDis)))) = inf;
    
    % 初始化每个网格的拥挤度计数
    CrowdG = zeros(1,max(Site));
    % 统计每个网格中已选中的解数量
    temp = tabulate(Site(Choose));
    CrowdG(temp(:,1)) = temp(:,2);

    %% 逐个选择解，直到达到N个
    while sum(Choose) < N
        % 找出未被选中的解
        remainS = find(~Choose);
        
        % 找出未被选中的解所在的网格
        remainG = unique(Site(remainS));
        
        % 找出拥挤度最小的网格（优先从稀疏网格中选择解）
        bestG = CrowdG(remainG) == min(CrowdG(remainG));
        
        % 获取拥挤度最小的网格中的所有未选中解
        current = remainS(ismember(Site(remainS),remainG(bestG)));
        
        % 计算自适应平衡参数r，随进化代数变化
        % 进化初期r接近1，更注重多样性；进化后期r接近0，更注重收敛性
        r = 1-(Problem.FE/Problem.maxFE)^2;
        
        % 计算适应度值：综合考虑收敛性和多样性
        % Problem.M*r*Con(current)：收敛性部分，权重随r变化
        % -min(RDis(current,Choose),[],2)：多样性部分，计算到已选解的最小距离
        fitness = Problem.M*r*Con(current) - min(RDis(current,Choose),[],2);
        
        % 选择适应度值最小的解（适应度越小越好）
        [~,best] = min(fitness);
        
        % 更新选择标记和网格拥挤度
        Choose(current(best)) = true;
        CrowdG(Site(current(best))) = CrowdG(Site(current(best))) + 1;
    end
end