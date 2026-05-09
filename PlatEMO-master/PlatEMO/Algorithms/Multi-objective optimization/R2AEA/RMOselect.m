function Next = RMOselect(Problem, Ref, Input, wmax, Smodel)
% RMOselect：关系模型引导选择（Relation Model guided Selection）
% 第二阶段：使用训练好的关系分类模型选择高质量的解
%
% 输入参数：
%   Problem - 问题对象
%   Ref     - 参考解（从存档中选出的代表性解）
%   Input   - 当前种群的决策变量
%   wmax    - 代理模型最大评估次数
%   Smodel  - 训练好的关系模型结构体：
%             Smodel.X - 原始决策变量
%             Smodel.Y - 分类标签（1=好解，0/-1=差解）
%             Smodel.mp_struct - 归一化结构
%             Smodel.net - 训练好的神经网络
%
% 输出参数：
%   Next    - 选出的高质量解的决策变量

%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ==================== 步骤1：生成初始候选解 ====================
    % OperatorGA：遗传算子（交叉和变异）
    % [Input; Ref.decs]：将当前种群和参考解的决策变量拼接
    % {1, 15, 1, 5}：GA算子参数
    %   参数1=1：使用模拟二进制交叉（SBX）
    %   参数2=15：交叉分布指数
    %   参数3=1：使用多项式变异
    %   参数4=5：变异分布指数
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});

    i = 0;  % 计数器：记录已评估的解的数量

    % alpha和beta：性能得分和不确定性得分的权重
    % 在当前版本中都设置为1，表示同等重要
    alpha = 1;  % 性能得分权重
    beta = 1;   % 不确定性得分权重

    %% ==================== 步骤2：迭代选择高质量解 ====================
    % while循环：持续选择直到达到最大评估次数wmax
    while i < wmax
        % model_select：使用关系模型对候选解进行评分和排序
        % 返回值：
        %   sorted_index - 按综合得分排序后的索引
        %   scores - 各候选解的性能得分
        [sorted_index, scores] = model_select(Smodel, Next, alpha, beta);

        % 选择得分最高的length(Ref)个解作为新的输入
        % sorted_index(1:length(Ref))：取前k个最高得分的索引
        Input = Next(sorted_index(1:length(Ref)), :);

        % 使用选出的优秀解和参考解生成新的候选解
        Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});

        % 更新计数器
        i = i + size(Next, 1);
    end

    %% ==================== 步骤3：最终选择 ====================
    % 对最终的候选解进行评分
    [~, selectscores, scores] = model_select(Smodel, Next, alpha, beta);

    % 如果没有足够多的高置信度好解（得分>3.9的不足4个）
    % 则只保留得分最高的2个解
    if sum(scores > 3.9) < 4
        [~, ind] = sort(selectscores, 'descend');  % 按综合得分降序排序
        Next = Next(ind(1:2), :);  % 保留前2个
    end
end

