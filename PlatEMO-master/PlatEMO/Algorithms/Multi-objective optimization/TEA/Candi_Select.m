function C = Candi_Select(PopDec,PopObj,PopCon,ObjMSE,ConMSE,Database,mu)
% Candi_Select - 智能候选解选择函数
% 该函数从进化的候选解集中选择最有价值的解进行真实函数评估
% 使用多种筛选策略：重复解检测、基于PDPD排序的非支配选择、欧氏距离多样性保持
%
% 输入参数:
% PopDec  - 候选解的设计变量矩阵 (N x D)，N为候选解数量，D为变量维度
% PopObj  - 候选解的目标值预测矩阵 (N x M)，M为目标函数个数
% PopCon  - 候选解的约束值预测矩阵 (N x C)，C为约束条件个数
% ObjMSE  - 目标函数预测的均方误差矩阵 (N x M)
% ConMSE  - 约束条件预测的均方误差矩阵 (N x C)
% Database - 当前数据库中所有已评估解的结构体
% mu      - 需要选择的候选解数量
%
% 输出参数:
% C       - 被选中的候选解设计变量矩阵 (mu x D)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao_zhang0@163.com)

    %% 步骤1: 排除数据库中已存在的重复解
    % 使用ismember函数检测候选解中哪些解在数据库中已存在
    index = ismember(PopDec,Database.decs,'rows');
    
    % 如果所有候选解都是重复的，直接返回空集
    if sum(index) == size(PopDec,1)
        C_ = [];
    else
        % 保留非重复的候选解进行进一步筛选
        index_ = Selection(PopObj(~index,:),ObjMSE(~index,:),PopCon(~index,:),ConMSE(~index,:),Database,mu);
        index  = find(~index);  % 获取非重复候选解的原始索引
        C_     = PopDec(index(index_),:);  % 提取被选中的解
    end
    
    %% 步骤2: 欧氏距离筛选，避免选择距离过近的解
    % 确保选择的解之间保持足够的空间距离，提高多样性
    C = [];
    for i = 1 : size(C_,1)
        % 计算当前解与数据库中所有解的欧氏距离
        dist2 = pdist2(real(C_(i,:)),real(Database.decs));
        % 如果最小距离大于阈值（1e-5），则保留该解
        if min(dist2) > 1e-5
            C = [C;C_(i,:)];
        end
    end
end

function index = EucDistance_Select(PopObj,ALL_Obj)
% EucDistance_Select - 基于欧氏距离的选择策略
% 该函数从候选解集中选择与参考集距离最远的解，增强多样性
%
% 输入参数:
% PopObj  - 候选解的目标值矩阵
% ALL_Obj - 参考解集的目标值矩阵
%
% 输出参数:
% index   - 被选中候选解的索引

    N1 = size(PopObj,1);  % 候选解数量
    N2 = size(ALL_Obj,1); % 参考解数量
    Distance = zeros(N1,N2);  % 初始化距离矩阵

    %% 计算候选解与参考解之间的欧氏距离
    for i = 1 : N1
        for j = 1 : N2
            % 计算目标空间中两点间的欧氏距离
            Distance(i,j) = norm(PopObj(i,:)-ALL_Obj(j,:),2);    
        end
    end
    
    %% 距离分析：每个候选解到其最近参考解的距离
    % 对每行进行排序，只保留最小的距离值
    Distance  = sort(Distance,2);
    Distance  = Distance(:,1);  % 提取每个候选解的最小距离
    
    %% 选择策略：选择最小距离最大的候选解
    % 这意味着该解距离参考集最远，具有最高的多样性价值
    [~,index] = max(Distance);
end

