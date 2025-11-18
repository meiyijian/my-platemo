function [phase,ct] = Phase_Trans(A2,C,ct,ct_max,phase)
% Phase_Trans - 相变控制函数
% 该函数检测并控制TEA算法的两个阶段之间的转换
% 阶段1：主要优化目标函数，忽略约束条件
% 阶段2：同时优化目标函数和约束条件
%
% 输入参数:
% A2       - 当前进化搜索后的种群结构体数组
% C        - 候选解集合结构体数组
% ct       - 当前连续未改善的迭代次数
% ct_max   - 触发相变的最大未改善次数
% phase    - 当前算法阶段（1=目标优化阶段，2=约束优化阶段）
%
% 输出参数:
% phase    - 更新后的算法阶段
% ct       - 更新后的连续未改善迭代次数

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao_zhang0@163.com)

    if phase == 1
        %% === 阶段1：目标优化阶段的相变检测 ===
        
        % 统计当前种群A2中的可行解数量
        feasible_num   = 0;        % 可行解计数器
        feasible_index = [];       % 可行解索引数组
        index          = 0;        % 相变触发标记
        
        % 逐个检查A2中的解是否满足约束条件
        for i = 1 : length(A2)
            if all(A2(i).cons <= 0)  % 所有约束条件都满足（cons <= 0）
                feasible_num = feasible_num + 1;      % 可行解数量加1
                feasible_index = [feasible_index, i]; % 记录可行解的索引
            end
        end
        
        %% 评估当前阶段是否需要继续或进行相变
        if feasible_num ~= 0
            % === 存在可行解时的评估 ===
            
            % 分别统计候选解C中的可行解和不可行解
            feasible_newindex   = [];   % 候选解中的可行解索引
            feasible_newnum     = 0;    % 候选解中的可行解数量
            infeasible_newindex = [];   % 候选解中的不可行解索引
            
            % 检查候选解的可行性
            for i = 1 : length(C)
                if all(C(i).cons <= 0)  % 候选解为可行解
                    feasible_newnum   = feasible_newnum + 1;
                    feasible_newindex = [feasible_newindex, i];
                else                     % 候选解为不可行解
                    infeasible_newindex = [infeasible_newindex, i];
                end
            end
            
            %% 相变条件判断
            % 条件1：没有新的可行解，或新可行解与现有解集无明显改善
            % 条件2：没有新的不可行解，或新不可行解与现有解集无明显支配关系
            if ((isempty(feasible_newindex) == 0 && ...
                 set_dominate(C(feasible_newindex), A2(feasible_index)) == 3) || ...  % 新可行解无支配关系
                 isempty(feasible_newindex)) && ...  % 或者没有新可行解
               (isempty(infeasible_newindex) || ...  % 或者没有新不可行解
                (isempty(infeasible_newindex) == 0 && ...  % 或者存在新不可行解
                 (set_dominate(C(infeasible_newindex), A2(feasible_index)) == 3 || ...  % 新不可行解无支配关系
                  set_dominate(C(infeasible_newindex), A2(feasible_index)) == 1)))      % 或新不可行解被支配
                
                % 相变条件满足，增加连续未改善计数
                ct = ct + 1;
                if ct >= ct_max
                    index = 1;  % 达到最大未改善次数，标记需要相变
                end
            else
                % 相变条件不满足，重置连续未改善计数
                ct = 0;
            end
        end
        
        %% 执行相变决策
        if (feasible_num ~= 0) && (phase == 1) && (index == 1)
            % 存在可行解且达到相变条件，从阶段1转换到阶段2
            phase = 2;
        else
            % 继续保持阶段1
            phase = 1;
        end
    end
    % 注意：当phase == 2时，函数直接返回，不做任何操作
end

function flag = set_dominate(A,B)
% set_dominate - 支配关系判断函数
% 比较两个解集之间的支配关系
%
% 输入参数:
% A - 解集A的结构体数组，包含.objs字段
% B - 解集B的结构体数组，包含.objs字段
%
% 输出参数:
% flag - 支配关系标志：
%        1: A集合支配B集合
%        2: B集合支配A集合
%        3: A集合与B集合互不支配
%        4: 存在复杂的混合关系

    % === 支配关系判断逻辑 ===
    % flag = 1: one of A dominates B
    % flag = 2: B dominates A
    % flag = 3: A is nondominated with B
    % flag = 4: other

    % 对两个解集进行非支配排序，只保留第一层前沿的解
    [FrontNo, ~] = NDSort(B.objs, inf);  % 对B进行非支配排序
    B = B(FrontNo == 1);                  % 只保留B的第一层前沿解
    
    [FrontNo, ~] = NDSort(A.objs, inf);  % 对A进行非支配排序
    A = A(FrontNo == 1);                  % 只保留A的第一层前沿解
    
    % 提取目标值矩阵
    Aobj = A.objs;    % A集合的目标值矩阵
    Bobj = B.objs;    % B集合的目标值矩阵
    
    Asize = length(A);  % A集合的大小
    Bsize = length(B);  % B集合的大小
    
    % 初始化支配关系索引矩阵
    % 最后一列用于存储每行的综合支配关系
    dominate_index = zeros(Asize, Bsize + 1);
    
    %% 逐对比较A和B集合中解之间的支配关系
    for i = 1 : Asize
        for j = 1 : Bsize
            if all(Aobj(i,:) == Bobj(j,:))
                % A的第i个解与B的第j个解完全相等
                dominate_index(i,j) = 3;
            elseif all(Aobj(i,:) <= Bobj(j,:))
                % A的第i个解支配B的第j个解（所有目标值都更优或相等）
                dominate_index(i,j) = 1;
            elseif all(Aobj(i,:) >= Bobj(j,:))
                % B的第j个解支配A的第i个解（所有目标值都更优或相等）
                dominate_index(i,j) = 2;
            else
                % A的第i个解与B的第j个解互不支配
                dominate_index(i,j) = 3;
            end
        end

        %% 计算A集合第i个解的综合支配关系
        uni = unique(dominate_index(i, 1:Bsize));  % 获取该解与B集合所有解的支配关系类型
        uni = sort(uni);                           % 按升序排序
        
        % 根据支配关系类型确定该解的综合支配关系
        if length(uni) == 1
            % 只有一种支配关系类型
            dominate_index(i, Bsize + 1) = uni;
        elseif length(uni) == 2
            % 有两种支配关系类型
            if all(uni == [1, 3])
                dominate_index(i, Bsize + 1) = 1;  % 主要为支配关系
            elseif all(uni == [2, 3])
                dominate_index(i, Bsize + 1) = 2;  % 主要为被支配关系
            else
                dominate_index(i, Bsize + 1) = 4;  % 复杂混合关系
            end
        else
            % 有三种或更多支配关系类型，视为复杂关系
            dominate_index(i, Bsize + 1) = 4;
        end
    end

    %% 计算两个集合之间的总体支配关系
    uni = unique(dominate_index(:, Bsize + 1))';  % 获取A集合所有解的综合支配关系
    
    % 根据A集合中解的支配关系类型确定集合间的总体关系
    if length(uni) == 1
        % 只有一种综合支配关系类型
        flag = uni;
    elseif length(uni) == 2
        % 有两种综合支配关系类型
        if all(uni == [1, 3])
            flag = 1;  % A集合整体支配B集合
        elseif all(uni == [2, 3])
            flag = 2;  % B集合整体支配A集合
        else
            flag = 4;  % 复杂混合关系
        end
    else
        % 有三种或更多综合支配关系类型，视为复杂关系
        flag = 4;
    end
end