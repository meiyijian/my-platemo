function upstream = CMCRequirePreviousGate(protocol,resultRoot)
%CMCREQUIREPREVIOUSGATE Enforce both upstream integrity and science gates.

    upstream = struct('Required',false,'DecisionCode',"", ...
        'DecisionHash',"",'AuthorizationHash',"");
    if strlength(protocol.Previous.Stage) == 0
        return;
    end
    previous = CMCProtocol(protocol.Previous.Stage,protocol.Previous.Profile);
    paths = CMCStagePaths(previous,resultRoot);
    prefix = "CMC_Stage" + string(previous.StageNumber);
    integrityFile = fullfile(paths.AnalysisRoot, ...
        char(prefix + "_IntegrityGate.csv"));
    decisionFile = fullfile(paths.AnalysisRoot, ...
        char(prefix + "_ScientificDecision.csv"));
    if ~isfile(integrityFile) || ~isfile(decisionFile)
        error('CMC:PreviousGateMissing', ...
            ['Run and analyze %s (%s) first. Both integrity and ', ...
             'scientific decision CSV files are required.'], ...
            previous.Stage,previous.Profile);
    end
    integrity = readtable(integrityFile,'TextType','string');
    decision = readtable(decisionFile,'TextType','string');
    requireOneRow(integrity,"integrity");
    requireOneRow(decision,"scientific decision");
    requiredColumns = ["ProtocolHash","Status"];
    decisionColumns = ["ProtocolHash","DecisionCode"];
    if ~all(ismember(requiredColumns,string(integrity.Properties.VariableNames)))
        error('CMC:PreviousGateInvalid','Previous integrity gate is malformed.');
    end
    if ~all(ismember(decisionColumns,string(decision.Properties.VariableNames)))
        error('CMC:PreviousGateInvalid', ...
            'Previous scientific decision gate is malformed.');
    end
    if integrity.ProtocolHash(1) ~= previous.ProtocolHash || ...
            decision.ProtocolHash(1) ~= previous.ProtocolHash
        error('CMC:PreviousProtocolDrift', ...
            'Previous gate protocol hash does not match the frozen protocol.');
    end
    if integrity.Status(1) ~= "PASS"
        error('CMC:PreviousIntegrityFailed', ...
            'Previous integrity status is %s, not PASS.',integrity.Status(1));
    end
    allowed = allowedCodes(protocol.Stage,protocol.Profile);
    code = decision.DecisionCode(1);
    if ~ismember(code,allowed)
        error('CMC:PreviousScienceGateFailed', ...
            'Decision %s does not authorize %s.',code,protocol.Stage);
    end
    upstream.Required = true;
    upstream.DecisionCode = code;
    authorizationPath = authorizationFile(previous,paths);
    if ~isfile(authorizationPath)
        error('CMC:PreviousAuthorizationMissing', ...
            'Previous authorization CSV is missing: %s.',authorizationPath);
    end
    authorization = readtable(authorizationPath,'TextType','string');
    if isempty(authorization)
        error('CMC:PreviousAuthorizationInvalid', ...
            'Previous authorization CSV is empty: %s.',authorizationPath);
    end
    if ismember("ProtocolHash",string(authorization.Properties.VariableNames)) && ...
            any(authorization.ProtocolHash ~= previous.ProtocolHash)
        error('CMC:PreviousProtocolDrift', ...
            'Previous authorization CSV does not match the frozen protocol.');
    end
    ignored = "GeneratedAt";
    authorizationHash = CMCTableFingerprint(authorization,ignored);
    upstream.AuthorizationHash = authorizationHash;
    upstream.DecisionHash = CMCTextHash(strjoin([ ...
        previous.ProtocolHash, ...
        CMCTableFingerprint(integrity,ignored), ...
        CMCTableFingerprint(decision,ignored), ...
        authorizationHash],"|"));
end

function pathValue = authorizationFile(previous,paths)
    if previous.Stage == "stage0"
        name = 'CMC_Stage0_FactorDecision.csv';
    elseif previous.Stage == "stage1"
        name = 'CMC_Stage1_FactorDecision.csv';
    else
        name = 'CMC_Stage2_ArmDecision.csv';
    end
    pathValue = fullfile(paths.AnalysisRoot,name);
end

function values = allowedCodes(stage,profile)
    if profile == "smoke"
        values = "SMOKE_PASS";
    elseif stage == "stage1"
        values = ["PASS_TO_STAGE1","PASS_TO_STAGE1_REDUCED"];
    elseif stage == "stage2"
        values = ["PASS_TO_STAGE2_POOL_ONLY", ...
            "PASS_TO_STAGE2_REDUCED","PASS_TO_STAGE2_FULL"];
    else
        values = ["PASS_TO_STAGE3_REDUCED","PASS_TO_STAGE3_FULL"];
    end
end

function requireOneRow(value,label)
    if height(value) ~= 1 || ...
            ~ismember("DecisionCode",string(value.Properties.VariableNames)) && ...
            label == "scientific decision"
        error('CMC:PreviousGateInvalid','Previous %s CSV is malformed.',label);
    end
end
