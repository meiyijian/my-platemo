classdef LTGGPAudit < ALGORITHM
% Lambdat030 production trajectory with stable evaluation identity audit.
%   Mirrors PWGGPAudit (the lambda_t = 0.50 audit) with the Lambdat030
%   exploration branch: DiversifiedInfillSelection comes from the
%   REMO_UniformMix_Pruned_Weighted_Lambdat030 private copy and keeps the
%   constant ambiguity reward A_t(x) = R~(x) + 0.30*U~(x). Everything else
%   (PAQC, relation model, indicator branch, pMix, RefSelect) is identical
%   to the frozen production class.
%   The ADAMAO_LAMBDAT030_DIAG global is intentionally NOT initialized
%   here: recordLambdaDiagnostics only writes bookkeeping records and never
%   draws random numbers, so leaving the collector disabled cannot change
%   the optimization path.
    properties
        auditRuntime = 0;   % Seconds spent in audit bookkeeping only
        auditData    = [];  % Struct with evaluations/snapshots/trajectory
    end

    methods
        function Catalog = selectTrainingCatalog(~, views)
            Catalog = views.CatalogCurrent;
        end
    end

    methods
        function main(obj, Problem)
            [gmax,pMix,rGood,qKeep,nMax] = ...
                obj.ParameterSet(3000,0.50,0.25,0.70,6);
            validateUniformMixParameters( ...
                gmax,pMix,rGood,qKeep,nMax);

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            N = min(N,max(0,floor(Problem.maxFE - Problem.FE)));
            initialFE = N;
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive = Population;
            ArchiveEvalIDs = (1:N)';   % Stable EvalIDs of all evaluated solutions
            PopulationEvalIDs = ArchiveEvalIDs;

            modeStream = CreateSDECandidateModeStream(obj.run);
            Lp = 1;   % Frozen entry initializes Lp=1; must match production.

            % ---- Audit buffers (preallocated against maxFE) ----
            maxRows = Problem.maxFE;
            evalID       = (1:maxRows)';
            evalDecision = zeros(maxRows,Problem.D);
            evalObj      = zeros(maxRows,Problem.M);
            evalGen      = zeros(maxRows,1);
            evalDecision(1:N,:) = Population.decs;
            evalObj(1:N,:)      = Population.objs;
            evalGen(1:N)        = 0;
            nEval = N;

            snapshots  = struct([]);
            trajectory = struct([]);
            gen = 0;

            % NOTE: NotTerminated throws PlatEMO:Termination once FE reaches
            % maxFE (same as the frozen entry; Solve catches it silently).
            % We catch it here so the audit bookkeeping after the loop runs.
            terminated = false;
            while ~terminated
                try
                    terminated = ~obj.NotTerminated(Archive);
                catch err
                    if strcmp(err.identifier,'PlatEMO:Termination')
                        terminated = true;
                    else
                        rethrow(err);
                    end
                end
                if terminated
                    break;
                end
                gen = gen + 1;
                FEBefore = Problem.FE;
                u = rand(modeStream,1);
                ratio = Problem.FE / Problem.maxFE;
                k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));

                % ---- Label computation with audit (frozen statement order)
                auditT = tic;
                [CatalogCurrent, Ref, views] = LVComputeLabelViews( ...
                    Population,ratio,'Nref',N,'k',k_eff, ...
                    'theta',5,'rGood',rGood);
                Catalog = obj.selectTrainingCatalog(views);

                % ---- Snapshot (before training; Population is the current
                %      population used by HV, unchanged from loop start)
                RefEvalID = PopulationEvalIDs(views.RefLocalIdx);
                S = struct();
                S.SnapshotID        = gen;
                S.Generation        = gen;
                S.FE                = Problem.FE;
                S.Ratio             = ratio;
                S.Alpha             = views.Alpha;
                S.PopulationEvalID  = PopulationEvalIDs;
                S.PopulationDec     = Population.decs;
                S.PopulationObj     = Population.objs;
                S.RefEvalID         = RefEvalID;
                S.RefObj            = views.RefObj;
                S.kEff              = k_eff;
                S.Nref              = N;
                S.Theta             = 5;
                S.DirectionSource   = views.DirectionSource;
                S.FallbackReason    = views.FallbackReason;
                S.Front1Count       = views.Front1Count;
                S.ClusterCount      = views.ClusterCount;
                S.UniqueDirectionCount = views.UniqueDirectionCount;
                S.V                 = views.V;
                S.Delta             = views.Delta;
                S.AnchorPositiveRate= views.AnchorPositiveRate;
                S.AnchorNormalizedG = views.AnchorNormalizedG;
                S.AnchorMargin      = views.AnchorMargin;
                S.LabelDyn          = views.LabelDyn;
                S.ScoreV            = views.ScoreV;
                S.ScoreHybrid       = views.ScoreHybrid;
                S.CatalogCurrent    = views.CatalogCurrent;
                S.ScoreVStd         = views.ScoreVStd;
                S.LabelDynStd       = views.LabelDynStd;
                S.EffectiveScaleRatio = views.EffectiveScaleRatio;
                S.TrainingCatalog   = Catalog;
                if isempty(snapshots)
                    snapshots = S;
                else
                    snapshots(end+1) = S; %#ok<AGROW>
                end
                obj.auditRuntime = obj.auditRuntime + toc(auditT);

                % ---- Frozen Lambdat030 pipeline ----
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    error('LTGGP:NoPairs','No relation training pairs');
                end

                [net,TrainIn_struct] = ...
                    TrainOriginalRelationModel(XXs,YYs);

                IndicatorModel = [];
                try
                    [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp); %#ok<NASGU>
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

                Smodel = struct();
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode = candidate_mode;

                Next = DiversifiedInfillSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel, ...
                    qKeep,nMax);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = unique(Next,'rows','stable');
                    Next = Next(1:min(nMax,size(Next,1)),:);
                end

                selectedEvalIDs = [];
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    NewSols = Problem.Evaluation(Next);
                    newIDs = (max(ArchiveEvalIDs)+1 : ...
                        max(ArchiveEvalIDs)+length(NewSols))';
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                    ArchiveEvalIDs = [ArchiveEvalIDs;newIDs]; %#ok<AGROW>
                    selectedEvalIDs = newIDs;
                    evalDecision(nEval+1:nEval+length(NewSols),:) = NewSols.decs;
                    evalObj(nEval+1:nEval+length(NewSols),:)      = NewSols.objs;
                    evalGen(nEval+1:nEval+length(NewSols))        = gen;
                    nEval = nEval + length(NewSols);
                end
                [Population,popIdx] = LVRefSelectWithIndex(Archive,Problem.N);
                PopulationEvalIDs = ArchiveEvalIDs(popIdx);

                T = struct('Generation',gen,'FEBefore',FEBefore, ...
                    'FEAfter',Problem.FE,'CandidateMode',candidate_mode, ...
                    'SelectedEvalID',selectedEvalIDs, ...
                    'PopulationEvalIDAfter',PopulationEvalIDs);
                if isempty(trajectory)
                    trajectory = T;
                else
                    trajectory(end+1) = T; %#ok<AGROW>
                end
            end

            % ---- Trim audit buffers to completed FE ----
            completedFE = Problem.FE;
            evaluations = struct( ...
                'EvalID',evalID(1:completedFE), ...
                'Decision',evalDecision(1:completedFE,:), ...
                'Objective',evalObj(1:completedFE,:), ...
                'Generation',evalGen(1:completedFE));

            % ---- Persist audit results on the object ----
            obj.auditData = struct( ...
                'evaluations',evaluations, ...
                'snapshots',snapshots, ...
                'trajectory',trajectory, ...
                'finalPopulation',struct('dec',Archive.decs,'obj',Archive.objs), ...
                'auditRuntime',obj.auditRuntime, ...
                'initialFE',initialFE, ...
                'populationN',Problem.N, ...
                'completedFE',completedFE);
        end
    end
