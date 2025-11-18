function [PopDec,PopObj,PopCon,ObjMSE,ConMSE] = Evo_Search(P,wmax,Model_obj,Model_con,Problem)
% Evo_Search - 进化搜索引擎主函数
% 该函数实现基于代理模型的进化搜索过程，包含子代生成、模型预测和环境选择
%
% 输入参数:
% P         - 当前种群结构体，包含decs(设计变量)、objs(目标值)、cons(约束值)
% wmax      - 进化搜索的最大迭代次数
% Model_obj - 目标函数的DACE代理模型集合
% Model_con - 约束条件的DACE代理模型集合  
% Problem   - 优化问题定义，包含边界、维度等信息
%
% 输出参数:
% PopDec    - 进化后的设计变量矩阵
% PopObj    - 对应的目标值矩阵
% PopCon    - 对应的约束值矩阵
% ObjMSE    - 目标函数预测的均方误差矩阵
% ConMSE    - 约束条件预测的均方误差矩阵

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao_zhang0@163.com)

    %% 初始化进化搜索
    PopDec = P.decs;  % 当前种群的设计变量
    PopObj = P.objs;  % 当前种群的目标值
    PopCon = P.cons;  % 当前种群的约束值
    ObjMSE = zeros(Problem.N,Problem.M);  % 初始化目标函数预测误差矩阵
    ConMSE = zeros(Problem.N,size(PopCon,2));  % 初始化约束条件预测误差矩阵
    w = 1;  % 进化迭代计数器
    
    %% 进化主循环
    while w <= wmax
        drawnow();  % 保持界面响应
        
        %% 子代生成：通过遗传算子产生新解
        OffDec = OperatorGA(Problem,PopDec);
        
        %% 子代预测：使用代理模型快速评估子代解
        [OffObj,Off_ObjMSE,OffCon,Off_ConMSE] = model_predict(Model_obj,Model_con,OffDec);
        
        %% 种群合并：当前种群与子代合并
        PopDec = [PopDec;OffDec];
        PopObj = [PopObj;OffObj];
        PopCon = [PopCon;OffCon];
        ObjMSE = [ObjMSE;Off_ObjMSE];
        ConMSE = [ConMSE;Off_ConMSE];
        
        %% 环境选择：从合并种群中选择最优的N个解
        index  = EnvironmentalSelection(PopObj,ObjMSE,PopCon,ConMSE,length(P));
        
        %% 更新种群：保留被选择的解
        PopDec = PopDec(index,:);
        PopObj = PopObj(index,:);
        PopCon = PopCon(index,:);
        ObjMSE = ObjMSE(index,:);
        ConMSE = ConMSE(index,:);
        
        w = w + 1;  % 迭代计数增加
    end
end

function [OffObj,Off_ObjMSE,OffCon,Off_ConMSE] = model_predict(Model_obj,Model_con,OffDec)
% model_predict - 基于DACE代理模型的预测函数
% 该函数对给定的设计变量进行代理模型预测，返回目标值、约束值及其预测误差
%
% 输入参数:
% Model_obj - 目标函数的代理模型集合
% Model_con - 约束条件的代理模型集合
% OffDec    - 待预测的设计变量矩阵
%
% 输出参数:
% OffObj     - 预测的目标值矩阵
% Off_ObjMSE - 目标函数预测的均方误差矩阵
% OffCon     - 预测的约束值矩阵
% Off_ConMSE - 约束条件预测的均方误差矩阵

    global Len_con Len_obj phase
    [N,~]      = size(OffDec);  % 获取子代解的数量
    
    % 初始化预测结果矩阵
    OffObj     = zeros(N,Len_obj);
    OffCon     = zeros(N,Len_con);
    Off_ObjMSE = zeros(N,Len_obj);
    Off_ConMSE = zeros(N,Len_con);
    
    %% 逐个预测子代解的目标值和约束值
    for i = 1 : N
        %% 目标函数预测
        for j = 1 : Len_obj
            % 使用DACE代理模型进行预测，返回预测值、方差和均方误差
            [OffObj(i,j),~,Off_ObjMSE(i,j)] = predictor(OffDec(i,:),Model_obj{j});
        end
        
        %% 约束条件预测（仅在阶段2）
        if phase == 2
            for j = 1 : Len_con
                [OffCon(i,j),~,Off_ConMSE(i,j)] = predictor(OffDec(i,:),Model_con{j});
            end
        end
    end
end

