function [CatalogCurrent, Ref, views] = LVComputeLabelViews(Population, ratio, varargin)
%LVComputeLabelViews Audit version of the frozen HybridPBI_Classification.
%   [CatalogCurrent, Ref, views] = LVComputeLabelViews(Population, ratio,
%   ...) reproduces the frozen label computation statement-by-statement
%   (including exactly one kmeans call per generation) and additionally
%   returns every audit field required by the Stage-1 MAT contract.
%
%   The function consumes EXACTLY the same random numbers as the frozen
%   HybridPBI_Classification: AdaptiveReferenceVectors -> kmeans once;
%   RefSelect (deterministic); GetOutput_PBI (deterministic bisection).
%   No extra random draw is introduced.
%
%   Outputs:
%     CatalogCurrent - Nx1 logical, the hybrid topQ catalog (frozen output)
%     Ref            - k reference solutions (frozen RefSelect output)
%     views          - struct with all Stage-1 audit fields

    %% ============ Parameter parsing (frozen) ============
    N = length(Population);
    M = size(Population(1).obj, 2);
    Nref = get_option(varargin, 'Nref', N);
    k = get_option(varargin, 'k', 6);
    theta = get_option(varargin, 'theta', 5);
    rGood = get_option(varargin, 'rGood', 0.25);
    if ~isscalar(rGood) || ~isnumeric(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('AdaMaO:InvalidPositiveGroupRatio', ...
            'rGood must be a finite scalar in (0,0.5].');
    end

    PopObj = [Population.objs];  % N x M

    %% ============ Step 1: direction field with audit ============
    if M <= 3 || N < 50
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        DirectionSource = 2;
        FallbackReason  = 'M_LE_3_OR_N_LT_50';
        Front1Count     = NaN;
        ClusterCount    = 0;
    else
        [V, dirAudit] = LVAdaptiveReferenceVectors(PopObj, Nref);
        DirectionSource = dirAudit.DirectionSource;
        FallbackReason  = dirAudit.FallbackReason;
        Front1Count     = dirAudit.Front1Count;
        ClusterCount    = dirAudit.ClusterCount;
    end

    %% ============ Step 2: reference solutions (with index) ============
    [Ref, RefLocalIdx] = LVRefSelectWithIndex(Population, k);
    RefObj = [Ref.objs];

    Zmin = min(PopObj, [], 1);

    %% ============ Step 3: score_v (frozen statements) ============
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

    %% ============ Step 4: dynamic label (with delta / normG audit) ============
    [label_dyn, delta, normG, posRate] = LVGetOutputPBI(PopObj, RefObj);

    %% ============ Step 5: hybrid score ============
    alpha = 1 - ratio;
    score_hybrid = alpha * score_v + (1-alpha) * double(label_dyn);

    %% ============ Step 6: positive group ============
    [~, idx_sorted] = sort(score_hybrid, 'descend');
    good_num = ceil(N * rGood);
    CatalogCurrent = false(N,1);
    CatalogCurrent(idx_sorted(1:good_num)) = true;

    %% ============ Assemble audit views ============
    views = struct();
    views.V                  = V;
    views.DirectionSource    = DirectionSource;
    views.FallbackReason     = FallbackReason;
    views.Front1Count        = Front1Count;
    views.ClusterCount       = ClusterCount;
    views.UniqueDirectionCount = size(unique(round(V*1e8)/1e8,'rows'),1);
    views.RefLocalIdx        = RefLocalIdx(:);
    views.RefObj             = RefObj;
    views.Delta              = delta;
    views.AnchorPositiveRate = posRate;
    views.AnchorNormalizedG  = normG;          % N x 1
    views.AnchorMargin       = 1 - normG;      % N x 1
    views.LabelDyn           = label_dyn;      % N x 1 logical
    views.ScoreV             = score_v;        % N x 1
    views.ScoreHybrid        = score_hybrid;   % N x 1
    views.CatalogCurrent     = CatalogCurrent; % N x 1 logical
    views.ScoreVStd          = std(score_v);
    views.LabelDynStd        = std(double(label_dyn));
    views.EffectiveScaleRatio = alpha*std(score_v) / ...
        ((1-alpha)*std(double(label_dyn)) + eps);
    views.Alpha              = alpha;
    views.Ratio              = ratio;
end

%% ============ Frozen get_option helper ============
function val = get_option(args, name, default)
    for i = 1:2:length(args)
        if strcmpi(args{i}, name)
            val = args{i+1};
            return;
        end
    end
    val = default;
end

%% ============ Adaptive reference vectors with direction audit ============
function [V, dirAudit] = LVAdaptiveReferenceVectors(PopObj, Nref)
%LVAdaptiveReferenceVectors Frozen AdaptiveReferenceVectors + audit.
%   Keeps the exact statement order of the frozen implementation; kmeans is
%   still called at most once. Returns DirectionSource/FallbackReason/
%   Front1Count/ClusterCount.

    M = size(PopObj, 2);
    dirAudit = struct('DirectionSource',0,'FallbackReason','', ...
        'Front1Count',NaN,'ClusterCount',0);

    try
        FrontNo = NDSort(PopObj, 1);
        ParetoIdx = (FrontNo == 1);
        ParetoObj = PopObj(ParetoIdx, :);
        nPareto = size(ParetoObj, 1);
    catch
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        dirAudit.DirectionSource = 5;   % UNIFORM_NDSORT_FAILURE
        dirAudit.FallbackReason  = 'NDSORT_EXCEPTION';
        return;
    end
    dirAudit.Front1Count = nPareto;

    if nPareto < max(10, Nref/2) || nPareto < 2
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        dirAudit.DirectionSource = 3;   % UNIFORM_FRONT_TOO_SMALL
        dirAudit.FallbackReason  = 'FRONT1_LT_THRESHOLD';
        return;
    end

    Zmin = min(ParetoObj, [], 1);
    Zmax = max(ParetoObj, [], 1);
    range = Zmax - Zmin;
    if any(range < 1e-12)
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        dirAudit.DirectionSource = 4;   % UNIFORM_ZERO_RANGE
        dirAudit.FallbackReason  = 'OBJECTIVE_RANGE_LT_1E12';
        return;
    end
    ParetoObj_norm = (ParetoObj - Zmin) ./ range;

    nClusters = min(Nref, nPareto);
    try
        [~, C] = kmeans(ParetoObj_norm, nClusters, ...
                       'MaxIter', 100, 'Replicates', 5, ...
                       'EmptyAction', 'singleton');
        if size(C,1) < 1
            error('聚类返回空中心');
        end
    catch
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        dirAudit.DirectionSource = 6;   % UNIFORM_KMEANS_FAILURE
        dirAudit.FallbackReason  = 'KMEANS_EXCEPTION';
        return;
    end
    dirAudit.ClusterCount = size(C,1);

    if size(C,1) < Nref
        repTimes = ceil(Nref / size(C,1));
        C = repmat(C, repTimes, 1);
        C = C(1:Nref, :);
    end

    V = C .* range + Zmin;
    V = V ./ vecnorm(V, 2, 2);
    dirAudit.DirectionSource = 1;   % ND_KMEANS
    dirAudit.FallbackReason  = 'NONE';
end

%% ============ GetOutput_PBI with delta / normG audit ============
function [Output, delt_final, normG, rate_final] = LVGetOutputPBI(Pop, Ref)
%LVGetOutputPBI Frozen GetOutput_PBI adaptive bisection + audit.
%   Additional outputs: delt_final (the delta used for the final split),
%   normG (Nx1 normalized PBI per solution) and rate_final.

    delt_l = -20;
    delt_u = 20;
    r = 0;
    Output = true(size(Pop,1),1);
    normG  = zeros(size(Pop,1),1);
    delt_final = NaN;
    rate_final = 0;

    while r>0.7 || r<0.3
        delt_c = (delt_l + delt_u)/2;
        if abs(delt_l-delt_u)<1e-1
            break;
        end
        [l, r, g] = LVSplitData(Pop, Ref, delt_c);
        Output     = l;
        normG      = g;
        delt_final = delt_c;
        rate_final = r;
        if r > 0.7
            delt_l = delt_c;
        elseif r < 0.3
            delt_u = delt_c;
        end
    end
end

%% ============ Frozen split_data (also returns per-solution g) ============
function [Output, rate, g_all] = LVSplitData(Pop, Ref, delt)
%LVSplitData Copy of frozen split_data, additionally returning the Nx1
%   normalized PBI value g for every solution (in Pop row order).

    N      = size(Pop,1);
    popind = 1 : N;
    Output = true(N,1);
    g_all  = NaN(N,1);

    [~,ref_index] = max(1-pdist2(Pop,Ref,'cosine'),[],2);

    Z = min(Pop,[],1);

    for i = 1 : size(Ref,1)
        sub_pop    = Pop(ref_index==i,:);
        sub_popind = popind(ref_index==i);
        if isempty(sub_popind)
            continue;
        end

        BOUND = Ref(i,:);
        w = BOUND-Z;
        W = w./sqrt(sum((w).^2,2));

        normW   = sqrt(sum((W).^2,2));
        normP   = sqrt(sum((sub_pop-repmat(Z,size(sub_pop,1),1)).^2,2));
        normR   = sqrt(sum((BOUND-Z).^2,2));

        CosineP = (sum((sub_pop-repmat(Z,size(sub_pop,1),1)).* ...
                  repmat(W,size(sub_pop,1),1),2)./normW./normP)-1e-6;

        g = normP.*CosineP + delt*normP.*sqrt(1-CosineP.^2);
        k = normR;
        g = g./k;

        Output(sub_popind(g>1)) = false;
        g_all(sub_popind)       = g;
    end

    rate = sum(Output == 1)/length(Output);
end
