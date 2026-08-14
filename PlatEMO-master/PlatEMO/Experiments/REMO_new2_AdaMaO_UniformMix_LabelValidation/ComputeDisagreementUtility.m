function rows = ComputeDisagreementUtility(catalogs, loo, oracleTop25, future)
%ComputeDisagreementUtility Divergence-set external utility (§6.1).
%   rows = ComputeDisagreementUtility(catalogs, loo, oracleTop25, future)
%   For the three pre-registered comparisons:
%     L2 vs L1, L3 vs L1, L3 vs L2
%   this computes, for the A-only and B-only divergence sets:
%     AOnlyCount, BOnlyCount,
%     AOnlyMeanLOO, BOnlyMeanLOO, DisagreementUtilityDelta,
%     OracleTop25CaptureA, OracleTop25CaptureB,
%     H1SurvivalA, H1SurvivalB, FinalSurvivalA, FinalSurvivalB
%   When a divergence set has fewer than 3 solutions the snapshot records
%   the counts only (means/deltas are NaN), per plan §6.1.

    comparisons = {'L2','L1'; 'L3','L1'; 'L3','L2'};
    rows = struct('VariantA',{},'VariantB',{}, ...
        'AOnlyCount',{},'BOnlyCount',{}, ...
        'AOnlyMeanLOO',{},'BOnlyMeanLOO',{}, ...
        'DisagreementUtilityDelta',{}, ...
        'OracleTop25CaptureA',{},'OracleTop25CaptureB',{}, ...
        'H1SurvivalA',{},'H1SurvivalB',{}, ...
        'FinalSurvivalA',{},'FinalSurvivalB',{}, ...
        'SamplesA',{},'SamplesB',{});

    U = loo.UtilityLOO(:);
    oracleSet = ismember(loo.EvalID(:), oracleTop25(:));

    for c = 1:size(comparisons,1)
        A = comparisons{c,1};
        B = comparisons{c,2};
        catA = logical(catalogs.(A)(:,1));
        catB = logical(catalogs.(B)(:,1));
        aOnly = catA & ~catB;
        bOnly = catB & ~catA;
        nA = nnz(aOnly);
        nB = nnz(bOnly);

        row = struct('VariantA',A,'VariantB',B, ...
            'AOnlyCount',nA,'BOnlyCount',nB, ...
            'AOnlyMeanLOO',NaN,'BOnlyMeanLOO',NaN, ...
            'DisagreementUtilityDelta',NaN, ...
            'OracleTop25CaptureA',NaN,'OracleTop25CaptureB',NaN, ...
            'H1SurvivalA',NaN,'H1SurvivalB',NaN, ...
            'FinalSurvivalA',NaN,'FinalSurvivalB',NaN, ...
            'SamplesA',nA,'SamplesB',nB);

        % divergence-set utility only when >= 3 solutions on each side
        if nA >= 3 && nB >= 3
            row.AOnlyMeanLOO = mean(U(aOnly));
            row.BOnlyMeanLOO = mean(U(bOnly));
            row.DisagreementUtilityDelta = row.AOnlyMeanLOO - row.BOnlyMeanLOO;
            row.OracleTop25CaptureA = mean(oracleSet(aOnly));
            row.OracleTop25CaptureB = mean(oracleSet(bOnly));
            if ~isnan(future.InPopulationH1(1))
                row.H1SurvivalA = mean(future.InPopulationH1(aOnly));
                row.H1SurvivalB = mean(future.InPopulationH1(bOnly));
            end
            row.FinalSurvivalA = mean(future.InFinalPopulation(aOnly));
            row.FinalSurvivalB = mean(future.InFinalPopulation(bOnly));
        end

        if isempty(rows)
            rows = row;
        else
            rows(end+1) = row; %#ok<AGROW>
        end
    end
end
