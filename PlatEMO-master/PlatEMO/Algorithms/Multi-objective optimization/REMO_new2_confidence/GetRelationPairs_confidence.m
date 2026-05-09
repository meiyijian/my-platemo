function [XXs,Ls,Ws] = GetRelationPairs_confidence(Input,Catalog,confidence)
% 在原 GetRelationPairs 基础上, 同步为每对样本生成权重 Ws
% 权重 = 两端解 confidence 的几何平均, 体现"两端都越确定, 这对关系越可靠"的思想
%
% 输入:
%   Input      - N x D 决策变量矩阵
%   Catalog    - N x 1 logical, 好类(true) / 坏类(false)
%   confidence - N x 1 每个解的置信度 (来自 HybridPBI_Classification)
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

    confidence = confidence(:);

    C1_idx  = find(Catalog == true);
    C2_idx  = find(Catalog ~= true);

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

    % ---- C1C1 (好-好, 标签 0) ----
    [I,J] = ndgrid(1:nC1,1:nC1);
    keep  = I ~= J;
    I = I(keep); J = J(keep);
    C1C1      = [C1_data(I,:), C1_data(J,:)];
    C1C1_conf = sqrt(C1_conf(I) .* C1_conf(J));

    % ---- C2C2 (坏-坏, 标签 0) ----
    [I,J] = ndgrid(1:nC2,1:nC2);
    keep  = I ~= J;
    I = I(keep); J = J(keep);
    C2C2      = [C2_data(I,:), C2_data(J,:)];
    C2C2_conf = sqrt(C2_conf(I) .* C2_conf(J));

    % ---- C1C2 (好-坏, 标签 +1) ----
    [I,J] = ndgrid(1:nC1,1:nC2);
    I = I(:); J = J(:);
    C1C2      = [C1_data(I,:), C2_data(J,:)];
    C1C2_conf = sqrt(C1_conf(I) .* C2_conf(J));

    % ---- C2C1 (坏-好, 标签 -1) ----
    [I,J] = ndgrid(1:nC2,1:nC1);
    I = I(:); J = J(:);
    C2C1      = [C2_data(I,:), C1_data(J,:)];
    C2C1_conf = sqrt(C2_conf(I) .* C1_conf(J));

    % ---- 数量平衡 (与原 GetRelationPairs 逻辑一致, 同步采样权重) ----
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

    XXs = [C1C1; C2C2; C1C2; C2C1];
    Ls  = [zeros(size(C1C1,1),1);
           zeros(size(C2C2,1),1);
           ones(size(C1C2,1),1);
           -1.*ones(size(C2C1,1),1)];
    Ws  = [C1C1_conf(:); C2C2_conf(:); C1C2_conf(:); C2C1_conf(:)];
end
