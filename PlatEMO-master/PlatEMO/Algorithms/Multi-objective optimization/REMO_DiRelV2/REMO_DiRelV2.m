classdef REMO_DiRelV2 < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Difficulty-aware Relation Modeling for Expensive Many-objective Optimization (V2).
%
% Key differences from REMO_DiRel (V1):
%   1. Pair labels: true subset Pareto + PBI fallback (BuildPairBank_ParetoPBI),
%      replacing Catalog-induced pair labels.
%   2. Sub-objective expert bank: K experts on multiple difficulty-aware subsets,
%      not a single easy subset.
%   3. Acquisition: reliability-calibrated expected-win + archive-aware novelty
%      + full-vs-subset disagreement penalty; no batch-relative [0,4] min-max
%      and no fixed 3.9 threshold.
%   4. Difficulty: 5-component (D_prog, D_learn, D_conf, D_sens, D_span) with EMA
%      smoothing; conflict is from max(0, -rho) only (strong negative is NOT
%      treated as redundancy).
%   5. Hidden layer is scalar; K_ens default 5; full-expert minimum weight 0.30.
%
% Public parameters:
%   gmax    --- 1000 --- surrogate-screened candidate budget per generation
%   K_ens   --- 5    --- ensemble size per expert
%   alpha_d --- 0.5  --- EMA smoothing factor for difficulty (new value share)
%   doKrig  --- 0    --- 1 = run Kriging NRMSE for D_learn every krigEvery gens
%   krigEvery -- 3   --- run Kriging every N gens (if doKrig=1)
%   minW_F  --- 0.30 --- full expert minimum weight share

    methods
        function main(Algorithm, Problem)
            % ============= Hyperparameters =============
            [gmax, K_ens, alpha_d, doKrig, krigEvery, minW_F] = ...
                Algorithm.ParameterSet(1000, 5, 0.5, 0, 3, 0.30);

            pairMaxPerExpert = 4000;
            anchorMax = 30;

            % ============= Initial population =============
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

            % ============= State =============
            H = struct();
            H.best_q10 = nan(Problem.M, 1);
            H.best_min = nan(Problem.M, 1);
            H.D_total_prev = nan(Problem.M, 1);

            Diag = struct();
            gen = 0;

            % ============= Configs =============
            % Ablation hooks via environment variables (no API change)
            useTransfer = ~strcmp(getenv('DIREL_USE_TRANSFER'), '0');
            singleSubset = strcmp(getenv('DIREL_SINGLE_SUBSET'), '1');
            gammaNov  = parseEnvNum('DIREL_GAMMA',  0.15);
            lambdaDis = parseEnvNum('DIREL_LAMBDA', 0.25);
            betaUnc   = parseEnvNum('DIREL_BETA',   0.10);

            cfgDiff = struct('emaAlpha', alpha_d);
            cfgPair = struct('pairMaxPerExpert', pairMaxPerExpert);
            cfgRef  = struct('numRef', 10);
            cfgTrain = struct('K_ens', K_ens, 'useTransfer', useTransfer);
            cfgAnchor = struct('anchorMax', anchorMax);
            cfgScore = struct('minFullWeight', minW_F, ...
                              'beta', betaUnc, ...
                              'gamma', gammaNov, ...
                              'lambda', lambdaDis, ...
                              'Lower', Problem.lower, 'Upper', Problem.upper);
            cfgSel  = struct('Lower', Problem.lower, 'Upper', Problem.upper);

            % ============= Main loop =============
            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;
                tStart = tic;

                % --- Step A: difficulty profile ---
                cfgDiff.doKriging = (doKrig == 1) && (mod(gen, krigEvery) == 0);
                [DiffState, H] = DifficultyProfilerV2(Population, Archive, H, gen, cfgDiff);

                % --- Step B: subsets ---
                if singleSubset
                    % Ablation: only full subset
                    Subsets = {1:Problem.M};
                    SubsetInfo = struct('size', Problem.M, 'indices', 1:Problem.M, ...
                        'meanDiff', mean(DiffState.total), 'redundancyRemoved', []);
                else
                    [Subsets, SubsetInfo] = BuildDifficultySubsets( ...
                        DiffState.total, Population.objs, struct());
                end

                % --- Step C: reference vectors per subset ---
                RefCell = BuildSubsetReferenceVectors(Population.objs, Subsets, cfgRef);

                % --- Step D: build pair banks for each subset ---
                PairBank = BuildPairBank_ParetoPBI(Population.decs, Population.objs, ...
                                                   Subsets, RefCell, cfgPair);

                % --- Step E: train experts ---
                Experts = TrainRelationExperts(PairBank, cfgTrain);

                % If no valid experts at all -> fallback to pure GA
                anyValid = any(arrayfun(@(e) e.valid, Experts));

                % --- Step F: generate candidates via GA ---
                Cand = generateCandidates(Problem, Population, Archive, gmax);

                % --- Step G: select anchors ---
                Anchors = SelectRelationAnchors(Archive.decs, Archive.objs, cfgAnchor);

                % --- Step H: score candidates ---
                scoreDbg = [];
                if anyValid
                    [scores, scoreDbg] = ScoreCandidates_DiRel(Cand, Anchors, Experts, ...
                                                              Archive.decs, cfgScore);
                else
                    scores = zeros(size(Cand, 1), 1);
                end

                % --- Step I: pick top-q with diversity constraint ---
                remain = Problem.maxFE - Problem.FE;
                qBatch = min(5, max(1, remain));
                if anyValid
                    selIdx = SelectTopDiverse(Cand, scores, Archive.decs, qBatch, cfgSel);
                else
                    selIdx = [];
                end
                if isempty(selIdx)
                    % Fallback: pure GA offspring
                    Next = fallbackOffspring(Problem, Population, Archive, qBatch);
                else
                    Next = Cand(selIdx, :);
                end

                % --- Step J: sanitize and evaluate ---
                Next = sanitizeCandidates(Next, Problem, Archive, remain);
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % --- Step K: update population ---
                Population = updatePopulation(Archive, Problem.N);

                % --- Step L: diagnostics ---
                runtime = toc(tStart);
                try
                    Diag = LogDiagnostics_DiRel(Diag, gen, DiffState, SubsetInfo, ...
                        PairBank, Experts, scoreDbg, selIdx, Cand, Archive, runtime);
                catch
                    % diagnostic failure should not crash main loop
                end
            end

            % Optionally stash Diag into Algorithm metric (best-effort)
            try
                Algorithm.metric.Diag = Diag;
            catch
            end
        end
    end
