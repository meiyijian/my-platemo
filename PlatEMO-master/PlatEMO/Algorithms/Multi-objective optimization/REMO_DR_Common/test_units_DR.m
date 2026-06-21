function test_units_DR()
% test_units_DR - Unit checks for REMO objective-reduction helpers.

    here = fileparts(mfilename('fullpath'));
    addpath(here);
    rng(1);

    N = 60;
    M = 10;
    D = 4;
    PopDec = rand(N, D);
    PopObj = rand(N, M);

    Srand = DR_BuildRandomReduction(PopObj, 3);
    assert(strcmp(Srand.Method, 'RandFixed'));
    assert(numel(Srand.Groups) == 3);
    assertCoversAllObjectives(Srand.Groups, M);
    groupSizes = cellfun(@numel, Srand.Groups);
    assert(max(groupSizes) - min(groupSizes) <= 1);
    assert(size(Srand.AggregatedObj, 1) == N);
    assert(size(Srand.AggregatedObj, 2) == 3);
    assert(all(isfinite(Srand.AggregatedObj(:))));

    PopObj2 = PopObj;
    PopObj2(1, 1) = NaN;
    PopObj2(:, 4) = 1;
    [ReducedObj, Sapplied] = DR_ApplyReduction(PopObj2, Srand);
    assert(size(ReducedObj, 1) == N);
    assert(size(ReducedObj, 2) == 3);
    assert(all(isfinite(ReducedObj(:))));
    assertCoversAllObjectives(Sapplied.Groups, M);

    x = linspace(0, 1, N)';
    PopDecL = [x, rand(N, 2)];
    PopObjL = [ ...
        x, ...
        x + 0.002 * randn(N, 1), ...
        -x + 0.002 * randn(N, 1), ...
        rand(N, 1), ...
        rand(N, 1)];
    Slkc = DR_BuildLKCReduction(PopDecL, PopObjL, 3, struct('nCells', 5));
    assert(strcmp(Slkc.Method, 'LKC'));
    assert(numel(Slkc.Groups) == 3);
    assertCoversAllObjectives(Slkc.Groups, 5);
    assert(size(Slkc.AggregatedObj, 2) == 3);
    assert(all(isfinite(Slkc.AggregatedObj(:))));
    assert(Slkc.Sim(1, 2) > 0);
    assert(Slkc.Sim(1, 3) < 0);
    assert(any(cellfun(@(g) all(ismember([1, 2], g)), Slkc.Groups)));
    assert(~any(cellfun(@(g) all(ismember([1, 3], g)), Slkc.Groups)));

    Small = DR_BuildRandomReduction(rand(N, 2), 3);
    assert(numel(Small.Groups) == 2);
    assert(size(Small.AggregatedObj, 2) == 2);

    [XXs, Ls, Catalog] = DR_GetRelationPairsBudgeted(PopDec, PopObj(:, 1:3), 200, [], 0.05);
    assert(size(XXs, 2) == 2 * D);
    assert(numel(Ls) == size(XXs, 1));
    assert(all(ismember(unique(Ls), [-1; 0; 1])));
    assert(numel(Catalog) == N);

    fprintf('test_units_DR passed.\n');
end


function assertCoversAllObjectives(Groups, M)
    allIdx = [];
    for i = 1:numel(Groups)
        assert(~isempty(Groups{i}));
        allIdx = [allIdx, Groups{i}(:)']; %#ok<AGROW>
    end
    assert(isequal(sort(allIdx), 1:M));
    assert(numel(unique(allIdx)) == M);
end
