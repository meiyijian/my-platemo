function arms = CMCResolveArms(protocol,resultRoot,requestedArms)
%CMCRESOLVEARMS Resolve only arms authorized by the previous stage.

    if nargin < 3
        requestedArms = strings(0,1);
    end
    if ismember(protocol.Stage,["stage0","stage1"])
        if ~isempty(requestedArms)
            error('CMC:AuditArmFixed', ...
                'Stage 0/1 use the fixed AUDIT_CURRENT arm only.');
        end
        arms = table(100,"AUDIT_CURRENT","AUDIT","audit", ...
            "CMC_HCV_Audit","逐行等价的当前HCV只读审计副本", ...
            'VariableNames',CMCArmCatalog().Properties.VariableNames);
        return;
    end

    catalog = CMCArmCatalog();
    if ~isempty(requestedArms)
        requestedArms = string(requestedArms(:));
        unknown = setdiff(requestedArms,catalog.Arm,'stable');
        if ~isempty(unknown)
            error('CMC:UnknownArm','Unknown CMC arms: %s.', ...
                strjoin(cellstr(unknown),', '));
        end
    end

    if protocol.Profile == "smoke"
        wanted = ["A00_FULL","A01_NO_P","CURRENT_HCV"];
    elseif protocol.Stage == "stage2"
        factorFile = upstreamFile(protocol,resultRoot, ...
            'CMC_Stage1_FactorDecision.csv');
        factors = readtable(factorFile,'TextType','string');
        requireColumns(factors,["Factor","CarryToNextStage"]);
        carried = factors.Factor(logical(factors.CarryToNextStage));
        wanted = ["A00_FULL","C00_RELATION_CONTROL","CURRENT_HCV"];
        map = struct('P',"A01_NO_P",'Q',"A02_NO_Q",'C',"A03_NO_C", ...
            'D',"A04_NO_D",'D_SIGNAL',"N01_SHUFFLE_D", ...
            'E_GEN',"A05_NO_EGEN",'E_FINAL',"A06_NO_EFINAL", ...
            'F',"A07_NO_F",'F_SIGNAL',"N02_SHUFFLE_F", ...
            'P_ERR_GATE',"N03_NO_PERR_GATE", ...
            'G',["G01_ALWAYS_EXPLORE","G02_ALWAYS_INDICATOR"]);
        for factor = carried(:).'
            key = char(factor);
            if isfield(map,key)
                wanted = [wanted,map.(key)]; %#ok<AGROW>
            end
        end
    else
        armFile = upstreamFile(protocol,resultRoot, ...
            'CMC_Stage2_ArmDecision.csv');
        decisions = readtable(armFile,'TextType','string');
        requireColumns(decisions,["Arm","CarryToNextStage"]);
        wanted = decisions.Arm(logical(decisions.CarryToNextStage)).';
    end
    wanted = unique(wanted,'stable');
    authorized = catalog(ismember(catalog.Arm,wanted),:);
    if ~isempty(requestedArms)
        unauthorized = setdiff(requestedArms,authorized.Arm,'stable');
        if ~isempty(unauthorized)
            error('CMC:UnauthorizedArm', ...
                'Upstream gates did not authorize arms: %s.', ...
                strjoin(cellstr(unauthorized),', '));
        end
        arms = authorized(ismember(authorized.Arm,requestedArms),:);
    else
        arms = authorized;
    end
    if isempty(arms)
        error('CMC:NoAuthorizedArms','No arms were authorized for %s.', ...
            protocol.Stage);
    end
end

function pathValue = upstreamFile(protocol,resultRoot,fileName)
    previous = CMCProtocol(protocol.Previous.Stage,protocol.Previous.Profile);
    paths = CMCStagePaths(previous,resultRoot);
    pathValue = fullfile(paths.AnalysisRoot,fileName);
    if ~isfile(pathValue)
        error('CMC:MissingUpstreamDecision', ...
            'Required upstream decision file is missing: %s.',pathValue);
    end
end

function requireColumns(value,names)
    if ~all(ismember(names,string(value.Properties.VariableNames)))
        error('CMC:InvalidUpstreamDecision','Upstream CSV columns are incomplete.');
    end
end
