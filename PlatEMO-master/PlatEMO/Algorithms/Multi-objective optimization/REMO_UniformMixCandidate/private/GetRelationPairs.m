function [XXs,Ls] = GetRelationPairs(Input,Catalog)
% 构建关系对数据：将解两两配对，生成训练关系模型所需的数据集
%
% 核心思想：我们不直接预测"这个解好不好"，而是预测"两个解之间是什么关系"
% 这样只需要比较解的优劣关系，比直接预测目标值更容易。
%
% Input   - 所有解的决策变量（解的坐标位置），每行一个解
% Catalog - 每个解的类别：1=好，~1=不好（由PBI方法分类得到）
% XXs     - 所有配对数据（每行是两个解的拼接 [解A, 解B]）
% Ls      - 每对的关系标签：0=同类(等价), 1=A优于B, -1=B优于A

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 找出好解(C1)和不好解(C2)的索引
    C1_index = Catalog == 1;
    C2_index = Catalog ~= 1;  % C2 = 所有不是"好"的解（即"不好"的解）

    % 用 combvec 生成所有可能的配对组合
    % combvec(A,B) = 把A和B中的向量两两组合
    % 例如 combvec([1,2],[3,4]) = [1,3;1,4;2,3;2,4]

    % 四种配对类型：
    C1C1 = combvec(Input(Catalog ==1,:)',Input(Catalog ==1,:)')';
    % C1C1 = 好解 vs 好解 → 标签应为"相等"(0)

    C1C2 = combvec(Input(Catalog ==1,:)',Input(Catalog ~=1,:)')';
    % C1C2 = 好解 vs 不好解(C1在前) → 标签应为"好优于不好"(1)

    C2C1 = combvec(Input(Catalog ~=1,:)',Input(Catalog ==1,:)')';
    % C2C1 = 不好解 vs 好解(C2在前) → 标签应为"不好劣于好"(-1)

    C2C2 = combvec(Input(Catalog ~=1,:)',Input(Catalog ~=1,:)')';
    % C2C2 = 不好解 vs 不好解 → 标签应为"相等"(0)

    % 删除C1C1中自己配对自己的情况（解和自己比没有意义）
    t_ind     = combvec(1:sum(C1_index),1:sum(C1_index));
    t_equ_ind = t_ind(1,:) == t_ind(2,:);  % 找到同一解配对的列
    C1C1(t_equ_ind,:) = [];

    % 同样删除C2C2中自己配对自己的情况
    t_ind     = combvec(1:sum(C2_index),1:sum(C2_index));
    t_equ_ind = t_ind(1,:) == t_ind(2,:);
    C2C2(t_equ_ind,:) = [];

    % 平衡各类别的样本数量，防止模型偏向样本多的类别
    t_num = ceil(size(C1C2,1)/2);  % 以"好-不好"配对数为基准的一半

    if size(C1C1,1) > t_num && size(C2C2,1) > t_num
        % 如果同类配对太多，随机抽取 t_num 个
        C1C1 = C1C1(randperm(size(C1C1,1),t_num),:);
        C2C2 = C2C2(randperm(size(C2C2,1),t_num),:);
    elseif size(C1C1,1) < t_num
        % 如果好-好配对太少，多补充一些不好-不好配对
        C2C2 = C2C2(randperm(size(C2C2,1),t_num*2-size(C1C1,1)),:);
    elseif size(C2C2,1) < t_num
        % 如果不好-不好配对太少，多补充一些好-好配对
        C1C1 = C1C1(randperm(size(C1C1,1),t_num*2-size(C2C2,1)),:);
    end

    % 合并所有配对数据及其对应的标签
    XXs = [C1C1; C2C2; C1C2; C2C1];
    % 标签含义：
    % 0  = 同类（好-好 或 不好-不好）→ 两个解质量"相等"
    % 1  = 好优于不好（C1优于C2）→ 关系为"好"
    % -1 = 不好劣于好（C2劣于C1）→ 关系为"差"
    Ls  = [zeros(size(C1C1,1),1); zeros(size(C2C2,1),1); ones(size(C1C2,1),1); -1.*ones(size(C2C1,1),1)];
end
