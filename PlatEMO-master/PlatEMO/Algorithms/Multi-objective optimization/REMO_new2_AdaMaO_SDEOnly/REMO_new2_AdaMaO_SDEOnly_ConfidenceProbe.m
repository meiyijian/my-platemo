classdef REMO_new2_AdaMaO_SDEOnly_ConfidenceProbe < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% AdaMaO UniformMix with a read-only confidence validity probe

    methods
        function main(Algorithm,Problem)
            %% Parameters kept identical to UniformMix
            [k,gmax,q_keep,lambda0,w_min,n_min,n_max,tau_err, ...
                use_indicator,debug] = Algorithm.ParameterSet( ...
                6,3000,0.80,0.35,0.30,4,6,0.35,1,0);

            %% Initialization kept identical except for sequential EvalIDs
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N,Problem.D,'Latin');
            initialEvalIDs = Problem.FE + (1:N)';
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1),initialEvalIDs);
            InitFE = Problem.FE;
            Archive = Population;

            policy = 'uniform_mix';
            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp         = 1;
            prev_p_err = 1;
            gen        = 0;
            probe      = SDEConfidenceProbeSchema();
            Algorithm.metric.confidenceProbe = probe;

            %% Main optimization loop
            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                % Consume the paired policy draw at the baseline position.
                u = rand(modeStream,1);

                ratio = Problem.FE / Problem.maxFE;
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                diagnostics = RuntimeDiagnostics(Population,N);
                mean_conf   = mean(confidence(:));

                %% Relation-pair mode is unchanged
                relation_mode = 'conservative';
                if prev_p_err > tau_err
                    relation_mode = 'curriculum';
                elseif prev_p_err <= tau_err && mean_conf >= 0.55 && ...
                        diagnostics.coverage < 0.60
                    relation_mode = 'weighted';
                end

                Input = Population.decs;
                switch relation_mode
                    case 'weighted'
                        [XXs,YYs,WWs] = GetRelationPairs_confidence( ...
                            Input,Catalog,confidence);
                    case 'curriculum'
                        [XXs,YYs] = GetRelationPairs_curriculum( ...
                            Input,Catalog,confidence,0.80);
                        WWs = [];
                    otherwise
                        [XXs,YYs] = GetRelationPairs(Input,Catalog);
                        WWs = [];
                end

                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    prev_p_err = 1;
                    continue;
                end

                [net,TrainIn_struct,p_err] = TrainRelationModel( ...
                    XXs,YYs,WWs,w_min,strcmp(relation_mode,'weighted'));

                %% Fixed SDE indicator model is trained as in UniformMix
                IndicatorModel = [];
                Fitness = [];
                if use_indicator
                    try
                        [Fitness,Lp] = IndicatorSelectorSDEOnly( ...
                            Population,Lp);
                    catch
                        Fitness = [];
                    end
                    if ~isempty(Fitness)
                        try
                            IndicatorModel = fitrsvm( ...
                                Population.decs,Fitness, ...
                                'KernelFunction','rbf', ...
                                'KernelScale','auto', ...
                                'Standardize',true);
                        catch
                            IndicatorModel = [];
                        end
                    end
                end

                [candidate_mode,p_ind,modeProgress] = ...
                    ResolveSDECandidateMode( ...
                    policy,~isempty(IndicatorModel),Problem.FE,InitFE, ...
                    Problem.maxFE,u);
                relationMode = relationModeCode(probe,relation_mode);
                candidateMode = candidateModeCode(probe,candidate_mode);

                auditFitness = Fitness;
                if isempty(auditFitness)
                    auditFitness = calFitness_SDE(Population.objs,Lp);
                end
                [solutionRows,pbiPairRows] = ...
                    BuildSDEConfidencePairAudit( ...
                    gen,Problem.FE,Population.adds,Population.objs, ...
                    Population.cons,Catalog,confidence,auditFitness, ...
                    'RelationMode',relationMode, ...
                    'CandidateMode',candidateMode);
                probe.solutionRows = [ ...
                    probe.solutionRows;solutionRows];
                probe.pbiPairRows = [ ...
                    probe.pbiPairRows;pbiPairRows];

                %% Surrogate-assisted candidate selection is unchanged
                Smodel = struct();
                Smodel.X              = Input;
                Smodel.Y              = Catalog;
                Smodel.mp_struct      = TrainIn_struct;
                Smodel.net            = net;
                Smodel.p_err          = p_err;
                Smodel.lambda0        = lambda0;
                Smodel.ratio          = ratio;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode           = candidate_mode;
                Smodel.q_keep         = q_keep;
                Smodel.n_min          = n_min;
                Smodel.n_max          = n_max;

                Next = AdaMaOSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel, ...
                    q_keep,n_min,n_max);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = Next(1:min(n_min,size(Next,1)),:);
                end

                NewSols = [];
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    candidateEvalIDs = Problem.FE + (1:size(Next,1))';
                    networkRows = PredictSDEConfidenceCandidatePairs( ...
                        gen,Problem.FE,candidateEvalIDs,Next, ...
                        Population.adds,Population.decs,Catalog,Smodel);
                    NewSols = Problem.Evaluation(Next,candidateEvalIDs);
                    [networkRows,candidateRows] = ...
                        CompleteSDEConfidenceCandidateAudit( ...
                        networkRows,candidateEvalIDs,NewSols.objs, ...
                        NewSols.cons,Population.adds,Population.objs, ...
                        Population.cons,Problem.optimum,Lp, ...
                        'RelationMode',relationMode, ...
                        'CandidateMode',candidateMode, ...
                        'HistoryEvalIDs',Archive.adds, ...
                        'HistoryObjectives',Archive.objs, ...
                        'HistoryConstraints',Archive.cons);
                    probe.networkPairRows = [ ...
                        probe.networkPairRows;networkRows];
                    probe.candidateRows = [ ...
                        probe.candidateRows;candidateRows];
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                end

                if debug
                    fprintf(['[AdaMaO-%s Gen %3d | FE=%4d/%4d] ', ...
                             'rel=%s cand=%s progress=%.3f Pind=%.3f ', ...
                             'u=%.3f p_err=%.3f prev=%.3f cov=%.3f ', ...
                             'deg=%.3f conf=%.3f n=%d\n'], ...
                        policy,gen,Problem.FE,Problem.maxFE,relation_mode, ...
                        candidate_mode,modeProgress,p_ind,u,p_err,prev_p_err, ...
                        diagnostics.coverage,diagnostics.degeneracy, ...
                        mean_conf,length(NewSols));
                end

                prev_p_err = p_err;
                Population = RefSelect(Archive,Problem.N);
                activeEvalIDs = Population.adds;
                archiveFrontNo = NDSort(Archive.objs,Archive.cons,1);
                currentNDEvalIDs = Archive(archiveFrontNo == 1).adds;
                isFinal = Problem.FE >= Problem.maxFE;
                probe = UpdateSDEConfidenceProbe( ...
                    probe,gen,activeEvalIDs,currentNDEvalIDs,isFinal);
                Algorithm.metric.confidenceProbe = probe;
            end
        end
    end
