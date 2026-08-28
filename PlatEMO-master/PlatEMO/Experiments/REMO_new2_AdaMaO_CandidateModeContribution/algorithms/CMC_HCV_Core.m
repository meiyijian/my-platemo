classdef (Abstract) CMC_HCV_Core < ALGORITHM
%CMC_HCV_CORE Frozen HCV host for candidate-mode auditing and ablation.

    methods
        function main(Algorithm,Problem)
            [gmax,pMix,rGood,qKeep,lambda0,nMin,nMax,nHarm,wConFlag, ...
                armID,stageCode,randomControlSeed,referenceSizes, ...
                checkpoints,randomReplicates] = Algorithm.ParameterSet( ...
                3000,0.50,0.25,0.80,0.35,4,6,2,0,0,2,1, ...
                [4096 8192 16384],[0.20 0.50 0.80],500);
            validateInputs(gmax,pMix,rGood,qKeep,lambda0,nMin,nMax, ...
                nHarm,wConFlag,armID,stageCode,randomControlSeed, ...
                referenceSizes,checkpoints,randomReplicates);
            if Algorithm.isAudit() && armID ~= 100
                error('CMC:AuditArmMismatch','CMC_HCV_Audit requires ArmID 100.');
            elseif ~Algorithm.isAudit() && armID == 100
                error('CMC:FactorArmMismatch', ...
                    'CURRENT_HCV must use the original HCV class.');
            end
            wCon = ternary(wConFlag == 1,'scaled','legacy');

            if Problem.D <= 10
                N = 11*Problem.D-1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive = Population;
            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp = 1;
            generation = 0;
            checkpointDone = false(size(checkpoints));
            Algorithm.metric.cmcActivity = CMCActivitySchema();
            Algorithm.metric.cmcSnapshots = CMCSnapshotSchema();
            Algorithm.metric.cmcReference = CMCReferenceSchema();
            Algorithm.metric.cmcArmID = armID;
            Algorithm.metric.cmcStageCode = stageCode;

            while Algorithm.NotTerminated(Archive)
                generation = generation + 1;
                u = rand(modeStream,1);
                ratio = Problem.FE/Problem.maxFE;
                kEffective = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                [~,~,Catalog,~,Ref] = ComplementaryPBI_Classification( ...
                    Population,ratio,'k',kEffective,'theta',5, ...
                    'rGood',rGood,'nHarm',nHarm);

                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N,wCon);
                    continue;
                end
                [net,normalization,pError] = trainRelationModel(XXs,YYs);

                IndicatorModel = [];
                try
                    [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp);
                catch
                    Fitness = [];
                end
                if ~isempty(Fitness)
                    try
                        IndicatorModel = fitrsvm(Population.decs,Fitness, ...
                            'KernelFunction','rbf','KernelScale','auto', ...
                            'Standardize',true);
                    catch
                        IndicatorModel = [];
                    end
                end
                attemptedMode = ternary(u < pMix,'indicator','explore');
                candidateMode = ResolveUniformMixMode( ...
                    ~isempty(IndicatorModel),u,pMix);

                Smodel = struct('X',Input,'Y',Catalog, ...
                    'mp_struct',normalization,'net',net,'p_err',pError, ...
                    'lambda0',lambda0,'ratio',ratio, ...
                    'IndicatorModel',IndicatorModel,'mode',candidateMode, ...
                    'AttemptedMode',attemptedMode,'Generation',generation, ...
                    'RandomControlSeed',randomControlSeed, ...
                    'ArchiveDec',Archive.decs);
                if Algorithm.isAudit()
                    [Next,trace] = auditSelectionReplay( ...
                        Problem,Ref,Input,gmax,Smodel,qKeep,nMin,nMax, ...
                        armID);
                else
                    Next = CMCCandidateSelection( ...
                        Problem,Ref,Input,gmax,Smodel,qKeep,nMin,nMax, ...
                        armID,false);
                    trace = struct();
                end

                remain = Problem.maxFE-Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = Next(1:min(nMin,size(Next,1)),:);
                end
                if isempty(Next)
                    postClipK = 0;
                else
                    postClipK = min(size(Next,1),remain);
                    Next = Next(1:postClipK,:);
                end

                if Algorithm.isAudit() && ~isempty(trace.Candidates)
                    activity = CMCBuildActivityRows( ...
                        trace,generation,Problem.FE,ratio,postClipK);
                    Algorithm.metric.cmcActivity = ...
                        [Algorithm.metric.cmcActivity;activity];
                    if stageCode == 1
                        due = find(~checkpointDone & ratio >= checkpoints,1);
                        if ~isempty(due)
                            snapshotID = nnz(checkpointDone)+1;
                            [snapshot,reference] = CMCBuildSnapshotAudit( ...
                                Problem,Archive,trace,snapshotID,generation, ...
                                referenceSizes,randomReplicates, ...
                                randomControlSeed,CMCProtocol( ...
                                    'stage1','smoke').Thresholds);
                            Algorithm.metric.cmcSnapshots = ...
                                [Algorithm.metric.cmcSnapshots;snapshot];
                            Algorithm.metric.cmcReference = ...
                                [Algorithm.metric.cmcReference;reference];
                            checkpointDone(due) = true;
                        end
                    end
                end

                if ~isempty(Next) && remain > 0
                    NewSolutions = Problem.Evaluation(Next);
                    Archive = [Archive,NewSolutions]; %#ok<AGROW>
                end
                Population = RefSelect(Archive,Problem.N,wCon);
            end
        end
    end

    methods (Access = protected, Abstract)
        value = isAudit(Algorithm)
    end