end


% ==========================================================
%  Local helpers
% ==========================================================

function v = parseEnvNum(name, defaultVal)
    raw = getenv(name);
    if isempty(raw)
        v = defaultVal;
    else
        v = str2double(raw);
        if isnan(v), v = defaultVal; end
    end
end

function Cand = generateCandidates(Problem, Population, Archive, gmax)
% Produce candidate decision matrix via multiple GA rounds with mixed parents
    if length(Archive) >= length(Population)
        parents = Archive.decs;
    else
        parents = Population.decs;
    end
    % If population is small, augment with random
    if size(parents, 1) < 10
        extra = UniformPoint(20, Problem.D, 'Latin');
        extra = repmat(Problem.upper - Problem.lower, 20, 1) .* extra + ...
                repmat(Problem.lower, 20, 1);
        parents = [parents; extra];
    end

    Cand = [];
    target = min(gmax, max(50, 5 * Problem.N));
    while size(Cand, 1) < target
        ga = OperatorGA(Problem, parents, {1, 20, 1, 20});
        Cand = [Cand; ga]; %#ok<AGROW>
        if size(ga, 1) == 0, break; end
    end
    if size(Cand, 1) > target
        Cand = Cand(1:target, :);
    end
end

function Next = fallbackOffspring(Problem, Population, ~, q)
    parents = Population.decs;
    Next = OperatorGA(Problem, parents, {1, 20, 1, 20});
    if size(Next, 1) > q
        Next = Next(1:q, :);
    end
end

function Next = sanitizeCandidates(Next, Problem, Archive, remain)
    if isempty(Next), return; end
    Lower = repmat(Problem.lower, size(Next, 1), 1);
    Upper = repmat(Problem.upper, size(Next, 1), 1);
    Next = min(max(Next, Lower), Upper);
    Next = unique(Next, 'rows', 'stable');
    if ~isempty(Archive)
        old = ismember(Next, Archive.decs, 'rows');
        Next = Next(~old, :);
    end
    if size(Next, 1) > remain
        Next = Next(1:remain, :);
    end
end

function Population = updatePopulation(Archive, N)
% Use environmental selection via NDSort + crowding-like
% to keep the population diverse and elite.
    objs = Archive.objs;
    nA = length(Archive);
    if nA <= N
        Population = Archive;
        return;
    end
    try
        [FrontNo, MaxF] = NDSort(objs, N);
        Next = false(1, nA);
        % include up to last full front
        for f = 1:MaxF
            idx = find(FrontNo == f);
            if sum(Next) + numel(idx) <= N
                Next(idx) = true;
            else
                slots = N - sum(Next);
                if slots > 0
                    % crowding-like: pick farthest in obj space
                    sel = farthestFirst(objs(idx, :), slots);
                    Next(idx(sel)) = true;
                end
                break;
            end
        end
        Population = Archive(Next);
    catch
        % fallback: random
        idx = randperm(nA, N);
        Population = Archive(idx);
    end
end

function pick = farthestFirst(F, k)
    n = size(F, 1);
    if k >= n, pick = 1:n; return; end
    Fmin = min(F, [], 1); Fmax = max(F, [], 1);
    span = max(Fmax - Fmin, 1e-12);
    Fn = (F - Fmin) ./ span;
    pick = zeros(1, k);
    pick(1) = 1;
    dist = sqrt(sum((Fn - Fn(1, :)).^2, 2));
    for i = 2:k
        [~, idx] = max(dist);
        pick(i) = idx;
        nd = sqrt(sum((Fn - Fn(idx, :)).^2, 2));
        dist = min(dist, nd);
    end
end
