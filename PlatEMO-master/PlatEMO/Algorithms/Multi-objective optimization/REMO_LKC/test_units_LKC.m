function test_units_LKC()
% test_units_LKC - Lightweight checks for REMO_LKC structure utilities.
%
% Covers the LKC objective-structure builder (BuildObjectiveStructure_LKC)
% and the difficulty-free reliable-group selector (selectReliableGroups).

    here = fileparts(mfilename('fullpath'));
    addpath(here);
    rng(1);

    N = 80;
    x = linspace(0, 1, N)';
    PopDec = [x, rand(N, 2)];
    PopObj = [x, x + 0.005 * randn(N, 1), -x + 0.005 * randn(N, 1)];
    cfg = struct('nCells', 5, 'minGroupReliability', 0.5);

    % --- BuildObjectiveStructure_LKC ---
    S = BuildObjectiveStructure_LKC(PopDec, PopObj, cfg);
    assert(size(S.Gamma, 1) == 3);
    assert(size(S.Gamma, 2) == 5 * 3);
    assert(S.Sim(1, 2) > 0);   % objs 1,2 are positively correlated
    assert(S.Sim(1, 3) < 0);   % objs 1,3 are negatively correlated
    assert(any(cellfun(@(g) all(ismember([1, 2], g)), S.Groups)));
    assert(~any(cellfun(@(g) all(ismember([1, 3], g)), S.Groups)));
    assert(size(S.AggregatedObj, 1) == N);
    assert(size(S.AggregatedObj, 2) == numel(S.Groups));
    for i = 1:numel(S.GroupWeights)
        assert(abs(sum(S.GroupWeights{i}) - 1) < 1e-10);
    end

    % --- selectReliableGroups (pure reliability, no difficulty) ---
    minRel = cfg.minGroupReliability;
    [Sgrp, EasyAggObj] = selectReliableGroups(S, minRel);
    assert(~isempty(Sgrp), 'expected at least one reliable group');
    assert(size(EasyAggObj, 1) == N);
    assert(size(EasyAggObj, 2) == numel(Sgrp));
    % Every selected group must satisfy the reliability threshold
    assert(all(S.GroupReliability(Sgrp) >= minRel - 1e-12));
    % Selected indices must be valid group indices
    assert(all(Sgrp >= 1) && all(Sgrp <= numel(S.Groups)));

    % Fallback path: a threshold so high that no group qualifies still yields
    % the single most reliable group.
    [Sgrp2, EasyAggObj2] = selectReliableGroups(S, 2.0);
    assert(numel(Sgrp2) == 1);
    assert(size(EasyAggObj2, 2) == 1);

    % Empty-struct guard
    [Sgrp3, EasyAggObj3] = selectReliableGroups(struct(), minRel);
    assert(isempty(Sgrp3) && isempty(EasyAggObj3));

    % --- NaN / degenerate-column robustness ---
    PopObj2 = PopObj;
    PopObj2(1, 1) = NaN;
    PopObj2(:, 4) = 1;
    S2 = BuildObjectiveStructure_LKC(PopDec, PopObj2, cfg);
    assert(size(S2.Gamma, 1) == 4);
    assert(size(S2.AggregatedObj, 1) == N);

    fprintf('test_units_LKC passed.\n');
end
