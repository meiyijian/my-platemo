function code = CMCStage2GateCode(armDecision,planned,supported, ...
        complete,upstreamCode,protocol)
%CMCSTAGE2GATECODE Classify the frozen endpoint-screening evidence.

    net = armDecision(armDecision.Arm == "C00_RELATION_CONTROL",:);
    if isempty(net)
        net = armDecision(armDecision.Arm == "CURRENT_HCV",:);
    end
    anchor = armDecision(armDecision.Arm == "CURRENT_HCV",:);
    planned = string(planned(:));
    supported = logical(supported(:));
    if isempty(net) || isempty(anchor) || isempty(planned) || ~complete || ...
            numel(planned) ~= numel(supported)
        code = "INSUFFICIENT_DATA";
    elseif ~CMCAnchorCompatible(armDecision,protocol)
        code = "STOP_FACTOR_HOST_MISMATCH";
    elseif ~net.Qualified(1)
        if net.CI95Lower(1) <= protocol.Thresholds.EndpointMCIDRatio && ...
                net.CI95Upper(1) >= ...
                protocol.Thresholds.NonInferiorityMargin
            code = "INCONCLUSIVE_ENDPOINT_SCREEN";
        else
            code = "STOP_NO_ENDPOINT_SIGNAL";
        end
    elseif ~any(supported & isPrimaryFactor(planned))
        code = "STOP_NO_ENDPOINT_SIGNAL";
    else
        fullSet = ["P","Q","C","D","E_GEN","E_FINAL","F","G", ...
            "D_SIGNAL","F_SIGNAL","P_ERR_GATE"];
        fullEvidence = string(upstreamCode) == "PASS_TO_STAGE2_FULL" && ...
            all(ismember(fullSet,planned)) && ...
            all(ismember(fullSet,planned(supported))) && all(supported);
        if fullEvidence
            code = "PASS_TO_STAGE3_FULL";
        else
            code = "PASS_TO_STAGE3_REDUCED";
        end
    end
end

function mask = isPrimaryFactor(factors)
    mask = ismember(string(factors), ...
        ["P","Q","C","D","E_GEN","E_FINAL","F","G","P_ERR_GATE"]);
end