function Next = Selection(PopObj,ObjMSE,PopCon,ConMSE,Database,mu)
% Selection - 多层次候选解筛选主函数
% 该函数实现三层筛选机制：数据准备、参考集构建、最终选择
%
% 输入参数:
% PopObj  - 候选解的目标值矩阵
% ObjMSE  - 目标函数预测误差
% PopCon  - 候选解的约束值矩阵  
% ConMSE  - 约束条件预测误差
% Database - 数据库
% mu      - 目标选择数量
%
% 输出参数:
% Next    - 被选中解的逻辑索引标记

    %% 数据层：数据预处理和标准化
    % 收集当前数据库中的所有解信息
    ALL_Obj = Database.objs;    % 数据库中所有解的目标值
    ALL_Con = Database.cons;    % 数据库中所有解的约束值
    
    % 全局数据标准化：合并候选解和数据库解进行统一归一化
    zmin    = min([ALL_Obj;PopObj]);  % 全局最小值
    zmax    = max([ALL_Obj;PopObj]);  % 全局最大值
    
    % 目标值标准化：避免不同目标函数数值范围差异的影响
    ALL_Obj = (ALL_Obj - zmin)./max(zmax - zmin,10e-10);
    PopObj  = (PopObj - zmin)./max(zmax - zmin,10e-10);
    
    % 预测误差标准化：考虑目标值缩放的影响
    ObjMSE  = ObjMSE./(max(zmax - zmin,10e-10).^2);

    %% 参考集层：根据算法阶段构建不同的参考解集
    global phase NI
    
    if phase == 2
        % 阶段2：约束多目标优化阶段
        num = 0;
        % 统计数据库中可行解的数量
        for i= 1 : length(Database)
            if all(Database(i).cons <= 0)  % 检查是否满足所有约束
                num = num + 1;
            end
        end
        
        % 基于约束处理的非支配排序
        [FrontNo,~] = NDSort(ALL_Obj,ALL_Con,inf);
        
        % 根据可行解比例选择参考集
        if num > NI  % 如果可行解数量超过种群大小
            ALL_Obj = ALL_Obj(FrontNo == 1,:);  % 只选择第一前沿解
        else
            % 选择足够数量的解以保持种群多样性
            i = 1;
            Next = FrontNo == i;
            while sum(Next) <= NI
                Next(FrontNo == i) = true;
                i = i + 1;
            end
            ALL_Obj = ALL_Obj(Next,:);
        end
    else
        % 阶段1：无约束多目标优化阶段
        [FrontNo,~] = NDSort(ALL_Obj,inf);
        ALL_Obj     = ALL_Obj(FrontNo == 1,:);  % 只选择第一前沿解
    end

    %% 选择层：基于PDPD排序的最终筛选
    % 根据算法阶段选择不同的排序策略
    if phase == 2
        % 阶段2：考虑约束条件的PDPD排序
        [FrontNo,MaxFNo] = NDSort_PDPD(PopObj,ObjMSE,PopCon,ConMSE,mu);
    else
        % 阶段1：仅考虑目标函数的PDPD排序
        [FrontNo,MaxFNo] = NDSort_PDPD(PopObj,ObjMSE,mu);
    end
    
    % 首先选择所有非最后一层前沿的解
    Next = FrontNo < MaxFNo;
    Last = find(FrontNo == MaxFNo);  % 找到最后一层前沿解的索引
    
    % 处理最后一层前沿解的策略
    if length(Last) == mu - sum(Next)
        % 如果最后一层前沿解数量正好等于需要的数量，全部选择
        Next(Last) = true;
    elseif length(Last) > mu - sum(Next)
        % 如果最后一层前沿解数量过多，使用距离选择策略
        ALL_Obj = [ALL_Obj;PopObj(Next,:)];  % 将已选择的解加入参考集
        
        % 逐个选择剩余的解，保持多样性和均匀分布
        for i = 1 : mu - sum(Next)
            % 选择距离当前参考集最远的解
            index             = EucDistance_Select(PopObj(Last,:),ALL_Obj);
            Next(Last(index)) = true;  % 标记该解为选中
            ALL_Obj           = [ALL_Obj;PopObj(Last(index),:)];  % 更新参考集
            Last(index)       = [];    % 从候选集中移除该解
        end
    end
end