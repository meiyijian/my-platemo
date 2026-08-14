function rows = ComputeExternalLabelMetrics(catalogs, scores, loo, oracleTop25, future, rGood)
%ComputeExternalLabelMetrics External-utility label metrics (§6).
%   rows = ComputeExternalLabelMetrics(catalogs, scores, loo, oracleTop25, future, rGood)
%   catalogs: struct L0..L8 (L6: N x 100, others N x 1 logical)
%   scores:   struct L0..L8 (same shapes; scores.L0 is binary)
%   loo:      struct with .UtilityLOO (N x 1) and .EvalID
%   oracleTop25: vector of EvalIDs in the greedy Oracle Top-25
%   future:   struct from ReconstructFutureLabelOutcomes
%   rGood:    frozen positive ratio (0.25)
%
%   Returns a struct array with one row per (variant, replicate):
%     VariantName, Replicate,
%     PrecisionAt25, RecallAt25, JaccardAt25,
%     NDCGAt25_LOO, KendallTauB_LOO, PairwiseAUC_LOO,
%     H1SurvivalRateSelected, H3SurvivalRateSelected,
%     FinalSurvivalRateSelected,
%     NativePositiveCount, NativePrecision, NativeRecall, NativeJaccard,
%     INSUFFICIENT_UTILITY_VARIATION, NNonTiePairs
%   L0 uses native size (fixed-25 columns NaN). L6 keeps only set-based
%   metrics (Precision/Recall/Jaccard + survival) so that the 100-permutation
%   distribution stays cheap; score-based rank metrics on L6 would not
%   contribute to the shuffle envelope decision.

    N = numel(loo.UtilityLOO);
    oracleSet = ismember(loo.EvalID(:), oracleTop25(:));
    oracleCount = nnz(oracleSet);

    rows = struct('VariantName',{},'Replicate',{}, ...
        'PrecisionAt25',{},'RecallAt25',{},'JaccardAt25',{}, ...
        'NDCGAt25_LOO',{},'KendallTauB_LOO',{},'PairwiseAUC_LOO',{}, ...
        'H1SurvivalRateSelected',{},'H3SurvivalRateSelected',{}, ...
        'FinalSurvivalRateSelected',{}, ...
        'NativePositiveCount',{},'NativePrecision',{},'NativeRecall',{}, ...
        'NativeJaccard',{}, ...
        'INSUFFICIENT_UTILITY_VARIATION',{},'NNonTiePairs',{});

    U = loo.UtilityLOO(:);
    nNonTie = nnz(U ~= U(1));
    insufficient = (nNonTie < 10);

    % single pair index for score-based metrics (shared across variants)
    pairs = nchoosek(1:N,2);

    names = fieldnames(catalogs);
    for v = 1:numel(names)
        nm = names{v};
        cat = catalogs.(nm);
        sc  = scores.(nm);
        R = size(cat,2);
        for r = 1:R
            sel = cat(:,r);
            selCount = nnz(sel);
            isL0 = strcmp(nm,'L0');
            isL6 = strcmp(nm,'L6');

            inter = nnz(sel & oracleSet);
            union_ = nnz(sel | oracleSet);

            row = struct('VariantName',nm,'Replicate',r, ...
                'PrecisionAt25',NaN,'RecallAt25',NaN,'JaccardAt25',NaN, ...
                'NDCGAt25_LOO',NaN,'KendallTauB_LOO',NaN, ...
                'PairwiseAUC_LOO',NaN, ...
                'H1SurvivalRateSelected',NaN, ...
                'H3SurvivalRateSelected',NaN, ...
                'FinalSurvivalRateSelected',NaN, ...
                'NativePositiveCount',NaN,'NativePrecision',NaN, ...
                'NativeRecall',NaN,'NativeJaccard',NaN, ...
                'INSUFFICIENT_UTILITY_VARIATION',insufficient, ...
                'NNonTiePairs',nNonTie);

            if isL0
                row.NativePositiveCount = selCount;
                row.NativePrecision = inter / max(selCount,1);
                row.NativeRecall    = inter / max(oracleCount,1);
                row.NativeJaccard   = inter / max(union_,1);
            else
                row.PrecisionAt25 = inter / 25;
                row.RecallAt25    = inter / 25;
                row.JaccardAt25   = inter / max(union_,1);

                % score-based rank metrics only for single-valued variants
                % (skip L6: 100 perms; envelope uses set metrics)
                if ~isL6 && ~insufficient
                    s = sc(:,r);
                    if ~all(s == s(1)) && ~all(U == U(1))
                        row.NDCGAt25_LOO    = ndcgAtTopK(s, U, 25);
                        row.KendallTauB_LOO = kendallTauB(s, U, pairs);
                        row.PairwiseAUC_LOO = pairwiseAUC(s, U, pairs);
                    end
                end

                if ~isnan(future.InPopulationH1(1))
                    row.H1SurvivalRateSelected = mean(future.InPopulationH1(sel));
                end
                if ~isnan(future.InPopulationH3(1))
                    row.H3SurvivalRateSelected = mean(future.InPopulationH3(sel));
                end
                row.FinalSurvivalRateSelected = mean(future.InFinalPopulation(sel));
            end

            if isempty(rows)
                rows = row;
            else
                rows(end+1) = row; %#ok<AGROW>
            end
        end
    end
end

%% ============ NDCG @ top-K by score (gain = UtilityLOO) ============
function ndcg = ndcgAtTopK(score, util, K)
    [~,ord] = sort(score(:),'descend');
    top = ord(1:min(K,numel(ord)));
    dcg = sum(util(top) ./ log2((1:numel(top)) + 1));
    [~,iord] = sort(util(:),'descend');
    itop = iord(1:min(K,numel(iord)));
    idcg = sum(util(itop) ./ log2((1:numel(itop)) + 1));
    ndcg = dcg / max(idcg, eps);
end

%% ============ Kendall tau-b between score and utility ============
function tb = kendallTauB(x, y, pairs)
    dx = x(pairs(:,1)) - x(pairs(:,2));
    dy = y(pairs(:,1)) - y(pairs(:,2));
    nc = nnz(dx > 0 & dy > 0) + nnz(dx < 0 & dy < 0);
    nd = nnz(dx > 0 & dy < 0) + nnz(dx < 0 & dy > 0);
    t0x = nnz(dx == 0);
    t0y = nnz(dy == 0);
    denom = sqrt((numel(pairs) - t0x) * (numel(pairs) - t0y));
    tb = (nc - nd) / max(denom, eps);
end

%% ============ pairwise AUC (concordance) ============
function auc = pairwiseAUC(score, util, pairs)
    dx = score(pairs(:,1)) - score(pairs(:,2));
    dy = util(pairs(:,1)) - util(pairs(:,2));
    concord = nnz(dx > 0 & dy > 0) + nnz(dx < 0 & dy < 0);
    total = nnz(dx ~= 0);
    auc = concord / max(total,1);
end
