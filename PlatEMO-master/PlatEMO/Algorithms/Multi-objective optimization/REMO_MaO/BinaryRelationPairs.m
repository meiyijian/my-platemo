function [XXs, Ls] = BinaryRelationPairs(Input, Catalog)
% BinaryRelationPairs - 构造二元标签的关系对
%
% 输入：
%   Input   : N×D 决策变量矩阵
%   Catalog : N×1 逻辑向量，true 表示好解，false 表示差解
%
% 输出：
%   XXs : 拼接后的样本对，每行是两个解 (2D 维)
%   Ls  : 二元标签 0/1
%         1 表示前者优于后者（[good, bad]）
%         0 表示前者劣于后者（[bad, good]）
%
% 与原 CleanRelationPairs 的区别：
%   - 标签从 ±1 改为 0/1，与新版 onehotconv2 输出 [1,0]/[0,1] 一致
%   - 修复原 RSurrogateAssistedSelection 中 pre_out(:,2) 语义错误的根因

    G_idx = find(Catalog);    % 好解下标
    B_idx = find(~Catalog);   % 差解下标

    nG = length(G_idx);
    nB = length(B_idx);

    if nG == 0 || nB == 0
        XXs = [];
        Ls  = [];
        return;
    end

    % 生成所有 好×差 的组合
    [Ggrid, Bgrid] = meshgrid(G_idx, B_idx);
    G_grid = Ggrid(:);
    B_grid = Bgrid(:);

    % 拼接样本：好在前 + 差在前
    XXs_GB = [Input(G_grid, :), Input(B_grid, :)];   % [good, bad] → 1
    XXs_BG = [Input(B_grid, :), Input(G_grid, :)];   % [bad, good] → 0

    Ls_GB = ones(size(XXs_GB, 1), 1);
    Ls_BG = zeros(size(XXs_BG, 1), 1);

    XXs = [XXs_GB; XXs_BG];
    Ls  = [Ls_GB; Ls_BG];

    % 打乱顺序避免训练时同类相邻
    rp  = randperm(size(XXs, 1));
    XXs = XXs(rp, :);
    Ls  = Ls(rp);
end
