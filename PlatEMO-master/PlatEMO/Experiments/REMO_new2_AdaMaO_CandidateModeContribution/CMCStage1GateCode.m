function code = CMCStage1GateCode(factorDecision)
%CMCSTAGE1GATECODE Classify carried same-state/deferred factor evidence.

    required = ["Factor","FactorDecision","CarryToNextStage"];
    if ~istable(factorDecision) || isempty(factorDecision) || ...
            ~all(ismember(required, ...
            string(factorDecision.Properties.VariableNames)))
        code = "INSUFFICIENT_DIRECT_EFFECT_DATA";
        return;
    end
    primary = ["P","Q","C","D","E_GEN","E_FINAL","F","G", ...
        "P_ERR_GATE"];
    fullSet = [primary,"D_SIGNAL","F_SIGNAL"];
    carried = factorDecision.Factor(logical( ...
        factorDecision.CarryToNextStage));
    carriedPrimary = intersect(carried,primary,'stable');
    if isempty(carriedPrimary)
        rows = factorDecision(ismember(factorDecision.Factor,primary),:);
        if ~isempty(rows) && any(startsWith( ...
                rows.FactorDecision,"INSUFFICIENT"))
            code = "INSUFFICIENT_DIRECT_EFFECT_DATA";
        else
            code = "STOP_NO_DIRECT_EFFECT";
        end
    elseif all(ismember(fullSet,carried))
        code = "PASS_TO_STAGE2_FULL";
    elseif numel(carried) == 1 && carried == "P"
        code = "PASS_TO_STAGE2_POOL_ONLY";
    else
        code = "PASS_TO_STAGE2_REDUCED";
    end
end
