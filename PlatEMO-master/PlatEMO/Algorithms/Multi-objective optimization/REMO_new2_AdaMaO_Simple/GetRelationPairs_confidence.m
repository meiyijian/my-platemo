function [XXs,Ls,Ws] = GetRelationPairs_confidence(Input,Catalog,confidence)
% GetRelationPairs_confidence - 在原 GetRelationPairs 基础上, 同步为每对样本生成权重
%
% 权重 = 两端解 confidence 的软加权：
%   W(i,j) = 0.5 + 0.5 * sqrt(conf_i * conf_j)
%
% 设计动机：
%   在 HPC 分类中，有些解的 score_v 和 label_dyn 信号一致（高置信度），
%   有些矛盾（低置信度）。低置信度样本的关系标签可能是噪声。
%   软加权让模型更关注"确定"的关系，同时权重天然落在 [0.5,1]，
%   不会出现极小权重，因此无需 w_min 下限截断（对应削减文档第4.5节）。
%
% 输入:
%   Input      - N x D 决策变量矩阵
%   Catalog    - N x 1 logical, 好类(true) / 坏类(false)
%   confidence - N x 1 每个解的置信度 (来自 HybridPBI_Classification)
% 输出:
%   XXs - n_pair x 2D 关系对样本
%   Ls  - n_pair x 1 关系标签 {-1, 0, +1}
%   Ws  - n_pair x 1 样本权重 (0.5~1)

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

    %% ============ 分离好类和坏类 ============
    C1_idx  = find(Catalog == true);
    C2_idx  = find(Catalog ~= true);

    % 获取对应类的决策变量和置信度
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

    % ---- C1C1 (好-好, 标签 0，表示同类) ----
    [I,J] = ndgrid(1:nC1,1:nC1);
    keep  = I ~= J;  % 排除自配对（i==j）
    I = I(keep); J = J(keep);
    C1C1      = [C1_data(I,:), C1_data(J,:)];
    % 权重 = 0.5 + 0.5*两端置信度的几何平均（软加权，落在 [0.5,1]）
    C1C1_conf = 0.5 + 0.5*sqrt(C1_conf(I) .* C1_conf(J));

    % ---- C2C2 (坏-坏, 标签 0，表示同类) ----
    [I,J] = ndgrid(1:nC2,1:nC2);
    keep  = I ~= J;
    I = I(keep); J = J(keep);
    C2C2      = [C2_data(I,:), C2_data(J,:)];
    C2C2_conf = 0.5 + 0.5*sqrt(C2_conf(I) .* C2_conf(J));

    % ---- C1C2 (好-坏, 标签 +1，表示前者优于后者) ----
    [I,J] = ndgrid(1:nC1,1:nC2);
    I = I(:); J = J(:);
    C1C2      = [C1_data(I,:), C2_data(J,:)];
    C1C2_conf = 0.5 + 0.5*sqrt(C1_conf(I) .* C2_conf(J));

    % ---- C2C1 (坏-好, 标签 -1，表示前者劣于后者) ----
    [I,J] = ndgrid(1:nC2,1:nC1);
    I = I(:); J = J(:);
    C2C1      = [C2_data(I,:), C1_data(J,:)];
    C2C1_conf = 0.5 + 0.5*sqrt(C2_conf(I) .* C1_conf(J));

    %% ============ 数量平衡 ============
    t_num = ceil(size(C1C2,1)/2);

    if size(C1C1,1) > t_num && size(C2C2,1) > t_num
        idx       = randperm(size(C1C1,1),t_num);
        C1C1      = C1C1(idx,:);
        C1C1_conf = C1C1_conf(idx);
        idx       = randperm(size(C2C2,1),t_num);
        C2C2      = C2C2(idx,:);
        C2C2_conf = C2C2_conf(idx);
    elseif size(C1C1,1) < t_num
        n2        = min(t_num*2 - size(C1C1,1), size(C2C2,1));
        idx       = randperm(size(C2C2,1),n2);
        C2C2      = C2C2(idx,:);
        C2C2_conf = C2C2_conf(idx);
    elseif size(C2C2,1) < t_num
        n1        = min(t_num*2 - size(C2C2,1), size(C1C1,1));
        idx       = randperm(size(C1C1,1),n1);
        C1C1      = C1C1(idx,:);
        C1C1_conf = C1C1_conf(idx);
    end

    %% ============ 合并输出 ============
    XXs = [C1C1; C2C2; C1C2; C2C1];
    Ls  = [zeros(size(C1C1,1),1);
           zeros(size(C2C2,1),1);
           ones(size(C1C2,1),1);
           -1.*ones(size(C2C1,1),1)];
    Ws  = [C1C1_conf(:); C2C2_conf(:); C1C2_conf(:); C2C1_conf(:)];
end
