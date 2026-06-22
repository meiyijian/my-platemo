function DR_RunMain(mode, ~, Problem, params)
% DR_RunMain - Shared main loop for REMO objective-reduction ablations.

    if nargin < 4 || isempty(params)
        error('DR_RunMain:MissingParams', 'Algorithm parameters must be read inside the algorithm class and passed in.');
    end

    k_red = params.k_red;
    tau_conf = params.tau_conf;
    k_ref = params.k_ref;
    gmax = params.gmax;
    K_ens = params.K_ens;
    nCells = params.nCells;
    scalarGap = params.scalarGap;
    lockGen = params.lockGen;
    notTerminated = params.notTerminated;

    pairMax = 6000;
    anchorMax = 30;
    lockGen = max(1, round(lockGen));

    if Problem.D <= 10
        N = 11 * Problem.D - 1;
    else
        N = 100;
    end
    PopDec = UniformPoint(N, Problem.D, 'Latin');
    Population = Problem.Evaluation( ...
        repmat(Problem.upper - Problem.lower, N, 1) .* PopDec + ...
        repmat(Problem.lower, N, 1));
    Archive = Population;

    ReductionState = [];
    if strcmpi(mode, 'randfixed')
        ReductionState = DR_BuildRandomReduction(Population.objs, k_red);
        ReductionState.IsFixed = true;
    end

    gen = 0;
    while notTerminated(Archive)
        gen = gen + 1;

        Ref = RefSelect(Population, k_ref);
        Input = Population.decs;
        PopObj = Population.objs;
        RefObj = Ref.objs;

        [ReducedObj, ReductionState, isLocked] = getReducedObjectives( ...
            mode, gen, lockGen, Input, PopObj, k_red, nCells, ReductionState);

        [XX_F, YY_F, Catalog_F] = DR_GetRelationPairsBudgeted( ...
            Input, PopObj, pairMax, RefObj, scalarGap);
        Ref_S_obj = makeReferenceObjectives(size(RefObj, 1), size(ReducedObj, 2), ReducedObj);
        [XX_S, YY_S, Catalog_S] = DR_GetRelationPairsBudgeted( ...
            Input, ReducedObj, pairMax, Ref_S_obj, scalarGap);

        Next = [];
        SelectInfo = [];
        if ~isempty(XX_F) && ~isempty(XX_S)
            DualNet = DR_TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens);

            Smodel = struct();
            Smodel.X = Input;
            Smodel.Y_F = Catalog_F;
            Smodel.Y_S = Catalog_S;
            Smodel.DualNet = DualNet;
            Smodel.ReductionState = ReductionState;
            Smodel.tau_conf = tau_conf;
            Smodel.anchorMax = anchorMax;
            Smodel.margin_F = 0.15;
            Smodel.margin_S = 0.15;
            Smodel.uncertainty_F = tau_conf.^2;
            Smodel.uncertainty_S = tau_conf.^2;
            Smodel.tieWeight = 0.5;
            Smodel.betaUncertainty = 0.25;
            Smodel.lambdaDisagreement = 0.75;
            Smodel.gammaNovelty = 0.25;
            Smodel.scoreThreshold = 3.4;

            [Next, SelectInfo] = DR_ArbitratedSelection(Problem, Ref, Input, gmax, Smodel);
        end

        if isempty(Next)
            Next = fallbackOffspring(Problem, Ref, Input);
        end

        if isfield(params, 'recordDiag') && ~isempty(params.recordDiag)
            params.recordDiag(gen, makeDiagnostic(mode, gen, isLocked, ReductionState, SelectInfo));
        end

        remain = Problem.maxFE - Problem.FE;
        if remain > 0
            Next = sanitizeCandidates(Next, Problem, Archive, remain);
            Archive = [Archive, Problem.Evaluation(Next)];
        end

        Population = RefSelect(Archive, Problem.N);
    end
end


