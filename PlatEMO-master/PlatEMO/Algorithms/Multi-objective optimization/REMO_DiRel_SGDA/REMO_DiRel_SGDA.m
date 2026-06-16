classdef REMO_DiRel_SGDA < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Structure-Guided Difficulty-aware Arbitration for REMO_DiRel.
%
% Public parameters:
%   gmax         --- 1000 --- surrogate-screened candidate budget
%   K_ens        --- 5    --- ensemble size per relation expert
%   alpha_d      --- 0.5  --- difficulty EMA smoothing factor
%   fullMargin   --- 0.20 --- full expert relation margin threshold
%   fullConfThr  --- 0.55 --- full expert confidence threshold
%   groupConfThr --- 0.60 --- group expert confidence threshold

    methods
        function main(Algorithm, Problem)
            [gmax, K_ens, alpha_d, fullMargin, fullConfThr, groupConfThr] = ...
                Algorithm.ParameterSet(1000, 5, 0.5, 0.20, 0.55, 0.60);

            pairMaxPerExpert = 4000;
            anchorMax = 30;

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

            H = struct();
            H.best_q10 = nan(Problem.M, 1);
            H.best_min = nan(Problem.M, 1);
            H.D_total_prev = nan(Problem.M, 1);
            Diag = struct();
            gen = 0;

            cfgDiff = struct('emaAlpha', alpha_d);
            cfgGroup = struct('simThreshold', 0.65, ...
                              'easyReliabilityThr', 0.45, ...
                              'diffStdLimit', 0.25);
            cfgPair = struct('pairMaxPerExpert', pairMaxPerExpert);
            cfgRef = struct('numRef', 10);
            cfgAnchor = struct('anchorMax', anchorMax);
            cfgTrainBase = struct('K_ens', K_ens, 'useTransfer', true);
            cfgScore = struct('fullMargin', fullMargin, ...
                              'fullConfThr', fullConfThr, ...
                              'groupConfThr', groupConfThr, ...
                              'groupMargin', 0.15, ...
                              'minGroupReliability', 0.30, ...
                              'beta', 0.10, ...
                              'lambda', 0.25, ...
                              'gamma', 0.15, ...
                              'Lower', Problem.lower, ...
                              'Upper', Problem.upper);
            cfgSel = struct('Lower', Problem.lower, 'Upper', Problem.upper);

            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;
                tStart = tic;

                [DiffState, H] = DifficultyProfiler_SGDA(Population, Archive, H, gen, cfgDiff);

                [Groups, GroupInfo] = BuildObjectiveGroups_SGDA( ...
                    Archive.decs, Archive.objs, DiffState.total, cfgGroup);
                if isempty(Groups)
                    Groups = num2cell(1:Problem.M);
                end

                Subsets = [Groups, {1:Problem.M}];
                ExpertMeta = buildExpertMeta(Groups, GroupInfo, Problem.M, DiffState.total);

                RefCell = BuildSubsetReferenceVectors_SGDA(Archive.objs, Subsets, cfgRef);
                PairBank = BuildPairBank_ParetoPBI_SGDA(Archive.decs, Archive.objs, ...
                    Subsets, RefCell, cfgPair);

                cfgTrain = cfgTrainBase;
                cfgTrain.meta = ExpertMeta;
                Experts = TrainRelationExperts_SGDA(PairBank, cfgTrain);
                anyValid = any(arrayfun(@(e) e.valid, Experts));

                Cand = generateCandidates(Problem, Population, Archive, gmax);
                Cand = sanitizeCandidatePool(Cand, Problem, Archive);
                Anchors = SelectRelationAnchors_SGDA(Archive.decs, Archive.objs, cfgAnchor);

                scoreDbg = [];
                if anyValid && ~isempty(Cand)
                    [scores, scoreDbg] = ScoreCandidates_SGDA(Cand, Anchors, Experts, ...
                        Archive.decs, cfgScore);
                else
                    scores = zeros(size(Cand, 1), 1);
                end

                remain = Problem.maxFE - Problem.FE;
                qBatch = min(5, max(1, remain));
                if anyValid && ~isempty(Cand)
                    selIdx = SelectTopDiverse_SGDA(Cand, scores, Archive.decs, qBatch, cfgSel);
                else
                    selIdx = [];
                end

                if isempty(selIdx)
                    Next = fallbackOffspring(Problem, Population, qBatch);
                else
                    Next = Cand(selIdx, :);
                end

                Next = sanitizeCandidates(Next, Problem, Archive, remain);
                if isempty(Next) && remain > 0
                    Next = randomFill(Problem, min(qBatch, remain));
                    Next = sanitizeCandidates(Next, Problem, Archive, remain);
                end
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                Population = updatePopulation(Archive, Problem.N);

                runtime = toc(tStart);
                try
                    Diag = LogDiagnostics_SGDA(Diag, gen, DiffState, Groups, GroupInfo, ...
                        PairBank, Experts, scoreDbg, selIdx, Cand, Archive, runtime);
                catch
                end
            end

            try
                Algorithm.metric.Diag = Diag;
            catch
            end
        end
    end
