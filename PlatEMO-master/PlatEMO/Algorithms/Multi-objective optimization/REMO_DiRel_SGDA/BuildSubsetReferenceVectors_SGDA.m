function RefCell = BuildSubsetReferenceVectors_SGDA(PopObj, Subsets, cfg)
% BuildSubsetReferenceVectors_SGDA - Reference directions for each subset.

    if nargin < 3 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'numRef', 10);
    cfg = setIfMissing(cfg, 'refType', 'ILD');

    K = numel(Subsets);
    RefCell = cell(1, K);
    for k = 1:K
        S = Subsets{k};
        S = S(S >= 1 & S <= size(PopObj, 2));
        m = numel(S);
        if m < 1
            RefCell{k} = [];
        elseif m == 1
            RefCell{k} = ones(cfg.numRef, 1);
        else
            try
                V = UniformPoint(cfg.numRef, m, cfg.refType);
            catch
                V = abs(randn(cfg.numRef, m));
            end
            RefCell{k} = V ./ max(sqrt(sum(V.^2, 2)), 1e-12);
        end
    end
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
