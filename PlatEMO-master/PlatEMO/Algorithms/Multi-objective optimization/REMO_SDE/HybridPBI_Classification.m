function [good_idx, bad_idx, Catalog, confidence, Ref] = HybridPBI_Classification(Population, ratio, varargin)
% REMO_SDE: Only use SDE performance indicator scoring
% No label_dyn or score_v - ablation study

    N = length(Population);
    M = size(Population(1).obj, 2);
    k = get_option(varargin, 'k', 6);
    
    PopObj = [Population.objs];
    
    %% Estimate PF shape parameter Lp
    Lp = Shape_Estimate(Population, N);
    
    %% Calculate SDE fitness
    SDE_raw = calFitness_SDE(PopObj, Lp);
    
    %% Normalize SDE to [0,1] as score_hybrid
    SDE_min = min(SDE_raw);
    SDE_max = max(SDE_raw);
    if SDE_max - SDE_min > 1e-10
        score_hybrid = (SDE_raw - SDE_min) / (SDE_max - SDE_min);
    else
        score_hybrid = ones(N, 1) * 0.5;
    end
    
    %% Dynamic reference solutions selection (for compatibility)
    Ref = RefSelect(Population, k);
    
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
