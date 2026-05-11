function [XXs,Ls] = GetRelationPairs(Input,Catalog)
% GetRelationPairs - 关系对样本生成（原始版本，无权重）
%
% 将分类问题转化为"关系学习"：
% 训练样本 = 两个解的拼接 [Xi, Xj]
% 标签 = 它们之间的关系（谁更好）
%
% 四类关系对：
%   C1C1 (好-好): 标签 0，表示同类
%   C2C2 (坏-坏): 标签 0，表示同类
%   C1C2 (好-坏): 标签 +1，表示前者优于后者
%   C2C1 (坏-好): 标签 -1，表示前者劣于后者
%
% 输入:
%   Input   - N x D 决策变量矩阵
%   Catalog - N x 1 logical，好类(true) / 坏类(false)
% 输出:
%   XXs - n_pair x 2D 关系对样本
%   Ls  - n_pair x 1 关系标签 {-1, 0, +1}

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ============ 分离好类和坏类 ============
    C1_index = Catalog == 1;   % 好类索引
    C2_index = Catalog ~= 1;   % 坏类索引

    %% ============ 生成四类关系对的笛卡尔积 ============
    % C1C1: 好-好对（同类）
    C1C1 = combvec(Input(Catalog ==1,:)',Input(Catalog ==1,:)')';
    % C1C2: 好-坏对（前者优于后者）
    C1C2 = combvec(Input(Catalog ==1,:)',Input(Catalog ~=1,:)')';
    % C2C1: 坏-好对（前者劣于后者）
    C2C1 = combvec(Input(Catalog ~=1,:)',Input(Catalog ==1,:)')';
    % C2C2: 坏-坏对（同类）
    C2C2 = combvec(Input(Catalog ~=1,:)',Input(Catalog ~=1,:)')';

    %% ============ 删除自配对（i==i） ============
    % C1C1 中删除同一个解与自己的配对
    t_ind     = combvec(1:sum(C1_index),1:sum(C1_index));
    t_equ_ind = t_ind(1,:) == t_ind(2,:);
    C1C1(t_equ_ind,:) = [];

    % C2C2 中删除同一个解与自己的配对
    t_ind     = combvec(1:sum(C2_index),1:sum(C2_index));
    t_equ_ind = t_ind(1,:) == t_ind(2,:);
    C2C2(t_equ_ind,:) = [];

    %% ============ 数量平衡 ============
    % 目标：保证"好坏对"和"同类对"数量均衡
    t_num = ceil(size(C1C2,1)/2);

    if size(C1C1,1) > t_num && size(C2C2,1) > t_num
        % 两类同类对都太多，各采样 t_num 个
        C1C1 = C1C1(randperm(size(C1C1,1),t_num),:);
        C2C2 = C2C2(randperm(size(C2C2,1),t_num),:);
    elseif size(C1C1,1) < t_num
        % C1C1 不够，多采样 C2C2 补偿
        C2C2 = C2C2(randperm(size(C2C2,1),t_num*2-size(C1C1,1)),:);
    elseif size(C2C2,1) < t_num
        % C2C2 不够，多采样 C1C1 补偿
        C1C1 = C1C1(randperm(size(C1C1,1),t_num*2-size(C2C2,1)),:);
    end

    %% ============ 合并输出 ============
    % 拼接所有关系对
    XXs = [C1C1;C2C2;C1C2;C2C1];
    % 标签：同类对=0，好坏对=+1/-1
    Ls  = [zeros(size(C1C1,1),1);
           zeros(size(C2C2,1),1);
           ones(size(C1C2,1),1);
           -1.*ones(size(C2C1,1),1)];
end