function Next = EnvironmentalSelection(PopObj,ObjMSE,PopCon,ConMSE,N)
% EnvironmentalSelection - 环境选择函数
% 该函数实现基于PDPD排序的环境选择，结合多样性保持策略
%
% 输入参数:
% PopObj  - 合并后种群的目标值矩阵
% ObjMSE  - 目标函数预测误差矩阵
% PopCon  - 合并后种群的约束值矩阵
% ConMSE  - 约束条件预测误差矩阵
% N       - 选择的解数量（种群大小）
%
% 输出参数:
% Next    - 被选择解的逻辑索引标记

    %% 非支配排序前的数据预处理
    zmin   = min(PopObj);  % 计算目标值最小值
    zmax   = max(PopObj);  % 计算目标值最大值
    
    % 目标值标准化：缩放到[0,1]区间
    PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);
    
    % 预测误差标准化：考虑目标值缩放的影响
    ObjMSE = ObjMSE./(max(zmax - zmin,10e-10).^2);
    
    global phase
    if phase == 2
        % 阶段2：考虑约束条件的PDPD排序
        [FrontNo,MaxFNo] = NDSort_PDPD(PopObj,ObjMSE,PopCon,ConMSE,N);
    else
        % 阶段1：仅考虑目标函数的PDPD排序
        [FrontNo,MaxFNo] = NDSort_PDPD(PopObj,ObjMSE,N);
    end

    %% 初步选择：选择所有非最后一层前沿的解
    Next = FrontNo < MaxFNo;
    Last = find(FrontNo == MaxFNo);  % 找到最后一层前沿解的索引

    %% 最后一层前沿解的选择策略
    if MaxFNo == 1
        % 如果只有一层前沿，使用截断策略保持多样性
        Del = Truncation(PopObj(Last,:),N);
        Next(Last(Del)) = true; 
    else
        % 如果有多层前沿，使用距离选择策略
        Choose = Dis_Selection(PopObj,Last,N-sum(Next));
        Next(Last(Choose)) = true;
    end
end

function Choose = Dis_Selection(PopObj,Last,mu)
% Dis_Selection - 基于距离的多样性选择
% 该函数从最后一层前沿中选择分布最均匀的解
%
% 输入参数:
% PopObj - 所有解的目标值矩阵
% Last   - 最后一层前沿解的索引
% mu     - 需要选择的解数量
%
% 输出参数:
% Choose - 被选中解在Last中的相对索引

    N = size(PopObj,1);

    %% 计算目标空间中每两个解之间的欧氏距离
    for i = 1 : N
        for j = [1:i-1,i+1:N]  % 跳过自己与自己比较
            Distance(i,j) = norm(PopObj(i,:)-PopObj(j,:),2);
        end
    end
    
    %% 计算多样性评估指标D
    % 对每行距离进行排序，只保留最近的邻居距离
    Distance = sort(Distance,2);
    % D = 1/(d_min + 2)，其中d_min是每个解到其最近邻居的距离
    D = 1./(Distance(:,1) + 2);
    % 只考虑最后一层前沿的解
    D = D(Last);
    [~,index] = sort(D);  % 按D值降序排序
    Choose    = index(1:mu);  % 选择前mu个解
end

function Del = Truncation(PopObj,K)
% Truncation - 截断选择函数
% 当解的数量超过目标数量时，使用截断策略选择最均匀分布的解
%
% 输入参数:
% PopObj - 需要截断的解的目标值矩阵
% K      - 最终需要的解数量
%
% 输出参数:
% Del    - 需要删除的解的标记（布尔向量）

    %% 选择部分解通过截断策略
    [N,~] = size(PopObj);
    
    %% 计算解之间的距离矩阵
    Distance = inf(N);
    for i = 1 : N
         for j = 1 : N
            Distance(i,j) = norm(PopObj(i,:) - PopObj(j,:),2);
        end
    end
    
    %% 截断算法实现
    % 将对角线元素设为无穷大，避免自己与自己比较
    Distance(logical(eye(length(Distance)))) = inf;
    Del = true(1,N);
    
    % 循环删除最应该删除的解
    while sum(Del) > K
        % 找到当前还存在的解
        Remain   = find(Del);
        % 对这些解的距离矩阵进行行排序
        Temp     = sort(Distance(Remain,Remain),2);
        % 对排序后的距离矩阵按第一列进行字典排序
        [~,Rank] = sortrows(Temp);
        % 删除排序后第一个解（距离其他解最近的解）
        Del(Remain(Rank(1))) = false;
    end
end