end

function validateUniformMixParameters(gmax,pMix,rGood,qKeep,nMax)
%validateUniformMixParameters Check classification and batch parameters.
    if ~isnumeric(gmax) || ~isscalar(gmax) || ~isfinite(gmax) || ...
            gmax < 1 || gmax ~= floor(gmax)
        error('AdaMaO:InvalidParameter', ...
            'gmax must be a positive integer.');
    end
    if ~isnumeric(pMix) || ~isscalar(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('AdaMaO:InvalidParameter', ...
            'pMix must be in [0,1].');
    end
    if ~isnumeric(rGood) || ~isscalar(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('AdaMaO:InvalidParameter', ...
            'rGood must be in (0,0.5].');
    end
    if ~isnumeric(qKeep) || ~isscalar(qKeep) || ~isfinite(qKeep) || ...
            qKeep < 0 || qKeep > 1
        error('AdaMaO:InvalidParameter', ...
            'qKeep must be in [0,1].');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('AdaMaO:InvalidParameter', ...
            'nMax must be a positive integer.');
    end
end

function [net,TrainIn_struct] = TrainOriginalRelationModel(XXs,YYs)
%TrainOriginalRelationModel Keep the original split and network topology.
    [TrainIn,TrainOut] = DataProcess(XXs,YYs);
    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,TrainIn_nor',TrainOut_onehot');
end