end

function code = relationModeCode(probe,mode)
    switch mode
        case 'conservative'
            code = probe.codes.relationMode.conservative;
        case 'curriculum'
            code = probe.codes.relationMode.curriculum;
        case 'weighted'
            code = probe.codes.relationMode.weighted;
        otherwise
            code = probe.codes.relationMode.unknown;
    end
end

function code = candidateModeCode(probe,mode)
    switch mode
        case 'explore'
            code = probe.codes.candidateMode.explore;
        case 'indicator'
            code = probe.codes.candidateMode.indicator;
        otherwise
            code = probe.codes.candidateMode.unknown;
    end
end

function diagnostics = RuntimeDiagnostics(Population,Nref)
    PopObj = NormalizeObjectives(Population.objs);
    [N,M] = size(PopObj);

    if N == 0 || M == 0
        diagnostics.coverage   = 0;
        diagnostics.degeneracy = 0;
        return;
    end

    V = UniformPoint(Nref,M,'ILD');
    V = V ./ max(vecnorm(V,2,2),eps);

    Direction = PopObj;
    rowNorm = vecnorm(Direction,2,2);
    zeroRows = rowNorm < 1e-12;
    Direction(zeroRows,:) = 1 ./ max(M,1);
    rowNorm(zeroRows) = vecnorm(Direction(zeroRows,:),2,2);
    Direction = Direction ./ max(rowNorm,eps);

    cosine = 1 - pdist2(Direction,V,'cosine');
    [~,assigned] = max(cosine,[],2);
    diagnostics.coverage = numel(unique(assigned)) / size(V,1);

    Centered = PopObj - mean(PopObj,1);
    if size(Centered,1) < 2 || all(abs(Centered(:)) < 1e-12)
        diagnostics.degeneracy = 0;
        return;
    end
    s = svd(Centered,'econ');
    energy = s.^2;
    total = sum(energy);
    if total < 1e-12
        rank90 = M;
    else
        rank90 = find(cumsum(energy)./total >= 0.90,1,'first');
    end
    diagnostics.degeneracy = max(0,min(1,1 - rank90/max(M,1)));
