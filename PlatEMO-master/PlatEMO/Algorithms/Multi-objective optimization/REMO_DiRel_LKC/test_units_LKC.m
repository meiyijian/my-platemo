function test_units_LKC()
% test_units_LKC - Lightweight checks for LKC objective structure utilities.

    here = fileparts(mfilename('fullpath'));
    addpath(here);
    rng(1);

    N = 80;
    x = linspace(0, 1, N)';
    PopDec = [x, rand(N, 2)];
    PopObj = [x, x + 0.005 * randn(N, 1), -x + 0.005 * randn(N, 1)];
    cfg = struct('nCells', 5, 'minGroupReliability', 0.5);

    S = BuildObjectiveStructure_LKC(PopDec, PopObj, cfg);
    assert(size(S.Gamma, 1) == 3);
    assert(size(S.Gamma, 2) == 5 * 3);
    assert(S.Sim(1, 2) > 0);
    assert(S.Sim(1, 3) < 0);
    assert(any(cellfun(@(g) all(ismember([1, 2], g)), S.Groups)));
    assert(~any(cellfun(@(g) all(ismember([1, 3], g)), S.Groups)));
    assert(size(S.AggregatedObj, 1) == N);
    assert(size(S.AggregatedObj, 2) == numel(S.Groups));
    for i = 1:numel(S.GroupWeights)
        assert(abs(sum(S.GroupWeights{i}) - 1) < 1e-10);
    end

    Population = struct();
    Population.objs = PopObj;
    H.d_score = nan(3, 3);
    H.model = nan(3, 3);
    H.improve = nan(3, 3);
    H.conf = nan(3, 3);
    H.best = nan(3, 1);

    [Sraw, Sgrp, EasyAggObj, d_score, groupDifficulty] = ...
        BuildStructureAwareEasySet(Population, H, 1, 0.6, 2, S, cfg);
    assert(~isempty(Sraw));
    assert(~isempty(Sgrp));
    assert(size(EasyAggObj, 1) == N);
    assert(numel(d_score) == 3);
    for g = 1:numel(S.Groups)
        C = S.Groups{g};
        expected = mean(d_score(C)) + 0.5 * std(d_score(C));
        assert(abs(groupDifficulty(g) - expected) < 1e-10);
    end

    PopObj2 = PopObj;
    PopObj2(1, 1) = NaN;
    PopObj2(:, 4) = 1;
    S2 = BuildObjectiveStructure_LKC(PopDec, PopObj2, cfg);
    assert(size(S2.Gamma, 1) == 4);
    assert(size(S2.AggregatedObj, 1) == N);

    fprintf('test_units_LKC passed.\n');
end

