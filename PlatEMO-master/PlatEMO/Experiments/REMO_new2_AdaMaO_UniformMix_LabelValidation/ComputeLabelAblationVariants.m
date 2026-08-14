function out = ComputeLabelAblationVariants(snap, meta)
%ComputeLabelAblationVariants Compute L0..L8 label variants on ONE snapshot.
%   out = ComputeLabelAblationVariants(snap, meta) is a pure offline
%   computation over an immutable Stage-1 snapshot. It never calls
%   Problem.Evaluation and never draws from the production RNG except
%   through the frozen offline-seed rule.
%
%   Outputs (struct):
%     .variantRows - struct array, one row per (variant, replicate):
%                    L0..L5,L7,L8 have 1 row; L6 has 100 rows.
%     .catalogs    - struct with fields L0..L8; each is N x R logical
%                    (R=1 except L6 -> 100).
%     .rankings    - struct with fields L0..L8; each is N x R int32
%                    (full 1:N permutation from LVTopQDeterministic order).
%     .scores      - struct with fields L0..L8; each is N x R double.
%                    L0 score is the binary LabelDyn (Spearman -> NaN).
%     .direction   - struct with fields DirectionSource, Front1Count,
%                    UniqueDirectionCount, Ndir per variant code.
%     .repro       - struct: L3 vs CatalogCurrent check (.ok, .detail).

    N = numel(snap.PopulationEvalID);
    M = meta.M;
    theta = snap.Theta;
    ratio = snap.Ratio;
    rGood = meta.rGood;
    kEff  = snap.kEff;
    Nref  = snap.Nref;

    PopObj   = snap.PopulationObj;
    labelDyn = logical(snap.LabelDyn(:));
    scoreV   = double(snap.ScoreV(:));
    anchorG  = double(snap.AnchorNormalizedG(:));
    anchorMargin = 1 - anchorG;                 % L1 score
    hybridCurrent = (1-ratio)*scoreV + ratio*double(labelDyn);  % L3 score

    snapshotSeed = meta.seed*1000 + snap.SnapshotID;

    [codes, names] = LVVariantTable();

    %% ---------- L0: binary native (natural proportion) ----------
    L0.score   = double(labelDyn);
    L0.catalog = labelDyn;
    [~, ord]   = sortrows([-L0.score(:), (1:N)']);
    L0.ranking = int32(ord);

    %% ---------- L1: anchor margin ----------
    L1.score   = anchorMargin;
    [L1.catalog, ord] = LVTopQDeterministic(anchorMargin, rGood);
    L1.ranking = int32(fullRankOrder(anchorMargin, N));

    %% ---------- L2: ND score (single branch) ----------
    L2.score   = scoreV;
    [L2.catalog, ~] = LVTopQDeterministic(scoreV, rGood);
    L2.ranking = int32(fullRankOrder(scoreV, N));

    %% ---------- L3: current hybrid ----------
    L3.score   = hybridCurrent;
    [L3.catalog, ~] = LVTopQDeterministic(hybridCurrent, rGood);
    L3.ranking = int32(fullRankOrder(hybridCurrent, N));

    %% ---------- L4: fixed 0.5/0.5 hybrid ----------
    L4.score   = 0.5*scoreV + 0.5*double(labelDyn);
    [L4.catalog, ~] = LVTopQDeterministic(L4.score, rGood);
    L4.ranking = int32(fullRankOrder(L4.score, N));

    %% ---------- L5: reverse hybrid ----------
    L5.score   = ratio*scoreV + (1-ratio)*double(labelDyn);
    [L5.catalog, ~] = LVTopQDeterministic(L5.score, rGood);
    L5.ranking = int32(fullRankOrder(L5.score, N));

    %% ---------- L6: shuffled ScoreV (100 replicates) ----------
    L6.score   = zeros(N,100);
    L6.catalog = false(N,100);
    L6.ranking = zeros(N,100,'int32');
    for r = 1:100
        offSeed = snapshotSeed + 6*100 + r;
        saved   = rng;
        rng(offSeed,'twister');
        shuf = scoreV(randperm(N));
        rng(saved);
        s6 = (1-ratio)*shuf + ratio*double(labelDyn);
        L6.score(:,r)   = s6;
        L6.catalog(:,r) = LVTopQDeterministic(s6, rGood);
        L6.ranking(:,r) = int32(fullRankOrder(s6, N));
    end

    %% ---------- L7: uniform directions ----------
    [L7.score, V7, nDir7] = ComputeUniformDirectionScore(PopObj, theta, Nref);
    [L7.catalog, ~] = LVTopQDeterministic(L7.score, rGood);
    L7.ranking = int32(fullRankOrder(L7.score, N));

    %% ---------- L8: reduced ND directions (kEff) ----------
    % Fallback eligibility is taken from Stage 1's recorded decision:
    % if the snapshot already used uniform directions, L8 uses kEff
    % uniform directions as well; otherwise ND directions with kEff.
    if strcmp(snap.FallbackReason,'NONE')
        [L8.score, V8, nDir8, ds8] = ComputeReducedNDDirectionScore( ...
            PopObj, kEff, theta, snapshotSeed + 8*100 + 1);
    else
        [L8.score, V8, nDir8] = ComputeUniformDirectionScore(PopObj, theta, kEff);
        ds8 = directionCodeFromReason(snap.FallbackReason);
    end
    [L8.catalog, ~] = LVTopQDeterministic(L8.score, rGood);
    L8.ranking = int32(fullRankOrder(L8.score, N));

    %% ---------- L3 reproduction check (STOP_REPRODUCTION_FAILURE) ----------
    repro.ok      = isequal(L3.catalog, logical(snap.CatalogCurrent(:)));
    repro.detail  = '';
    if ~repro.ok
        repro.detail = sprintf('L3 catalog differs from CatalogCurrent on %d entries', ...
            nnz(L3.catalog ~= logical(snap.CatalogCurrent(:))));
    end

    %% ---------- direction provenance ----------
    dirProvenance = struct();
    for c = 1:numel(codes)
        code = codes(c);
        switch code
            case {0,1,2,3,4,5,6}
                dirProvenance.(sprintf('L%d',code)) = struct( ...
                    'DirectionSource',snap.DirectionSource, ...
                    'Front1Count',snap.Front1Count, ...
                    'UniqueDirectionCount',snap.UniqueDirectionCount, ...
                    'Ndir',size(snap.V,1));
            case 7
                dirProvenance.L7 = struct( ...
                    'DirectionSource',2, ...   % UNIFORM_LOW_M_OR_N (uniform ILD)
                    'Front1Count',NaN, ...
                    'UniqueDirectionCount',nDir7, ...
                    'Ndir',nDir7);
            case 8
                dirProvenance.L8 = struct( ...
                    'DirectionSource',ds8, ...
                    'Front1Count',snap.Front1Count, ...
                    'UniqueDirectionCount',nDir8, ...
                    'Ndir',nDir8);
        end
    end

    %% ---------- assemble variantRows ----------
    rows = struct('VariantCode',{},'VariantName',{},'Replicate',{}, ...
        'PopulationWidth',{}, ...
        'PositiveCount',{},'PositiveRate',{}, ...
        'ScoreMean',{},'ScoreStd',{},'ScoreMin',{},'ScoreMax',{}, ...
        'CatalogHash',{},'RankingHash',{}, ...
        'DirectionSource',{},'Front1Count',{},'UniqueDirectionCount',{}, ...
        'Ndir',{});
    vars = struct('L0',L0,'L1',L1,'L2',L2,'L3',L3,'L4',L4,'L5',L5, ...
        'L6',L6,'L7',L7,'L8',L8);
    for c = 1:numel(codes)
        code = codes(c);
        nm   = names{c};
        v    = vars.(sprintf('L%d',code));
        R    = size(v.catalog,2);
        prov = dirProvenance.(sprintf('L%d',code));
        for r = 1:R
            cat    = v.catalog(:,r);
            score  = v.score(:,r);
            rankv  = v.ranking(:,r);
            row = struct( ...
                'VariantCode',code,'VariantName',nm,'Replicate',r, ...
                'PopulationWidth',N, ...
                'PositiveCount',sum(cat),'PositiveRate',sum(cat)/N, ...
                'ScoreMean',mean(score),'ScoreStd',std(score), ...
                'ScoreMin',min(score),'ScoreMax',max(score), ...
                'CatalogHash',LVHashString(cat), ...
                'RankingHash',LVHashString(rankv), ...
                'DirectionSource',prov.DirectionSource, ...
                'Front1Count',prov.Front1Count, ...
                'UniqueDirectionCount',prov.UniqueDirectionCount, ...
                'Ndir',prov.Ndir);
            if isempty(rows)
                rows = row;
            else
                rows(end+1) = row; %#ok<AGROW>
            end
        end
    end

    out = struct();
    out.variantRows = rows;
    fn = fieldnames(vars);
    out.catalogs = struct();
    out.rankings = struct();
    out.scores   = struct();
    for i = 1:numel(fn)
        out.catalogs.(fn{i}) = vars.(fn{i}).catalog;
        out.rankings.(fn{i}) = vars.(fn{i}).ranking;
        out.scores.(fn{i})   = vars.(fn{i}).score;
    end
    out.direction   = dirProvenance;
    out.repro       = repro;
end

%% ============ helpers ============
function ord = fullRankOrder(score, N)
%fullRankOrder Full 1:N permutation by (score desc, row asc).
    [~, ord] = sortrows([-score(:), (1:N)']);
end

function code = directionCodeFromReason(reason)
%directionCodeFromReason Map a frozen FallbackReason to the enum code.
    switch reason
        case 'M_LE_3_OR_N_LT_50'
            code = 2;
        case 'FRONT1_LT_THRESHOLD'
            code = 3;
        case 'OBJECTIVE_RANGE_LT_1E12'
            code = 4;
        case 'NDSORT_EXCEPTION'
            code = 5;
        case 'KMEANS_EXCEPTION'
            code = 6;
        otherwise
            code = 2;
    end
end