end

function PopObj = NormalizeObjectives(PopObj)
    zmin = min(PopObj,[],1);
    zmax = max(PopObj,[],1);
    span = zmax - zmin;
    span(span < 1e-12) = 1;
    PopObj = (PopObj - zmin) ./ span;
    PopObj(isnan(PopObj) | isinf(PopObj)) = 0;
end

function [XXs,YYs] = GetRelationPairs_curriculum( ...
    Input,Catalog,confidence,q_keep)
    Catalog = Catalog(:);
    confidence = confidence(:);

    good_idx = find(Catalog == 1);
    rest_idx = find(Catalog ~= 1);
    good_idx = KeepMostConfident(good_idx,confidence,q_keep);
    rest_idx = KeepMostConfident(rest_idx,confidence,q_keep);
    keep_idx = [good_idx;rest_idx];

    if numel(good_idx) < 1 || numel(rest_idx) < 1 || numel(keep_idx) < 2
        XXs = zeros(0,2*size(Input,2));
        YYs = zeros(0,1);
        return;
    end

    Catalog2 = false(numel(keep_idx),1);
    Catalog2(1:numel(good_idx)) = true;
    [XXs,YYs] = GetRelationPairs(Input(keep_idx,:),Catalog2);
end

function idx = KeepMostConfident(idx,confidence,q_keep)
    idx = idx(:);
    if isempty(idx)
        return;
    end
    [~,order] = sort(confidence(idx),'descend');
    n_keep = max(1,ceil(q_keep*numel(idx)));
    idx = idx(order(1:n_keep));
end

function [net,TrainIn_struct,p_err] = TrainRelationModel( ...
    XXs,YYs,WWs,w_min,use_weights)
    if use_weights
        [TrainIn,TrainOut,TrainW,TestIn,TestOut,~] = ...
            DataProcess_confidence(XXs,YYs,WWs);
    else
        [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
        TrainW = [];
    end

    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;

    if use_weights && ~isempty(TrainW)
        EW = TrainW(:)';
        if mean(EW) > 1e-12
            EW = EW ./ mean(EW);
        else
            EW = ones(size(EW));
        end
        EW = max(EW,w_min);
        net = train(net,TrainIn_nor',TrainOut_onehot',[],[],EW);
    else
        net = train(net,TrainIn_nor',TrainOut_onehot');
    end

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
