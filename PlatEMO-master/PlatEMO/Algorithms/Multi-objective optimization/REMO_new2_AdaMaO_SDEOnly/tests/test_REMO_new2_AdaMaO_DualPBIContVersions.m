function tests = test_REMO_new2_AdaMaO_DualPBIContVersions
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    testFile     = mfilename('fullpath');
    testsDir     = fileparts(testFile);
    algorithmDir = fileparts(testsDir);
    platemoRoot  = fileparts(fileparts(fileparts(algorithmDir)));
    addpath(genpath(platemoRoot));
    rehash;
    testCase.TestData.AlgorithmDir = algorithmDir;
end

function testFiveEntriesAreDiscoverableAndMapped(testCase)
    names = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Unweighted'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Filter'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Weighted'};

    for i = 1:numel(names)
        expectedFile = fullfile(testCase.TestData.AlgorithmDir, ...
            [names{i},'.m']);
        verifyEqual(testCase,which(names{i}),expectedFile);
    end

    hardSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        [names{1},'.m']));
    adaptiveSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        [names{2},'.m']));
    unweightedSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        [names{3},'.m']));
    filterSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        [names{4},'.m']));
    weightedSource = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        [names{5},'.m']));

    verifyTrue(testCase,contains(hardSource, ...
        '< REMO_new2_AdaMaO_SDEOnly_ModeBase'));
    verifyTrue(testCase,contains(adaptiveSource, ...
        '< REMO_new2_AdaMaO_SDEOnly_DualPBIContModeBase'));
    verifyTrue(testCase,contains(adaptiveSource, ...
        "policy = 'uniform_mix';"));
    verifyTrue(testCase,contains(unweightedSource, ...
        "mode = 'conservative';"));
    verifyTrue(testCase,contains(filterSource, ...
        "mode = 'curriculum';"));
    verifyTrue(testCase,contains(weightedSource, ...
        "mode = 'weighted';"));
end

function testContinuousSupervisorMatchesApprovedDualPBI(testCase)
    N = 24;
    t = linspace(0.04,0.96,N)';
    PopDec = [t,1-t,t.^2];
    PopObj = [1+t,2-t,0.4+0.3*sin(pi*t).^2];
    Population = SOLUTION(PopDec,PopObj,zeros(N,1));
    theta = 5;
    ratio = 0.37;

    [catalog0,agreement0,ref0,score0] = ...
        DualPBIContinuousSupervision(Population,0,N,6,theta);
    [catalog1,agreement1,ref1,score1] = ...
        DualPBIContinuousSupervision(Population,1,N,6,theta);
    [catalogMix,agreementMix,refMix,scoreMix] = ...
        DualPBIContinuousSupervision(Population,ratio,N,6,theta);

    expectedV = expectedDirectionScore(PopObj,N,theta);
    expectedR = expectedReferenceScore(PopObj,refMix.objs,theta,expectedV);
    expectedMix = (1-ratio)*expectedV+ratio*expectedR;
    expectedAgreement = 1-abs(expectedV-expectedR);

    verifyEqual(testCase,ref0.decs,ref1.decs,'AbsTol',0);
    verifyEqual(testCase,ref0.decs,refMix.decs,'AbsTol',0);
    verifyEqual(testCase,score0,expectedV,'AbsTol',1e-12);
    verifyEqual(testCase,score1,expectedR,'AbsTol',1e-12);
    verifyEqual(testCase,scoreMix,expectedMix,'AbsTol',1e-12);
    verifyEqual(testCase,agreement0,expectedAgreement,'AbsTol',1e-12);
    verifyEqual(testCase,agreement1,expectedAgreement,'AbsTol',1e-12);
    verifyEqual(testCase,agreementMix,expectedAgreement,'AbsTol',1e-12);
    verifyEqual(testCase,catalog0,expectedCatalog(expectedV));
    verifyEqual(testCase,catalog1,expectedCatalog(expectedR));
    verifyEqual(testCase,catalogMix,expectedCatalog(expectedMix));
end

function testContinuousSupervisorUsesBaselineAdaptiveDirectionPath(testCase)
    source = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'DualPBIContinuousSupervision.m'));

    verifyTrue(testCase,contains(source,'if M <= 3 || N < 50'));
    verifyTrue(testCase,contains(source, ...
        'V = AdaptiveReferenceVectors(PopObj, Nref);'));
    verifyTrue(testCase,contains(source,'Ref = RefSelect(Population, k);'));
    verifyFalse(testCase,contains(source, ...
        'ComputeSDEFactorialContinuousScore('));
    verifyFalse(testCase,contains(source,'rankUtility('));
    verifyFalse(testCase,contains(source,'GetOutput_PBI('));
    verifyFalse(testCase,contains(source,'NormalizeObjectives('));
    verifyTrue(testCase,contains(source,'if isempty(validRef)'));
    verifyTrue(testCase,contains(source,'scoreRef = scoreV;'));
end

