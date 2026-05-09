function [XXs,Ls] = GetRelationPairs(Input,Catalog)
% GetRelationPairs：生成关系对训练数据
% 将解对按照优劣关系分为4类，用于训练关系分类模型
%
% 输入参数：
%   Input   - 决策变量矩阵，大小为 N x D
%   Catalog - 分类标签，逻辑数组或数值数组（1=好解，0/-1=差解）
%
% 输出参数：
%   XXs - 关系对的决策变量，每行是两个解的拼接 [x_i, x_j]
%   Ls  - 关系对的标签：
%         0 = 同类对（好-好 或 差-差）
%         1 = 好-差对（C1-C2）
%         -1 = 差-好对（C2-C1）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ==================== 步骤1：将解分为两类 ====================
    % C1_index：好解的逻辑索引（标签=1的解）
    C1_index = Catalog == 1;

    % C2_index：差解的逻辑索引（标签!=1的解）
    C2_index = Catalog ~= 1;

    %% ==================== 步骤2：生成四种组合对 ====================
    % combvec：生成两个向量的所有组合
    % Input(Catalog==1,:)'：好解的决策变量转置
    % '：最后再转置回来，使每行是一个配对

    % C1C1：好解-好解配对
    C1C1 = combvec(Input(Catalog ==1,:)',Input(Catalog ==1,:)')';

    % C1C2：好解-差解配对
    C1C2 = combvec(Input(Catalog ==1,:)',Input(Catalog ~=1,:)')';

    % C2C1：差解-好解配对
    C2C1 = combvec(Input(Catalog ~=1,:)',Input(Catalog ==1,:)')';

    % C2C2：差解-差解配对
    C2C2 = combvec(Input(Catalog ~=1,:)',Input(Catalog ~=1,:)')';

    %% ==================== 步骤3：删除自身配对 ====================
    % 对于C1C1和C2C2，删除解与自身的配对

    % t_ind：生成所有可能的索引组合
    t_ind = combvec(1:sum(C1_index),1:sum(C1_index));

    % t_equ_ind：找到自身配对（两个索引相同）
    t_equ_ind = t_ind(1,:) == t_ind(2,:);

    % 删除自身配对
    C1C1(t_equ_ind,:) = [];

    % 同样处理C2C2
    t_ind = combvec(1:sum(C2_index),1:sum(C2_index));
    t_equ_ind = t_ind(1,:) == t_ind(2,:);
    C2C2(t_equ_ind,:) = [];

    %% ==================== 步骤4：平衡各类对的数量 ====================
    % t_num：目标数量（C1C2数量的一半）
    t_num = ceil(size(C1C2,1)/2);

    % 根据各类对的数量进行采样平衡
    if size(C1C1,1) > t_num && size(C2C2,1) > t_num
        % 如果C1C1和C2C2都太多，各采样t_num个
        C1C1 = C1C1(randperm(size(C1C1,1),t_num),:);
        C2C2 = C2C2(randperm(size(C2C2,1),t_num),:);
    elseif size(C1C1,1) < t_num
        % 如果C1C1太少，从C2C2中多采样补充
        C2C2 = C2C2(randperm(size(C2C2,1),t_num*2-size(C1C1,1)),:);
    elseif size(C2C2,1) < t_num
        % 如果C2C2太少，从C1C1中多采样补充
        C1C1 = C1C1(randperm(size(C1C1,1),t_num*2-size(C2C2,1)),:);
    end

    %% ==================== 步骤5：合并所有关系对 ====================
    % XXs：拼接所有关系对
    % 每行是 [x_i, x_j]，其中x_i和x_j是两个解的决策变量
    XXs = [C1C1;C2C2;C1C2;C2C1];

    % Ls：生成对应的标签
    % C1C1 -> 0（好-好，同类）
    % C2C2 -> 0（差-差，同类）
    % C1C2 -> 1（好-差，候选解优于参考解）
    % C2C1 -> -1（差-好，候选解劣于参考解）
    Ls = [zeros(size(C1C1,1),1);zeros(size(C2C2,1),1);ones(size(C1C2,1),1);-1.*ones(size(C2C1,1),1)];
end