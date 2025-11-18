function Next = Pop_Reselect(PopObj,PopCon,N)
% Pop_Reselect - 种群重选函数
% 该函数从候选解中选择最优的N个解，基于非支配排序和多样性保持策略
% 适用于多目标优化问题的种群管理
%
% 输入参数:
% PopObj - 候选解的目标值矩阵（每行代表一个解，每个列代表一个目标）
% PopCon - 候选解的约束条件矩阵（每行代表一个解）
% N      - 需要选择的解数量（种群大小）
%
% 输出参数:
% Next   - 选中解的逻辑索引向量（true表示选择该解）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao_zhang0@163.com)

    %% === 数据预处理 ===
    % 非支配排序前的数据标准化处理
    
    % 计算目标值的最小值和最大值
    zmin = min(PopObj);  % 各目标的最小值
    zmax = max(PopObj);  % 各目标的最大值
    
    % 目标值归一化：将所有目标值缩放到[0,1]区间
    PopObj = (PopObj - zmin)./max(zmax - zmin, 10e-10);
    
    % 获取当前算法阶段信息（全局变量）
    global phase
    
    %% === 基于算法阶段的非支配排序 ===
    if phase == 2
        % 阶段2：同时考虑目标函数和约束条件的非支配排序
        % 使用NDSort函数考虑PopCon约束条件
        [FrontNo, MaxFNo] = NDSort(PopObj, PopCon, N);
    else
        % 阶段1：仅考虑目标函数的非支配排序
        % 使用NDSort函数仅基于PopObj进行排序
        [FrontNo, MaxFNo] = NDSort(PopObj, N);
    end
    
    %% === 初步选择：非支配解 ===
    % FrontNo存储每个解的前沿层号（数值越小表示越优）
    % 选择所有非最后一层前沿的解
    Next = FrontNo < MaxFNo;
    
    % Last存储最后一层前沿解的索引（需要进一步筛选）
    Last = find(FrontNo == MaxFNo);
    
    %% === 最后一层前沿解的选择策略 ===
    % 根据前沿层的数量选择不同的处理策略
    
    if MaxFNo == 1
        % === 情况1：只有一个前沿层 ===
        % 使用截断策略（Truncation）从最后一个前沿中选择最均匀分布的解
        
        % Truncation函数返回需要删除的解的标记
        Del = Truncation(PopObj(Last,:), N);
        
        % 在标记数组中设置被删除解的Next为true（将被删除）
        Next(Last(Del)) = true;
    else
        % === 情况2：有多个前沿层 ===
        % 使用距离选择策略（Dis_Selection）选择最优解
        
        % Dis_Selection函数返回需要在Last中选择mu个解的索引
        Choose = Dis_Selection(PopObj, Last, N-sum(Next));
        
        % 在标记数组中设置被选择解的Next为true
        Next(Last(Choose)) = true;
    end
end

function Choose = Dis_Selection(PopObj,Last,mu)
% Dis_Selection - 基于欧氏距离的多样性选择
% 该函数从最后一层前沿中选择分布最均匀的解，避免解的过度聚集
%
% 输入参数:
% PopObj - 所有候选解的目标值矩阵（已标准化）
% Last   - 最后一层前沿解的索引向量
% mu     - 需要从Last中选择的解数量
%
% 输出参数:
% Choose - 被选中解在Last中的相对索引

    N = size(PopObj,1);  % 总的候选解数量
    
    %% === 计算解之间的距离矩阵 ===
    % 初始化距离矩阵（对角线为无穷大）
    Distance = inf(N);
    
    % 逐对计算所有解之间的欧氏距离
    for i = 1 : N
        for j = [1:i-1,i+1:N]  % 跳过对角线元素（i==j）
            % 计算目标空间中的欧氏距离
            Distance(i,j) = norm(PopObj(i,:) - PopObj(j,:), 2);
        end
    end
    
    %% === 多样性评估 ===
    % 对每行的距离进行排序
    Distance = sort(Distance, 2);
    
    % 计算多样性指标D：距离越大，多样性越好
    % 使用公式D = 1/(d_min + 2)，其中d_min是最近邻居的距离
    D = 1 ./ (Distance(:,1) + 2);
    
    % 只考虑最后一层前沿的解
    D = D(Last);
    
    %% === 选择最优解 ===
    % 按多样性指标降序排序，选择多样性最好的mu个解
    [~, index] = sort(D);
    Choose = index(1:mu);  % 选择前mu个解的索引
end

function Del = Truncation(PopObj,K)
% Truncation - 截断选择算法
% 当解的数量超过目标数量时，使用截断策略选择最均匀分布的解
%
% 输入参数:
% PopObj - 需要截断的解的目标值矩阵
% K      - 最终需要的解数量
%
% 输出参数:
% Del    - 需要删除的解的标记（布尔向量，true表示删除）

    %% 选择部分解通过截断策略
    [N,~] = size(PopObj);  % N是当前解的总数
    
    %% === 计算解之间的距离矩阵 ===
    % 初始化距离矩阵，对角线元素为无穷大
    Distance = inf(N);
    
    % 逐对计算所有解之间的欧氏距离
    for i = 1 : N
        for j = 1 : N
            % 在标准化后的目标空间中计算距离
            Distance(i,j) = norm(PopObj(i,:) - PopObj(j,:), 2);
        end
    end
    
    %% === 截断算法实现 ===
    % 将对角线元素设为无穷大，避免自己与自己比较
    Distance(logical(eye(length(Distance)))) = inf;
    
    % Del是一个布尔向量，true表示该解仍然存在
    Del = true(1, N);
    
    % 循环删除距离其他解最近的解，直到达到目标数量
    while sum(Del) > K
        % 找到当前还存在的解
        Remain = find(Del);
        
        % 对这些解的距离矩阵进行行排序（按距离升序）
        Temp = sort(Distance(Remain, Remain), 2);
        
        % 对排序后的距离矩阵按第一列进行字典排序
        [~, Rank] = sortrows(Temp);
        
        % 删除排序后第一个解（距离其他解最近的解）
        % 这种方法优先保留分布更均匀的解
        Del(Remain(Rank(1))) = false;
    end
end