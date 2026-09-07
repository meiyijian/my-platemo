function [XXs,Ls] = GetRelationPairs(Input,Catalog)
%GetRelationPairs 根据 PAQC 分组构造有序解对及三类关系标签。
%   [XXs,Ls] = GetRelationPairs(Input,Catalog) 使用 N×D 决策矩阵 Input
%   和正组标记 Catalog，输出由两个不同解拼接成的样本 [Xi,Xj]。
%   Catalog=true 表示正组 C1，其余为非正组 C2。
%
%   C1-C2 对的标签为 +1，C2-C1 对为 -1，两类同组对为 0。
%   标签描述解所属组别的有序关系，同组解共同使用标签 0。
%   删除自配对后，对同组样本随机抽样，使其总量接近一类跨组样本的数量。
%   XXs 为 n_pair×2D 矩阵，Ls 为 n_pair×1 关系标签向量。

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ============ 分离正组和非正组 ============
    C1_index = Catalog == 1;   % 正组索引
    C2_index = Catalog ~= 1;   % 非正组索引（包含中间排名和末端排名解）

    %% ============ 生成四类关系对的笛卡尔积 ============
    % C1C1: 正组-正组对（同组）
    C1C1 = combvec(Input(Catalog ==1,:)',Input(Catalog ==1,:)')';
    % C1C2: 正组-非正组对（前者属于更高组）
    C1C2 = combvec(Input(Catalog ==1,:)',Input(Catalog ~=1,:)')';
    % C2C1: 非正组-正组对（前者属于更低组）
    C2C1 = combvec(Input(Catalog ~=1,:)',Input(Catalog ==1,:)')';
    % C2C2: 非正组-非正组对（同组）
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
    % 目标：平衡跨组对和同组对的数量
    t_num = ceil(size(C1C2,1)/2);

    if size(C1C1,1) > t_num && size(C2C2,1) > t_num
        % 两类同组对都太多，各采样 t_num 个
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
    % 标签：同组对=0，正组/非正组顺序对=+1/-1
    Ls  = [zeros(size(C1C1,1),1);
           zeros(size(C2C2,1),1);
           ones(size(C1C2,1),1);
           -1.*ones(size(C2C1,1),1)];
end
