classdef CMC_HCV_Audit < ALGORITHM
%CMC_HCV_AUDIT Operationally exact HCV host with read-only audit replay.

    methods
        function main(Algorithm,Problem)
            [gmax,pMix,rGood,qKeep,lambda0,nMin,nMax,nHarm,wConFlag, ...
                armID,stageCode,randomControlSeed,referenceSizes, ...
                checkpoints,randomReplicates] = Algorithm.ParameterSet( ...
                3000,0.50,0.25,0.80,0.35,4,6,2,0,100,0,1, ...
                [4096 8192 16384],[0.20 0.50 0.80],500);
            if armID ~= 100
                error('CMC:AuditArmMismatch','CMC_HCV_Audit requires ArmID 100.');
            end
            validateAuditParameters(gmax,pMix,rGood,qKeep,lambda0,nMin, ...
                nMax,nHarm,wConFlag,stageCode,randomControlSeed, ...
                referenceSizes,checkpoints,randomReplicates);
            if wConFlag == 1
                wCon = 'scaled';
            else
                wCon = 'legacy';
            end

            if Problem.D <= 10
                N = 11*Problem.D - 1;
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
            thresholds = CMCProtocol('stage1','smoke').Thresholds;

            while Algorithm.NotTerminated(Archive)
                generation = generation + 1;
                u = rand(modeStream,1);
                ratio = Problem.FE / Problem.maxFE;
                k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                [~,~,Catalog,~,Ref] = ComplementaryPBI_Classification( ...
                    Population,ratio,'k',k_eff,'theta',5, ...
                    'rGood',rGood,'nHarm',nHarm);

                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N,wCon);
                    continue;
                end

                [net,TrainIn_struct,p_err] = ...
                    TrainOriginalRelationModel(XXs,YYs);

                IndicatorModel = [];
                try
                    [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp);
                catch
                    Fitness = [];
                end
                if ~isempty(Fitness)
                    try
                        IndicatorModel = fitrsvm(Population.decs,Fitness, ...
                            'KernelFunction','rbf', ...
                            'KernelScale','auto','Standardize',true);
                    catch
                        IndicatorModel = [];
                    end
                end

                candidate_mode = ResolveUniformMixMode( ...
                    ~isempty(IndicatorModel),u,pMix);
                attemptedMode = 'explore';
                if u < pMix
                    attemptedMode = 'indicator';
                end

                Smodel = struct();
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;
                Smodel.lambda0 = lambda0;
                Smodel.ratio = ratio;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode = candidate_mode;
                Smodel.q_keep = qKeep;
                Smodel.n_min = nMin;
                Smodel.n_max = nMax;
                Smodel.AttemptedMode = attemptedMode;
                Smodel.Generation = generation;
                Smodel.RandomControlSeed = randomControlSeed;
                Smodel.ArchiveDec = Archive.decs;

                [Next,trace] = auditedSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel, ...
                    qKeep,nMin,nMax,armID);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = Next(1:min(nMin,size(Next,1)),:);
                end

                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                end
                postClipK = size(Next,1);

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
                            randomControlSeed,thresholds);
                        Algorithm.metric.cmcSnapshots = ...
                            [Algorithm.metric.cmcSnapshots;snapshot];
                        Algorithm.metric.cmcReference = ...
                            [Algorithm.metric.cmcReference;reference];
                        checkpointDone(due) = true;
                    end
                end

                if ~isempty(Next) && remain > 0
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                end
                Population = RefSelect(Archive,Problem.N,wCon);
            end
        end
    end
end

function [Next,trace] = auditedSelection( ...
        Problem,Ref,Input,gmax,Smodel,qKeep,nMin,nMax,armID)
    feBefore = Problem.FE;
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
    if Problem.FE ~= feBefore || ~isequal(rng,operationalAfter)
        error('CMC:TraceReplayStateDrift', ...
            'The read-only trace replay changed FE or operational RNG.');
    end
end

function [net,TrainIn_struct,p_err] = TrainOriginalRelationModel(XXs,YYs)
    [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,TrainIn_nor',TrainOut_onehot');

    if isempty(TestIn)
        p_err = 1;
    else
        TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
        TestPre = onehotconv(net(TestIn_nor')',2);
        p_err = sum(TestPre ~= TestOut) / size(TestPre,1);
    end
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
end

function validateAuditParameters(gmax,pMix,rGood,qKeep,lambda0,nMin,nMax, ...
        nHarm,wConFlag,stageCode,randomControlSeed,referenceSizes, ...
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
    validateattributes(stageCode,{'numeric'},{'scalar','integer','>=',0,'<=',1});
    validateattributes(randomControlSeed,{'numeric'}, ...
        {'scalar','integer','positive'});
    validateattributes(referenceSizes,{'numeric'}, ...
        {'vector','integer','positive','numel',3});
    validateattributes(checkpoints,{'numeric'},{'vector','>',0,'<',1});
    validateattributes(randomReplicates,{'numeric'}, ...
        {'scalar','integer','positive'});
end
