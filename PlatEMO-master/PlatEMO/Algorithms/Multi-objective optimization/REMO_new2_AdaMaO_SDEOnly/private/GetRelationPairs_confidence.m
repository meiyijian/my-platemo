function [XXs,Ls,Ws] = GetRelationPairs_confidence(Input,Catalog,confidence)
% GetRelationPairs_confidence - 在原 GetRelationPairs 基础上，为每个组别关系对生成一致性权重
%
% 权重 = 两端 PBI 双表征一致性分数的几何平均，体现“两端都与融合标签一致时，
% 该组别关系对得到更大训练权重”的实现假设。
%
% 权重计算公式：
%   W(i,j) = sqrt(agreement_i * agreement_j)
%
% 设计动机：
%   在当前分组中，有些解的连续方向场分数与二值锚点标签一致，有些不一致。
%   低一致性样本可能带来较多组别标签噪声；加权训练让模型更关注一致性较高的关系。
%   一致性是启发式权重，不是标签正确概率。
%
% 输入:
%   Input      - N x D 决策变量矩阵
%   Catalog    - N x 1 logical, 正组(true) / 非正组(false)
%   confidence - N x 1 PBI 双表征一致性分数（变量名来自旧接口）
% 输出:
%   XXs - n_pair x 2D 关系对样本
%   Ls  - n_pair x 1 关系标签 {-1, 0, +1}
%   Ws  - n_pair x 1 样本权重 (0~1)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 确保 confidence 是列向量
    confidence = confidence(:);

    %% ============ 分离正组和非正组 ============
    % C1: 正组（Catalog == true）
    % C2: 非正组（Catalog ~= true，包含中间排名和末端排名解）
    C1_idx  = find(Catalog == true);
    C2_idx  = find(Catalog ~= true);

    % 获取对应组的决策变量和 PBI 双表征一致性分数
    C1_data = Input(C1_idx,:);
    C2_data = Input(C2_idx,:);
    C1_conf = confidence(C1_idx);
    C2_conf = confidence(C2_idx);

    nC1 = length(C1_idx);
    nC2 = length(C2_idx);

    % 防御: 若任一类为空, 退化为返回空集 (主程序应避免这种情况)
    if nC1 == 0 || nC2 == 0
        XXs = zeros(0, 2*size(Input,2));
        Ls  = zeros(0,1);
        Ws  = zeros(0,1);
        return;
    end

    %% ============ 生成四类关系对 ============

    % ---- C1C1 (正组-正组, 标签 0，表示同组) ----
    % 生成所有正组解的有序两两组合（不含自配对）
    [I,J] = ndgrid(1:nC1,1:nC1);
    keep  = I ~= J;  % 排除自配对（i==j）
    I = I(keep); J = J(keep);
    C1C1      = [C1_data(I,:), C1_data(J,:)];
    % 权重 = 两端一致性分数的几何平均（sqrt(ab)）
    % 含义：两端与融合标签都较一致时，该关系对得到更大训练权重
    C1C1_conf = sqrt(C1_conf(I) .* C1_conf(J));

    % ---- C2C2 (非正组-非正组, 标签 0，表示同组) ----
    [I,J] = ndgrid(1:nC2,1:nC2);
    keep  = I ~= J;
    I = I(keep); J = J(keep);
    C2C2      = [C2_data(I,:), C2_data(J,:)];
    C2C2_conf = sqrt(C2_conf(I) .* C2_conf(J));

    % ---- C1C2 (正组-非正组, 标签 +1，表示前者属于更高组别) ----
    [I,J] = ndgrid(1:nC1,1:nC2);
    I = I(:); J = J(:);
    C1C2      = [C1_data(I,:), C2_data(J,:)];
    C1C2_conf = sqrt(C1_conf(I) .* C2_conf(J));

    % ---- C2C1 (非正组-正组, 标签 -1，表示前者属于更低组别) ----
    [I,J] = ndgrid(1:nC2,1:nC1);
    I = I(:); J = J(:);
    C2C1      = [C2_data(I,:), C1_data(J,:)];
    C2C1_conf = sqrt(C2_conf(I) .* C1_conf(J));

    %% ============ 数量平衡 ============
    % 目标：保证跨组对和同组对数量大致均衡
    % t_num = 好坏对数量的一半
    t_num = ceil(size(C1C2,1)/2);

    if size(C1C1,1) > t_num && size(C2C2,1) > t_num
        % 两类同类对都太多，各采样 t_num 个
        idx       = randperm(size(C1C1,1),t_num);
        C1C1      = C1C1(idx,:);
        C1C1_conf = C1C1_conf(idx);
        idx       = randperm(size(C2C2,1),t_num);
        C2C2      = C2C2(idx,:);
        C2C2_conf = C2C2_conf(idx);
    elseif size(C1C1,1) < t_num
        % C1C1 不够，多采样 C2C2 补偿
        n2        = min(t_num*2 - size(C1C1,1), size(C2C2,1));
        idx       = randperm(size(C2C2,1),n2);
        C2C2      = C2C2(idx,:);
        C2C2_conf = C2C2_conf(idx);
    elseif size(C2C2,1) < t_num
        % C2C2 不够，多采样 C1C1 补偿
        n1        = min(t_num*2 - size(C2C2,1), size(C1C1,1));
        idx       = randperm(size(C1C1,1),n1);
        C1C1      = C1C1(idx,:);
        C1C1_conf = C1C1_conf(idx);
    end

    %% ============ 合并输出 ============
    % 拼接所有关系对
    XXs = [C1C1; C2C2; C1C2; C2C1];
    % 标签：同组对=0，正组/非正组顺序对=+1/-1
    Ls  = [zeros(size(C1C1,1),1);
           zeros(size(C2C2,1),1);
           ones(size(C1C2,1),1);
           -1.*ones(size(C2C1,1),1)];
    % 权重：两端一致性分数的几何平均
    Ws  = [C1C1_conf(:); C2C2_conf(:); C1C2_conf(:); C2C1_conf(:)];
end
