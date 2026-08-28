function rows = CMCBuildActivityRows(trace,generation,fe,ratio,postClipK)
%CMCBUILDACTIVITYROWS Convert one selector trace to factor activity rows.

    rows = CMCActivitySchema();
    factors = ["P","Q","K","C","D","E_GEN","E_FINAL", ...
        "F","G","P_ERR_GATE"];
    for factor = factors
        [eligible,triggered,changed,overlap] = factorState(trace,factor);
        selected = trace.SelectedIndex(:);
        nonfinal = nnz(~trace.InFinalRound(selected));
        meanRound = mean(trace.FirstRound(selected));
        row = {generation,fe,ratio,string(trace.AttemptedMode), ...
            string(trace.Mode),logical(trace.IndicatorAvailable), ...
            logical(trace.OperationalIndicatorUsed), ...
            string(trace.FallbackReason),trace.RequestedK,trace.SelectedK, ...
            postClipK,trace.LastPoolCount,trace.AccumRawCount, ...
            trace.AccumUniqueCount,trace.RetainedCount,trace.LambdaT, ...
            trace.PErr,factor,eligible,triggered,changed,overlap, ...
            nonfinal,meanRound,trace.ArchiveDuplicateCount, ...
            trace.ArchiveNearDuplicateCount};
        rows = [rows;row]; %#ok<AGROW>
    end
end

function [eligible,triggered,changed,overlap] = factorState(trace,factor)
    policy = trace.Policy;
    K = policy.K;
    mode = string(trace.Mode);
    eligible = false;
    triggered = false;
    changed = false;
    overlap = NaN;
    switch factor
        case "P"
            eligible = trace.AccumUniqueCount > trace.LastPoolCount && ...
                trace.LastPoolCount >= K;
            triggered = eligible;
            [changed,overlap] = compareMasks( ...
                policy.ACCUM_MATCHED,policy.FINAL_MATCHED,eligible);
        case "Q"
            eligible = mode == "explore" && trace.AccumUniqueCount >= K;
            triggered = eligible;
            [changed,overlap] = compareMasks( ...
                policy.EXP_FULL,policy.EXP_NO_Q,eligible);
        case "K"
            eligible = trace.AccumUniqueCount >= 6;
            triggered = eligible;
            changed = eligible && trace.SelectedK ~= 6;
            overlap = double(~changed);
        case "C"
            eligible = mode == "explore" && ...
                nnz(policy.ExploreRetained) >= K;
            triggered = eligible;
            [changed,overlap] = compareMasks( ...
                policy.EXP_FULL,policy.EXP_NO_C,eligible);
        case "D"
            eligible = mode == "explore" && trace.LambdaT > 0 && ...
                range(trace.Ambiguity) > 1e-12;
            triggered = eligible;
            [changed,overlap] = compareMasks( ...
                policy.EXP_FULL,policy.EXP_NO_D,eligible);
        case "E_GEN"
            eligible = trace.GenerationAggregationEligible > 0;
            triggered = eligible && mode == "explore";
            changed = eligible && trace.GenerationAggregationChanged > 0;
        case "E_FINAL"
            eligible = mode == "explore" && ...
                range(trace.WeightedScore-trace.SimpleScore) > 1e-12;
            triggered = eligible;
            [changed,overlap] = compareMasks( ...
                policy.EXP_FULL,policy.EXP_SIMPLE_FULL,eligible);
        case "F"
            eligible = mode == "indicator" && policy.IND_OPERATIONAL;
            triggered = eligible;
            [changed,overlap] = compareMasks( ...
                policy.IND_FULL,policy.IND_RELATION_ONLY,eligible);
        case "G"
            eligible = trace.IndicatorAvailable;
            triggered = eligible;
            [changed,overlap] = compareMasks( ...
                policy.EXP_FULL,policy.IND_FULL,eligible);
        case "P_ERR_GATE"
            eligible = mode == "explore" && trace.LambdaT >= 0 && ...
                isfinite(trace.PErr);
            triggered = eligible;
            [changed,overlap] = compareMasks( ...
                policy.EXP_FULL,policy.EXP_NO_PERR_GATE,eligible);
    end
end

function [changed,overlap] = compareMasks(a,b,eligible)
    if ~eligible
        changed = false;
        overlap = NaN;
        return;
    end
    a = logical(a(:)); b = logical(b(:));
    changed = ~isequal(a,b);
    unionCount = nnz(a|b);
    if unionCount == 0
        overlap = NaN;
    else
        overlap = nnz(a&b)/unionCount;
    end
end