function testContinuousAdaptiveModeKeepsOriginalRelationController(testCase)
    source = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_SDEOnly_DualPBIContModeBase.m'));

    verifyTrue(testCase,contains(source, ...
        'Algorithm.ParameterSet(6,3000,0.80,0.35,0.30,4,6,0.35,1,0)'));
    verifyTrue(testCase,contains(source, ...
        'ratio = Problem.FE / Problem.maxFE;'));
    verifyTrue(testCase,contains(source, ...
        'previousError > errorThreshold'));
    verifyTrue(testCase,contains(source,'meanAgreement >= 0.55'));
    verifyTrue(testCase,contains(source,'coverage < 0.60'));
end

function testHardBaselineBlobsRemainFrozen(testCase)
    files = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix.m'; ...
        'REMO_new2_AdaMaO_SDEOnly_ModeBase.m'; ...
        fullfile('private','HybridPBI_Classification.m'); ...
        fullfile('private','GetOutput_PBI.m'); ...
        fullfile('private','RefSelect.m')};
    expected = { ...
        '523deb264424909d84334bdeacf81377352eca8a'; ...
        '411a828ae68111e4ede67709386832624d4c38a4'; ...
        '342658c826e2f1f96937f1d300896b14331d2e2d'; ...
        'de30b2e915908e6d205134168a0cf87894a97cb9'; ...
        '241e8940b34b1c1c8cdc092d1db3cecf9407bb86'};

    prefixCommand = sprintf('git -C "%s" rev-parse --show-prefix', ...
        testCase.TestData.AlgorithmDir);
    [prefixStatus,repoPrefix] = system(prefixCommand);
    verifyEqual(testCase,prefixStatus,0);
    repoPrefix = strtrim(repoPrefix);

    for i = 1:numel(files)
        file = fullfile(testCase.TestData.AlgorithmDir,files{i});
        repoPath = [repoPrefix,strrep(files{i},'\','/')];
        command = sprintf(['git -C "%s" hash-object --path="%s" ', ...
            '"%s"'],testCase.TestData.AlgorithmDir,repoPath,file);
        [status,blob] = system(command);
        verifyEqual(testCase,status,0);
        verifyEqual(testCase,strtrim(blob),expected{i}, ...
            sprintf('Frozen H-A file changed: %s',files{i}));
    end
end

function testFiveVersionsCompleteOnePostInitializationUpdate(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));

    names = { ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Unweighted'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Filter'; ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_DualPBICont_Weighted'};
    D = 3;
    initialFE = 11*D-1;
    parameters = {[],1,[],[],[],[],[],[],[],[]};

    for i = 1:numel(names)
        Algorithm = feval(names{i},'parameter',parameters,'save',0, ...
            'outputFcn',@silentOutput,'run',23);
        Problem = DTLZ2('N',20,'M',3,'D',D, ...
            'maxFE',initialFE+4);
        rng(9001,'twister');
        Algorithm.Solve(Problem);

        verifyGreaterThan(testCase,Problem.FE,initialFE);
        verifyNotEmpty(testCase,Algorithm.result);
        last = find(~cellfun(@isempty,Algorithm.result(:,2)),1,'last');
        verifyTrue(testCase,all(isfinite( ...
            Algorithm.result{last,2}.objs),'all'));
    end
end

function score = expectedDirectionScore(PopObj,Nref,theta)
    N = size(PopObj,1);
    M = size(PopObj,2);
    V = UniformPoint(Nref,M,'ILD');
    V = V./vecnorm(V,2,2);
    zmin = min(PopObj,[],1);
    [~,assigned] = max(1-pdist2(PopObj,V,'cosine'),[],2);
    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        w = V(assigned(i),:);
        d1(i) = (PopObj(i,:)-zmin)*w'/norm(w);
        projection = zmin+d1(i)*w;
        d2(i) = norm(PopObj(i,:)-projection);
    end
    score = 1./(1+d1+theta*d2);
end

function score = expectedReferenceScore(PopObj,RefObj,theta,fallback)
    zmin = min(PopObj,[],1);
    directions = RefObj-zmin;
    directionNorm = vecnorm(directions,2,2);
    valid = directionNorm > 0;
    if ~any(valid)
        score = fallback;
        return;
    end

    validRef = RefObj(valid,:);
    W = directions(valid,:)./directionNorm(valid);
    [~,assigned] = max(1-pdist2(PopObj,validRef,'cosine'),[],2);
    assignedW = W(assigned,:);
    shifted = PopObj-zmin;
    d1 = sum(shifted.*assignedW,2);
    projection = zmin+d1.*assignedW;
    d2 = vecnorm(PopObj-projection,2,2);
    score = 1./(1+d1+theta*d2);
end

function catalog = expectedCatalog(score)
    [~,order] = sort(score,'descend');
    catalog = false(numel(score),1);
    catalog(order(1:ceil(numel(score)/4))) = true;
end

function silentOutput(varargin)
end
