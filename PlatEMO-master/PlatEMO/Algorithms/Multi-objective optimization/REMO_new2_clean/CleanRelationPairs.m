function [XXs, Ls] = CleanRelationPairs(Input, Catalog)
% 构造净化后的关系对：仅使用“好(1)”与“坏(-1)”，剔除所有中间解(0)
% Input  : N×D 决策变量矩阵
% Catalog: N×1 标签向量，值为 -1（坏）, 0（中）, 1（好）
% XXs    : 拼接后的成对输入 (2D 维)
% Ls     : 关系标签，-1（前者差）, 0（不可区分，可选）, 1（前者好）

    G_idx = find(Catalog == 1);   % 好解下标
    B_idx = find(Catalog == -1);  % 坏解下标

    nG = length(G_idx);
    nB = length(B_idx);

    if nG == 0 || nB == 0
        % 极端情况：无好或无坏，返回空
        XXs = [];
        Ls  = [];
        return;
    end

    % 生成好 vs 坏的对：all combinations of G and B
    [Ggrid, Bgrid] = meshgrid(G_idx, B_idx);
    G_grid = Ggrid(:);   % 好解索引
    B_grid = Bgrid(:);   % 坏解索引

    % 拼接输入：好在前 + 坏在前（即 G-B 对 和 B-G 对）
    XXs_G_B = [Input(G_grid, :), Input(B_grid, :)];   % 好-坏，标签 +1
    XXs_B_G = [Input(B_grid, :), Input(G_grid, :)];   % 坏-好，标签 -1

    % 构建标签向量
    Ls_G_B =  ones(size(XXs_G_B, 1), 1);   % +1
    Ls_B_G = -ones(size(XXs_B_G, 1), 1);   % -1

    % 合并
    XXs = [XXs_G_B; XXs_B_G];
    Ls  = [Ls_G_B; Ls_B_G];

    % （可选）若需要少量不可区分对（0标签），可从此处插入，但非必须
    % 此处省略，保持纯净

    % 随机打乱顺序
    rp = randperm(size(XXs, 1));
    XXs = XXs(rp, :);
    Ls  = Ls(rp);
end