end

function [Next,trace] = auditSelectionReplay( ...
        Problem,Ref,Input,gmax,Smodel,qKeep,nMin,nMax,armID)
    before = rng;
    Next = CMCFrozenAdaMaOSelection( ...
        Problem,Ref,Input,gmax,Smodel,qKeep,nMin,nMax);
    operationalAfter = rng;
    rng(before);
    restore = onCleanup(@()rng(operationalAfter));
    [replayNext,trace] = CMCCandidateSelection( ...
        Problem,Ref,Input,gmax,Smodel,qKeep,nMin,nMax,armID,true);
    if ~isequal(Next,replayNext)
        error('CMC:TraceReplayMismatch', ...
            'The read-only trace replay did not reproduce operational Next.');
    end
    clear restore;
    rng(operationalAfter);
end

function [net,normalization,pError] = trainRelationModel(XXs,YYs)
    [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
    dimension = size(TrainIn,2);
    [normalized,normalization] = mapminmax(TrainIn');
    normalized = normalized';
    onehot = onehotconv(TrainOut,1);
    net = patternnet([ceil(dimension*1.5),dimension,ceil(dimension/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,normalized',onehot');
    if isempty(TestIn)
        pError = 1;
    else
        testNormalized = mapminmax('apply',TestIn',normalization)';
        prediction = onehotconv(net(testNormalized')',2);
        pError = sum(prediction ~= TestOut)/size(prediction,1);
    end
    if ~isfinite(pError)
        pError = 1;
    end
end

function validateInputs(gmax,pMix,rGood,qKeep,lambda0,nMin,nMax,nHarm, ...
        wConFlag,armID,stageCode,randomControlSeed,referenceSizes, ...
        checkpoints,randomReplicates)
    validateattributes(gmax,{'numeric'},{'scalar','integer','positive'});
    validateattributes(pMix,{'numeric'},{'scalar','>=',0,'<=',1});
    validateattributes(rGood,{'numeric'},{'scalar','>',0,'<=',0.5});
    validateattributes(qKeep,{'numeric'},{'scalar','>=',0,'<=',1});
    validateattributes(lambda0,{'numeric'},{'scalar','nonnegative'});
    validateattributes(nMin,{'numeric'},{'scalar','integer','positive'});
    validateattributes(nMax,{'numeric'},{'scalar','integer','>=',nMin});
    validateattributes(nHarm,{'numeric'},{'scalar','integer','nonnegative'});
    validateattributes(wConFlag,{'numeric'},{'scalar','integer','>=',0,'<=',1});
    validateattributes(armID,{'numeric'},{'scalar','integer'});
    validateattributes(stageCode,{'numeric'},{'scalar','integer','>=',0,'<=',3});
    validateattributes(randomControlSeed,{'numeric'},{'scalar','integer','positive'});
    validateattributes(referenceSizes,{'numeric'},{'vector','integer','positive'});
    validateattributes(checkpoints,{'numeric'},{'vector','>',0,'<',1});
    validateattributes(randomReplicates,{'numeric'},{'scalar','integer','positive'});
end

function value = ternary(condition,a,b)
    if condition
        value = a;
    else
        value = b;
    end
end