function [ReducedObj, State, isLocked] = getReducedObjectives(mode, gen, lockGen, Input, PopObj, kRed, nCells, State)
    isLocked = false;
    cfg = struct('nCells', nCells);

    switch lower(mode)
        case 'randfixed'
            isLocked = true;
            [ReducedObj, State] = DR_ApplyReduction(PopObj, State);

        case 'lkcfixed'
            if isempty(State) || gen <= lockGen
                State = DR_BuildLKCReduction(Input, PopObj, kRed, cfg);
                if gen >= lockGen
                    State.IsFixed = true;
                    isLocked = true;
                end
                ReducedObj = State.AggregatedObj;
            else
                isLocked = true;
                [ReducedObj, State] = DR_ApplyReduction(PopObj, State);
            end

        case 'lkcdynamic'
            State = DR_BuildLKCReduction(Input, PopObj, kRed, cfg);
            ReducedObj = State.AggregatedObj;

        otherwise
            error('DR_RunMain:UnknownMode', 'Unknown reduction mode: %s', mode);
    end
end


function RefObj = makeReferenceObjectives(nRef, M, Obj)
    if M <= 0
        RefObj = [];
        return;
    end
    nRef = max(1, nRef);
    P_min = min(Obj, [], 1);
    P_span = max(max(Obj, [], 1) - P_min, 1e-12);
    if M == 1
        RefObj = linspace(P_min, P_min + P_span, nRef)';
    else
        RefObj = UniformPoint(nRef, M, 'ILD');
        RefObj = RefObj .* P_span + P_min;
    end
end


function Diag = makeDiagnostic(mode, gen, isLocked, State, SelectInfo)
    Diag = struct();
    Diag.mode = mode;
    Diag.gen = gen;
    Diag.isLocked = isLocked;
    Diag.Groups = State.Groups;
    Diag.GroupWeights = State.GroupWeights;
    Diag.GroupReliability = State.GroupReliability;
    Diag.Sim = State.Sim;
    Diag.ClusterK = State.ClusterK;
    Diag.Note = State.Note;

    Diag.fullUncertainRatio = 1;
    Diag.subTriggeredRatio = 0;
    Diag.disagreementRatio = 0;
    Diag.fullDominatedRatio = 0;
    Diag.subTieBreakDominatedRatio = 0;
    if isstruct(SelectInfo) && isfield(SelectInfo, 'fullUncertainRatio')
        Diag.fullUncertainRatio = SelectInfo.fullUncertainRatio;
        Diag.subTriggeredRatio = SelectInfo.subTriggeredRatio;
        Diag.disagreementRatio = SelectInfo.disagreementRatio;
        Diag.fullDominatedRatio = SelectInfo.fullDominatedRatio;
        Diag.subTieBreakDominatedRatio = SelectInfo.subTieBreakDominatedRatio;
    end
end


function Next = fallbackOffspring(Problem, Ref, Input)
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 20, 1, 20});
end


function Next = sanitizeCandidates(Next, Problem, Archive, remain)
    if isempty(Next)
        Next = randomFill(Problem, min(4, remain));
        return;
    end

    Lower = repmat(Problem.lower, size(Next, 1), 1);
    Upper = repmat(Problem.upper, size(Next, 1), 1);
    Next = min(max(Next, Lower), Upper);
    Next = unique(Next, 'rows', 'stable');

    if ~isempty(Archive)
        old = ismember(Next, Archive.decs, 'rows');
        Next = Next(~old, :);
    end

    if isempty(Next)
        Next = randomFill(Problem, min(4, remain));
    elseif size(Next, 1) > remain
        Next = Next(1:remain, :);
    end
end


function X = randomFill(Problem, n)
    if n <= 0
        X = zeros(0, Problem.D);
        return;
    end
    U = UniformPoint(n, Problem.D, 'Latin');
    X = repmat(Problem.upper - Problem.lower, n, 1) .* U + repmat(Problem.lower, n, 1);
end
