function RefCell = BuildSubsetReferenceVectors(PopObj, Subsets, cfg)
% BuildSubsetReferenceVectors - 为每个 subset 生成参考向量
%
% 输入：
%   PopObj  - N×M 目标矩阵（用于估计 ideal/nadir）
%   Subsets - 1×K cell，子集目标索引
%   cfg     - .numRef 每个 subset 的参考向量数，默认 10
%             .refType  'ILD'(默认) 或 'unit'
%
% 输出：
%   RefCell - 1×K cell，每个元素是 numRef × |S| 参考向量矩阵
%             已按 ideal/nadir 缩放到 subset 实际值域

    if nargin < 3 || isempty(cfg), cfg = struct(); end
    if ~isfield(cfg, 'numRef') || isempty(cfg.numRef), cfg.numRef = 10; end
    if ~isfield(cfg, 'refType') || isempty(cfg.refType), cfg.refType = 'ILD'; end

    K = numel(Subsets);
    RefCell = cell(1, K);

    for k = 1:K
        S = Subsets{k};
        m = numel(S);
        if m < 1
            RefCell{k} = [];
            continue;
        end
        if m == 1
            RefCell{k} = ones(cfg.numRef, 1);
            continue;
        end

        % 生成单位向量，对应均匀分布的方向
        try
            V = UniformPoint(cfg.numRef, m, cfg.refType);
        catch
            % fallback：随机方向
            V = abs(randn(cfg.numRef, m));
        end
        % 单位化
        V = V ./ max(sqrt(sum(V.^2, 2)), 1e-12);

        RefCell{k} = V;
    end
end
