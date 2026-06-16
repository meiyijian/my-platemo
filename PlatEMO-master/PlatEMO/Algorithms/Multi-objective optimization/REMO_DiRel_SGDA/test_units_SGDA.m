function test_units_SGDA()
% test_units_SGDA - Minimal unit tests for SGDA helper logic.

    fprintf('Running SGDA unit tests...\n');
    testPositiveGrouping();
    testNegativeNotMerged();
    testGroupTieBreakOnly();
    testFullCannotBeOverridden();
    fprintf('All SGDA unit tests passed.\n');
end

function testPositiveGrouping()
    rng(1);
    t = linspace(0, 1, 80)';
    PopDec = [t, rand(80, 2)];
    PopObj = [t + 0.01*randn(80, 1), ...
              2*t + 0.01*randn(80, 1), ...
              rand(80, 1)];
    d = [0.2; 0.25; 0.7];
    [Groups, Info] = BuildObjectiveGroups_SGDA(PopDec, PopObj, d, ...
        struct('simThreshold', 0.60, 'maxPairs', 300));
    has12 = any(cellfun(@(g) all(ismember([1 2], g)), Groups));
    assert(has12, 'Strong positively related objectives were not grouped.');
    assert(Info.similarity(1, 2) > 0, 'Positive pair should have positive similarity.');
    fprintf('[OK] positive correlation grouping\n');
end

function testNegativeNotMerged()
    rng(2);
    t = linspace(0, 1, 80)';
    PopDec = [t, rand(80, 2)];
    PopObj = [t + 0.01*randn(80, 1), ...
              1 - t + 0.01*randn(80, 1), ...
              rand(80, 1)];
    d = [0.2; 0.25; 0.7];
    [Groups, Info] = BuildObjectiveGroups_SGDA(PopDec, PopObj, d, ...
        struct('simThreshold', 0.60, 'maxPairs', 300));
    has12 = any(cellfun(@(g) all(ismember([1 2], g)), Groups));
    assert(~has12, 'Strong negative objectives must not be merged.');
    assert(Info.similarity(1, 2) < 0, 'Negative pair should keep negative similarity.');
    fprintf('[OK] negative correlation is not merged\n');
end

function testGroupTieBreakOnly()
    Cand = rand(3, 2);
    Anchors = struct('elite', zeros(1, 2), 'diverse', [], 'eliteObj', [], 'diverseObj', []);
    ArchiveDec = rand(5, 2);
    Experts = [mockExpert(+0.75, 0.90, 0.05, 'group'), ...
               mockExpert(+0.02, 0.20, 0.30, 'full')];
    cfg = struct('fullMargin', 0.20, 'fullConfThr', 0.60, ...
        'groupMargin', 0.20, 'groupConfThr', 0.60, ...
        'gamma', 0, 'beta', 0, 'lambda', 0, 'tieWeight', 0.5);
    [scores, dbg] = ScoreCandidates_SGDA(Cand, Anchors, Experts, ArchiveDec, cfg);
    assert(all(dbg.tieTriggered), 'Full uncertainty should trigger tie-break.');
    assert(all(dbg.mode == 2), 'High-confidence group evidence should be tie-break mode.');
    assert(all(scores > 0), 'Group auxiliary preference should improve score when full is uncertain.');
    fprintf('[OK] group acts as tie-break under full uncertainty\n');
end

function testFullCannotBeOverridden()
    Cand = rand(3, 2);
    Anchors = struct('elite', zeros(1, 2), 'diverse', [], 'eliteObj', [], 'diverseObj', []);
    ArchiveDec = rand(5, 2);
    Experts = [mockExpert(+0.90, 0.95, 0.05, 'group'), ...
               mockExpert(-0.80, 0.95, 0.02, 'full')];
    cfg = struct('fullMargin', 0.20, 'fullConfThr', 0.60, ...
        'groupMargin', 0.20, 'groupConfThr', 0.60, ...
        'gamma', 0, 'beta', 0, 'lambda', 0, 'tieWeight', 1.0);
    [scores, dbg] = ScoreCandidates_SGDA(Cand, Anchors, Experts, ArchiveDec, cfg);
    assert(all(dbg.fullCertain), 'Full expert should be certain.');
    assert(all(dbg.mode == 1), 'Confident full expert should dominate arbitration.');
    assert(all(abs(scores - dbg.fullOnlyScore) < 1e-12), 'Group score must not override full.');
    assert(all(scores < 0), 'Confident negative full relation should remain negative.');
    fprintf('[OK] full expert cannot be overridden by group expert\n');
end

function e = mockExpert(R, C, U, type)
    e = struct('subset', [], 'valid', true, 'nets', {{}}, ...
        'mp_struct', [], 'valError', 0.05, 'brier', 0, ...
        'labelStats', [1 1 1], 'modelType', 'mock', ...
        'expertType', type, 'groupIndex', 1, ...
        'groupDifficulty', 0.2, 'groupReliability', 0.9, ...
        'isEasyGroup', strcmp(type, 'group'), ...
        'mockR', R, 'mockConf', C, 'mockU', U);
    if strcmp(type, 'full')
        e.groupReliability = 1;
        e.isEasyGroup = false;
        e.groupIndex = 0;
    end
end