end

function Meta = buildExpertMeta(Groups, GroupInfo, M, dScore)
    K = numel(Groups) + 1;
    empty = struct('groupDifficulty', 1, 'groupReliability', 0, ...
        'isEasyGroup', false, 'expertType', 'group', 'groupIndex', 0);
    Meta = repmat(empty, 1, K);
    for k = 1:numel(Groups)
        Meta(k).groupDifficulty = GroupInfo.groupDifficulty(k);
        Meta(k).groupReliability = GroupInfo.groupReliability(k);
        Meta(k).isEasyGroup = GroupInfo.isEasyGroup(k);
        Meta(k).expertType = 'group';
        Meta(k).groupIndex = k;
    end
    Meta(K).groupDifficulty = mean(dScore(:)) + 0.5*std(dScore(:));
    Meta(K).groupReliability = 1;
    Meta(K).isEasyGroup = false;
    Meta(K).expertType = 'full';
    Meta(K).groupIndex = 0;
end

function Cand = generateCandidates(Problem, Population, Archive, gmax)
    if length(Archive) >= length(Population)
        parents = Archive.decs;
    else
        parents = Population.decs;
    end
    if size(parents, 1) < 10
        extra = UniformPoint(20, Problem.D, 'Latin');
        extra = repmat(Problem.upper - Problem.lower, 20, 1) .* extra + ...
                repmat(Problem.lower, 20, 1);
        parents = [parents; extra];
    end

    target = min(gmax, max(50, 5*Problem.N));
    Cand = zeros(0, Problem.D);
    while size(Cand, 1) < target
        ga = OperatorGA(Problem, parents, {1, 20, 1, 20});
        if isempty(ga)
            break;
        end
        Cand = [Cand; ga]; %#ok<AGROW>
    end
    if size(Cand, 1) > target
        Cand = Cand(1:target, :);
    end
end

function Cand = sanitizeCandidatePool(Cand, Problem, Archive)
    if isempty(Cand)
        return;
    end
    Lower = repmat(Problem.lower, size(Cand, 1), 1);
    Upper = repmat(Problem.upper, size(Cand, 1), 1);
    Cand = min(max(Cand, Lower), Upper);
    Cand = unique(Cand, 'rows', 'stable');
    if ~isempty(Archive)
        old = ismember(Cand, Archive.decs, 'rows');
        Cand = Cand(~old, :);
    end
end

function Next = fallbackOffspring(Problem, Population, q)
    Next = OperatorGA(Problem, Population.decs, {1, 20, 1, 20});
    if size(Next, 1) > q
        Next = Next(1:q, :);
    end
end

function Next = sanitizeCandidates(Next, Problem, Archive, remain)
    if isempty(Next) || remain <= 0
        Next = zeros(0, Problem.D);
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
    if size(Next, 1) > remain
        Next = Next(1:remain, :);
    end
end

function X = randomFill(Problem, n)
    if n <= 0
        X = zeros(0, Problem.D);
        return;
    end
    U = UniformPoint(n, Problem.D, 'Latin');
    X = repmat(Problem.upper - Problem.lower, n, 1) .* U + ...
        repmat(Problem.lower, n, 1);
end

function Population = updatePopulation(Archive, N)
    objs = Archive.objs;
    nA = length(Archive);
    if nA <= N
        Population = Archive;
        return;
    end
    try
        [FrontNo, MaxF] = NDSort(objs, N);
        Next = false(1, nA);
        for f = 1:MaxF
            idx = find(FrontNo == f);
            if sum(Next) + numel(idx) <= N
                Next(idx) = true;
            else
                slots = N - sum(Next);
                if slots > 0
                    sel = farthestFirst(objs(idx, :), slots);
                    Next(idx(sel)) = true;
                end
                break;
            end
        end
        Population = Archive(Next);
    catch
        idx = randperm(nA, N);
        Population = Archive(idx);
    end
end

function pick = farthestFirst(F, k)
    n = size(F, 1);
    if k >= n
        pick = 1:n;
        return;
    end
    Fmin = min(F, [], 1);
    Fmax = max(F, [], 1);
    span = max(Fmax - Fmin, 1e-12);
    Fn = (F - Fmin) ./ span;
    pick = zeros(1, k);
    pick(1) = 1;
    dist = sqrt(sum((Fn - Fn(1, :)).^2, 2));
    for i = 2:k
        [~, idx] = max(dist);
        pick(i) = idx;
        dNew = sqrt(sum((Fn - Fn(idx, :)).^2, 2));
        dist = min(dist, dNew);
    end
end
