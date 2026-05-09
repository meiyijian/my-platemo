function [good_idx, bad_idx, Catalog, confidence, Ref] = HybridPBI_Classification(Population, ratio, varargin)
% REMO_global: Only use global reference vector field score (score_v)
% No label_dyn calculation - ablation study

    N = length(Population);
    M = size(Population(1).obj, 2);
    Nref = get_option(varargin, 'Nref', N);
    k = get_option(varargin, 'k', 6);
    theta = get_option(varargin, 'theta', 5);
    
    PopObj = [Population.objs];
    
    %% Adaptive reference vector field
    if M <= 3 || N < 50
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
    else
        V = AdaptiveReferenceVectors(PopObj, Nref);
    end
    
    %% Dynamic reference solutions selection
    Ref = RefSelect(Population, k);
    Zmin = min(PopObj, [], 1);
    
    %% Calculate score_v (only this is used)
    cosine = 1 - pdist2(PopObj, V, 'cosine');
    [~, ref_idx] = max(cosine, [], 2);
    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        vi = ref_idx(i);
        w = V(vi,:);
        d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);
        proj = Zmin + d1(i) * w;
        d2(i) = norm(PopObj(i,:) - proj);
    end
    PBI_v = d1 + theta * d2;
    score_v = 1 ./ (1 + PBI_v);
    
    %% DIRECTLY use score_v as score_hybrid (no label_dyn)
    score_hybrid = score_v;
    
    %% Confidence (placeholder for compatibility)
    confidence = ones(N, 1);
    
    %% Select good/bad solutions
    [~, idx_sorted] = sort(score_hybrid, 'descend');
    good_num = ceil(N / 4);
    bad_num  = good_num;
    good_idx = idx_sorted(1:good_num);
    bad_idx  = idx_sorted(end-bad_num+1:end);
    
    %% Catalog for compatibility
    Catalog = false(N,1);
    Catalog(good_idx) = true;
end

function val = get_option(args, name, default)
    for i = 1:2:length(args)
        if strcmpi(args{i}, name)
            val = args{i+1};
            return;
        end
    end
    val = default;
end

function V = AdaptiveReferenceVectors(PopObj, Nref)
    M = size(PopObj, 2);
    try
        FrontNo = NDSort(PopObj, 1);
        ParetoIdx = (FrontNo == 1);
        ParetoObj = PopObj(ParetoIdx, :);
        nPareto = size(ParetoObj, 1);
    catch
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end
    
    if nPareto < max(10, Nref/2) || nPareto < 2
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end
    
    Zmin = min(ParetoObj, [], 1);
    Zmax = max(ParetoObj, [], 1);
    range = Zmax - Zmin;
    if any(range < 1e-12)
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end
    ParetoObj_norm = (ParetoObj - Zmin) ./ range;
    
    nClusters = min(Nref, nPareto);
    try
        [~, C] = kmeans(ParetoObj_norm, nClusters, 'MaxIter', 100, 'Replicates', 5, 'EmptyAction', 'singleton');
        if size(C,1) < 1
            error('Empty clusters');
        end
    catch
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end
    
    if size(C,1) < Nref
        repTimes = ceil(Nref / size(C,1));
        C = repmat(C, repTimes, 1);
        C = C(1:Nref, :);
    end
    
    V = C .* range + Zmin;
    V = V ./ vecnorm(V, 2, 2);
end
