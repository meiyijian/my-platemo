function code = CMCStage3GateCode(armDecision,upstreamCode,protocol)
%CMCSTAGE3GATECODE Classify held-out formal endpoint evidence.

    net = armDecision(armDecision.Arm == "C00_RELATION_CONTROL",:);
    if isempty(net)
        net = armDecision(armDecision.Arm == "CURRENT_HCV",:);
    end
    catalog = CMCArmCatalog();
    primary = ["P","Q","C","D","E_GEN","E_FINAL","F","G", ...
        "P_ERR_GATE"];
    evidenceArms = catalog.Arm(ismember(catalog.Role, ...
        ["drop_one","negative_control","route_control"]));
    evidence = armDecision(ismember(armDecision.Arm,evidenceArms),:);
    [qualifiedFactors,~] = CMCSummarizeEvidenceFactors(armDecision);
    fullFormalEvidence = all(ismember(evidenceArms,armDecision.Arm)) && ...
        height(evidence) == numel(evidenceArms) && all(evidence.Qualified);
    netGain = ~isempty(net) && net.Qualified(1);
    factorGain = any(ismember(qualifiedFactors,primary));
    if ~CMCAnchorCompatible(armDecision,protocol)
        code = "FACTOR_HOST_NOT_NONINFERIOR_TO_CURRENT";
    elseif netGain && factorGain
        if string(upstreamCode) == "PASS_TO_STAGE3_FULL" && ...
                fullFormalEvidence
            code = "SUPPORTED_FULL_MODULE";
        else
            code = "SUPPORTED_REDUCED_MODULE";
        end
    elseif netGain
        code = "PERFORMANCE_GAIN_WITHOUT_FACTOR_ATTRIBUTION";
    elseif factorGain
        code = "FACTOR_EFFECT_WITHOUT_NET_PERFORMANCE_GAIN";
    elseif ~isempty(net) && net.CI95Lower(1) <= ...
            protocol.Thresholds.EndpointMCIDRatio && ...
            net.CI95Upper(1) >= protocol.Thresholds.NonInferiorityMargin
        code = "INCONCLUSIVE_FORMAL_EFFECT";
    else
        code = "NO_CONFIRMED_ENDPOINT_ADVANTAGE";
    end
end
