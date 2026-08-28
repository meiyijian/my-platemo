function value = CMCPrimaryMetric(stage)
%CMCPRIMARYMETRIC Return the exact primary estimand label for a stage.

    switch lower(string(stage))
        case "stage0"
            value = "BEHAVIORAL_ACTIVITY";
        case "stage1"
            value = "DIRECT_ORACLE_EFFICIENCY_DELTA";
        case {"stage2","stage3"}
            value = "FINAL_IGDP";
        otherwise
            error('CMC:UnknownStage','Unknown CMC stage: %s.',string(stage));
    end
end