function [ind, selectscores, scores] = model_select(Smodel, Next, alpha, beta)
% model_select：使用关系模型对候选解进行评分和排序
% 核心思想：计算每个候选解与好解和差解的关系，综合评估其质量
%
% 输入参数：
%   Smodel - 训练好的关系模型
%   Next   - 候选解矩阵
%   alpha  - 性能得分权重
%   beta   - 不确定性得分权重
%
% 输出参数：
%   ind          - 按综合得分排序后的索引
%   selectscores - 综合得分（性能得分 - 不确定性得分）
%   scores       - 性能得分

    %% ========== 步骤1：准备数据 ==========
    % model_x：原始决策变量
    model_x = Smodel.X;

    % C1_data：好解的决策变量（标签=1的解）
    % Smodel.Y==1：逻辑索引，选择标签为1的行
    C1_data = model_x(Smodel.Y == 1, :);

    % C2_data：差解的决策变量（标签!=1的解）
    % Smodel.Y~=1：逻辑索引，选择标签不为1的行
    C2_data = model_x(Smodel.Y ~= 1, :);

    % C1_num/C2_num：好解/差解的数量
    C1_num = size(C1_data, 1);
    C2_num = size(C2_data, 1);

    % Next_num：候选解的数量
    Next_num = size(Next, 1);

    % scores：性能得分数组
    scores = zeros(Next_num, 1);

    %% ========== 步骤2：生成测试数据对 ==========
    % all_testdata：存储所有测试数据对
    % 每个候选解需要与所有好解和差解配对
    % 配对方式：C1_Xi, Xi_C1, C2_Xi, Xi_C2（共4种）
    % 每行是两个解的决策变量拼接 [x_i, x_j]
    all_testdata = zeros(2 * (C1_num + C2_num) * Next_num, 2 * size(C1_data, 2));

    for i = 1:Next_num
        % original：当前候选解在all_testdata中的起始行索引
        original = (i - 1) * 2 * (C1_num + C2_num);

        % Xi：将当前候选解复制C1_num次，便于与好解配对
        Xi = repmat(Next(i, :), size(C1_data, 1), 1);

        % C1_Xi：好解在前，候选解在后
        all_testdata(original + 1:original + C1_num, :) = [C1_data, Xi];

        % Xi_C1：候选解在前，好解在后
        all_testdata(original + C1_num + 1:original + 2 * C1_num, :) = [Xi, C1_data];

        % Xi：将当前候选解复制C2_num次，便于与差解配对
        Xi = repmat(Next(i, :), size(C2_data, 1), 1);

        % C2_Xi：差解在前，候选解在后
        all_testdata(original + 2 * C1_num + 1:original + 2 * C1_num + C2_num, :) = [C2_data, Xi];

        % Xi_C2：候选解在前，差解在后
        all_testdata(original + 2 * C1_num + C2_num + 1:original + 2 * (C1_num + C2_num), :) = [Xi, C2_data];
    end

    %% ========== 步骤3：使用关系模型预测 ==========
    % mapminmax('apply', ...)：应用之前训练时的归一化结构
    % 对新的测试数据使用相同的归一化参数
    TestIn_nor = mapminmax('apply', all_testdata', Smodel.mp_struct)';

    % Smodel.net(TestIn_nor')：使用训练好的神经网络进行预测
    % 返回每个数据对属于各类别的概率
    % pre_out：预测结果，每行3个概率值 [P(好), P(等), P(差)]
    pre_out = Smodel.net(TestIn_nor')';

    %% ========== 步骤4：计算每个候选解的得分 ==========
    for i = 1:Next_num
        % C_SCORE：得分数组
        % C_SCORE(1)：性能得分（候选解优于好解的程度）
        % C_SCORE(2)：不确定性得分（预测的不确定性，用熵表示）
        C_SCORE = zeros(1,2);
        original = (i-1)*2*(C1_num+C2_num);

        %% --- 与好解（C1）的关系 ---
        % pre_C1Xi：候选解与好解配对的平均预测概率
        % sum(...,1)：按列求和，./C1_num：求平均
        pre_C1Xi = sum(pre_out(original+1:original+C1_num,:),1)./C1_num;

        % 性能得分更新：
        % 0.5*pre_C1Xi(2)：相等的概率权重为0.5
        % +pre_C1Xi(3)：候选解优于好解的概率（正向贡献）
        % -pre_C1Xi(1)：候选解劣于好解的概率（负向贡献）
        C_SCORE(1) = C_SCORE(1) + (0.5*pre_C1Xi(2)+pre_C1Xi(3)-pre_C1Xi(1));

        % 不确定性得分更新：
        % -sum(P.*log2(P))：计算信息熵，熵越高不确定性越大
        C_SCORE(2) = C_SCORE(2) - sum(pre_C1Xi.*log2(pre_C1Xi));

        %% --- 与好解（C1）的反向关系 ---
        pre_XiC1 = sum(pre_out(original+1+C1_num:original+C1_num*2,:),1)./C1_num;
        C_SCORE(1) = C_SCORE(1) + (0.5*pre_XiC1(2) + pre_XiC1(1)-pre_XiC1(3));
        C_SCORE(2) = C_SCORE(2) - sum(pre_XiC1.*log2(pre_XiC1));

        %% --- 与差解（C2）的关系 ---
        pre_C2Xi = sum(pre_out(original+1+C1_num*2:original+C1_num*2+C2_num,:),1)./C2_num;
        C_SCORE(1) = C_SCORE(1) + (pre_C2Xi(3)-0.5*pre_C2Xi(2) -pre_C2Xi(1));
        C_SCORE(2) = C_SCORE(2) + sum(pre_C2Xi.*log2(pre_C2Xi));

        %% --- 与差解（C2）的反向关系 ---
        pre_XiC2 = sum(pre_out(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2,:),1)./C2_num;
        C_SCORE(1) = C_SCORE(1) + (pre_XiC2(1)-0.5*pre_XiC2(2) - pre_XiC2(3));
        C_SCORE(2) = C_SCORE(2) + sum(pre_C2Xi.*log2(pre_C2Xi));

        %% --- 综合得分计算 ---
        % selectscores：综合得分 = 性能得分 - 不确定性得分
        % 优先选择性能好且不确定性低的解
        selectscores(i) = C_SCORE(1) - C_SCORE(2);

        % scores：纯性能得分
        scores(i) = C_SCORE(1);
    end

    % 按综合得分降序排序，返回排序后的索引
    [~, ind] = sort(selectscores, 'descend');
end
