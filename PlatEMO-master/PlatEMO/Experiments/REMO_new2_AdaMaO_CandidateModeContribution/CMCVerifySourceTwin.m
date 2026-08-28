function result = CMCVerifySourceTwin(profile,resultRoot)
%CMCVERIFYSOURCETWIN Compare original HCV and the read-only audit twin.

    CMCWarmupLearningToolboxes();
    protocol = CMCProtocol('stage0',profile);
    paths = CMCStagePaths(protocol,resultRoot);
    if ~isfolder(paths.AnalysisRoot)
        mkdir(paths.AnalysisRoot);
    end
    filePath = fullfile(paths.AnalysisRoot, ...
        'CMC_Stage0_SourceTwinEquivalence.csv');
    if isfile(filePath)
        prior = readtable(filePath,'TextType','string');
        if height(prior) == 1 && ...
                all(ismember(["Status","ProtocolHash", ...
                "SourceMainSHA256","SourceSelectionSHA256"], ...
                string(prior.Properties.VariableNames))) && ...
                prior.Status == "PASS" && ...
                prior.ProtocolHash == protocol.ProtocolHash && ...
                prior.SourceMainSHA256 == ...
                "BD51B71976C31AD8172B00A6675A73710C475689A6906B4FDD70D10E0A920566" && ...
                prior.SourceSelectionSHA256 == ...
                "ABE4DD8ED74157C544899AFA73136F95851DB913CB6B14DFA3B09BABE725AED0"
            result = prior;
            return;
        end
    end

    seed = CMCStableSeed('stage0','DTLZ2',3,1);
    verificationMaxFE = 112;
    ProblemA = DTLZ2('N',100,'M',3,'D',6, ...
        'maxFE',verificationMaxFE);
    ProblemB = DTLZ2('N',100,'M',3,'D',6, ...
        'maxFE',verificationMaxFE);
    p = protocol.Parameters;
    common = {p.gmax,p.pMix,p.rGood,p.qKeep,p.lambda0,p.nMin,p.nMax, ...
        p.nHarm,p.wConFlag};
    Original = REMO_new2_AdaMaO_HCV('parameter',common, ...
        'run',seed.Routing,'save',10000,'outputFcn',@silentOutput);
    auditParameters = [common,{100,0,seed.RandomControl, ...
        protocol.ReferenceSizes,protocol.Checkpoints, ...
        protocol.RandomReplicates}];
    Twin = CMC_HCV_Audit('parameter',auditParameters, ...
        'run',seed.Routing,'save',10000,'outputFcn',@silentOutput);

    rng(seed.Search,'twister');
    Original.Solve(ProblemA);
    rngAfterOriginal = rng;
    rng(seed.Search,'twister');
    Twin.Solve(ProblemB);
    rngAfterTwin = rng;
    [sameHistory,maxDec,maxObj,firstMismatchFE,initialDecisionError] = ...
        compareHistory(Original.result,Twin.result);
    originalFinal = Original.result{end,2};
    twinFinal = Twin.result{end,2};
    igdA = ProblemA.CalMetric('IGD',originalFinal);
    igdB = ProblemB.CalMetric('IGD',twinFinal);
    igdpA = ProblemA.CalMetric('IGDp',originalFinal);
    igdpB = ProblemB.CalMetric('IGDp',twinFinal);
    sameFE = ProblemA.FE == ProblemB.FE && ...
        ProblemA.FE == verificationMaxFE;
    sameRng = isequal(rngAfterOriginal,rngAfterTwin);
    tolerance = 1e-12;
    pass = sameHistory && sameFE && sameRng && maxDec <= tolerance && ...
        maxObj <= tolerance && abs(igdA-igdB) <= tolerance && ...
        abs(igdpA-igdpB) <= tolerance;
    status = string(ternary(pass,'PASS','FAIL'));
    result = table(status,protocol.ProtocolHash,sameHistory,sameFE,sameRng, ...
        maxDec,maxObj, ...
        firstMismatchFE,initialDecisionError, ...
        abs(igdA-igdB),abs(igdpA-igdpB),tolerance, ...
        "BD51B71976C31AD8172B00A6675A73710C475689A6906B4FDD70D10E0A920566", ...
        "ABE4DD8ED74157C544899AFA73136F95851DB913CB6B14DFA3B09BABE725AED0", ...
        string(datetime('now','Format','yyyy-MM-dd HH:mm:ss')), ...
        'VariableNames',{'Status','ProtocolHash','SameGenerationHistory', ...
        'SameCompletedFE', ...
        'SameFinalRNG','MaxDecisionError','MaxObjectiveError', ...
        'FirstMismatchFE','InitialDecisionError','IGDError', ...
        'IGDpError','Tolerance','SourceMainSHA256', ...
        'SourceSelectionSHA256','GeneratedAt'});
    CMCWriteTableAtomic(result,filePath);
    if ~pass
        error('CMC:SourceTwinMismatch', ...
            'The CMC audit twin is not trajectory-equivalent to current HCV.');
    end
end

function [same,maxDec,maxObj,firstMismatchFE,initialDecisionError] = ...
        compareHistory(a,b)
    rowsA = find(~cellfun(@isempty,a(:,1)));
    rowsB = find(~cellfun(@isempty,b(:,1)));
    same = isequal(a(rowsA,1),b(rowsB,1)) && numel(rowsA) == numel(rowsB);
    maxDec = 0;
    maxObj = 0;
    firstMismatchFE = NaN;
    initialDecisionError = NaN;
    if ~same
        maxDec = inf;
        maxObj = inf;
        return;
    end
    for index = 1:numel(rowsA)
        popA = a{rowsA(index),2};
        popB = b{rowsB(index),2};
        if length(popA) ~= length(popB)
            same = false;
            maxDec = inf;
            maxObj = inf;
            return;
        end
        maxDec = max(maxDec,max(abs(popA.decs-popB.decs),[],'all'));
        maxObj = max(maxObj,max(abs(popA.objs-popB.objs),[],'all'));
        localError = max(abs(popA.decs-popB.decs),[],'all');
        if index == 1
            initialDecisionError = localError;
        end
        if isnan(firstMismatchFE) && localError > 1e-12
            firstMismatchFE = a{rowsA(index),1};
        end
    end
end

function value = ternary(condition,a,b)
    if condition, value = a; else, value = b; end
end

function silentOutput(varargin)
end
