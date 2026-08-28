function config = CMCArmConfiguration(armID)
%CMCARMCONFIGURATION Internal switches for the frozen arm catalog.

    config = struct( ...
        'ArmID',armID,'PoolAll',true,'UseQ',true,'UseC',true, ...
        'UseD',true,'ShuffleD',false,'EGen',"current", ...
        'EFinal',"current",'UseF',true,'ShuffleF',false, ...
        'RemovePErrGate',false,'Route',"uniform",'FixedK',true);
    switch armID
        case 0
            % A00_FULL
        case 1
            config.PoolAll = false;
        case 2
            config.UseQ = false;
        case 3
            config.UseC = false;
        case 4
            config.UseD = false;
        case 5
            config.EGen = "simple";
        case 6
            config.EFinal = "simple";
        case 7
            config.UseF = false;
        case 8
            config.ShuffleD = true;
        case 9
            config.ShuffleF = true;
        case 10
            config.RemovePErrGate = true;
        case 11
            config.Route = "explore";
        case 12
            config.Route = "indicator";
        case 13
            config.UseQ = false;
            config.UseC = false;
            config.UseD = false;
            config.EGen = "simple";
            config.EFinal = "simple";
            config.UseF = false;
            config.Route = "explore";
        case 100
            % Exact operational batch rule of CURRENT_HCV is retained.
            config.FixedK = false;
        otherwise
            error('CMC:UnknownArmID','Unknown CMC ArmID: %g.',armID);
    end
end
