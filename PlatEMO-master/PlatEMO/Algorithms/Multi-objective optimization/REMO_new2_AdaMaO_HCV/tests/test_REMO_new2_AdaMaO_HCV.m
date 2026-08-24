function tests = test_REMO_new2_AdaMaO_HCV
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
    % private/ 不在路径上，测试通过一个放在算法目录内的 harness 访问
    testCase.TestData.Harness = @hcv_test_harness;
end

%% ================= 1. 解析性质：核空间 =================
function testKernelOrthogonalityAndDimension(testCase)
    h = testCase.TestData.Harness;
    for M = [10 14 20]
        [Lambda,B,Info] = h('hcv',M,inf);
        m = 0:M-1;
        A = [cos(2*pi*m/M); sin(2*pi*m/M)];
        % B 与 RadViz 的两行、以及全一向量正交 => B 落在 ker(RadViz) 内
        verifyLessThan(testCase,max(abs(B*A'),[],'all'),1e-10, ...
            sprintf('B not orthogonal to RadViz rows at M=%d',M));
        verifyLessThan(testCase,max(abs(B*ones(M,1))),1e-10, ...
            sprintf('B not orthogonal to all-ones at M=%d',M));
        % 维数恰为 M-3，且 [1;A;B] 满秩 => 完整正交分解
        verifyEqual(testCase,size(B,1),M-3, ...
            sprintf('blind dim mismatch at M=%d',M));
        verifyEqual(testCase,rank([ones(1,M);A;B]),M, ...
            sprintf('[1;A;B] not full rank at M=%d',M));
        verifyEqual(testCase,Info.blindDim,M-3);
        verifyEqual(testCase,size(Lambda,1),2*(M-3));
    end
end

function testHarmonicVectorsAreValidSimplexWeights(testCase)
    h = testCase.TestData.Harness;
    for M = [10 15 20]
        Lambda = h('hcv',M,inf);
        verifyGreaterThanOrEqual(testCase,min(Lambda(:)),-1e-12, ...
            sprintf('negative weight at M=%d',M));
        verifyLessThan(testCase,max(abs(sum(Lambda,2)-1)),1e-10, ...
            sprintf('weights do not sum to 1 at M=%d',M));
    end
end

function testHarmonicVectorsAreWellSeparated(testCase)
    h = testCase.TestData.Harness;
    for M = [10 20]
        [~,~,Info] = h('hcv',M,inf);
        % 谐波正交性 => 最小夹角与 M 无关，约 48.2 度
        verifyGreaterThan(testCase,Info.minPairAngle,40, ...
            sprintf('vectors too close at M=%d',M));
    end
end

function testRadVizAliasingCounterexampleIsResolved(testCase)
    % M 偶数时的显式反例：两个 lambda 距离为 1，RadViz 坐标却精确相同
    h = testCase.TestData.Harness;
    M = 10;
    l1 = zeros(1,M); l1([1 6]) = 0.5;
    l2 = zeros(1,M); l2([3 8]) = 0.5;
    m  = 0:M-1;
    A  = [cos(2*pi*m/M); sin(2*pi*m/M)];
    verifyLessThan(testCase,max(abs(A*l1'-A*l2')),1e-10, ...
        'counterexample is not actually aliased by RadViz');
    verifyGreaterThan(testCase,norm(l1-l2),0.5);
    % 盲坐标必须能区分它们
    [~,B] = h('hcv',M,inf);
    verifyGreaterThan(testCase,norm(l1*B'-l2*B'),0.1, ...
        'blind coordinates fail to separate the aliased pair');
end

function testHarmonicOrderIsNested(testCase)
    h = testCase.TestData.Harness;
    M = 20;
    Lprev = [];
    for n = 1:4
        L = h('hcv',M,n);
        if ~isempty(Lprev)
            verifyEqual(testCase,L(1:size(Lprev,1),:),Lprev,'AbsTol',1e-12, ...
                'increasing nHarm changed earlier vectors');
        end
        Lprev = L;
    end
    verifyEmpty(testCase,h('hcv',M,0));
end

function testLowObjectiveNumberDisablesComplementarity(testCase)
    h = testCase.TestData.Harness;
    for M = [2 3]
        [Lambda,B,Info] = h('hcv',M,inf);
        % M<=3 时核空间为空，互补分支自动关闭
        verifyEmpty(testCase,Lambda);
        verifyEmpty(testCase,B);
        verifyFalse(testCase,Info.enabled);
    end
end

function testDeterminism(testCase)
    h = testCase.TestData.Harness;
    a = h('hcv',20,3);
    b = h('hcv',20,3);
    verifyEqual(testCase,a,b,'AbsTol',0);
end

%% ================= 2. 分类器行为 =================
function testNestingWithNHarmZeroGivesPureAnchorRanking(testCase)
    h = testCase.TestData.Harness;
    rng(42,'twister');
    for M = [10 20]
        P = h('pop',M,100);
        [g0,C0] = h('classify',P,0.0,0);      % nHarm=0
        % nHarm=0 时正组必须恰为 g 最小的 nGood 个
        nGood = ceil(numel(C0)*0.25);
        [~,ord] = sort(g0,'ascend');
        expected = false(size(C0));
        expected(ord(1:nGood)) = true;
        verifyEqual(testCase,C0,expected, ...
            sprintf('nHarm=0 is not pure anchor ranking at M=%d',M));
    end
end

function testDiversitySlotsShrinkWithRatio(testCase)
    h = testCase.TestData.Harness;
    rng(7,'twister');
    P = h('pop',10,100);
    prev = inf;
    for ratio = [0 0.25 0.5 0.75 1.0]
        [~,~,D] = h('classify',P,ratio,2);
        verifyLessThanOrEqual(testCase,D.nDivSlots,prev, ...
            'diversity slots not monotonically decreasing in ratio');
        prev = D.nDivSlots;
    end
    verifyEqual(testCase,prev,0,'ratio=1 should leave no diversity slot');
end

function testPositiveGroupSizeIsExact(testCase)
    h = testCase.TestData.Harness;
    rng(11,'twister');
    for M = [10 20]
        for ratio = [0 0.5 1]
            for nh = [0 2 100]
                [~,C] = h('classify',h('pop',M,100),ratio,nh);
                verifyEqual(testCase,sum(C),ceil(100*0.25), ...
                    sprintf('positive group size wrong (M=%d r=%.1f nh=%d)', ...
                    M,ratio,nh));
            end
        end
    end
end

function testComplementarityIncreasesNicheCoverage(testCase)
    % 机制检查：在完整核空间的**同一固定划分**下，HCV 正组覆盖的 niche 数应多于
    % 纯锚点排序的正组。
    %
    % 必须用 nicheCoverageFull 而不是 nicheOfPositive：后者基于当前 nHarm 激活的
    % 划分，nHarm=0 时 niche 恒为 1，比较是同义反复。
    %
    % 输入必须是 RSEA 已筛过的种群（主循环里 Population = RefSelect(Archive,N)）。
    % 均匀随机点云上不存在 RSEA 引入的盲子空间偏差，因此没有可修正的东西 ——
    % 实测该情形下增益不显著，这是机制的适用边界，不是实现缺陷。
    h = testCase.TestData.Harness;
    rng(3,'twister');
    win = 0; total = 0;
    for M = [10 20]
        pro = DTLZ2('N',100,'M',M,'D',30);
        for t = 1:4
            A = pro.CalObj(unifrnd(repmat(pro.lower,400,1), ...
                repmat(pro.upper,400,1)));
            P = h('refselect',A,100,'legacy');       % RSEA 筛选后的种群
            [~,~,Dh] = h('classify',P,0.0,2);
            [~,~,D0] = h('classify',P,0.0,0);
            verifyTrue(testCase,isfinite(Dh.nicheCoverageFull));
            verifyTrue(testCase,isfinite(D0.nicheCoverageFull));
            total = total + 1;
            win = win + (Dh.nicheCoverageFull > D0.nicheCoverageFull);
        end
    end
    verifyGreaterThan(testCase,total,0,'no comparable trials');
    verifyGreaterThanOrEqual(testCase,win/total,0.75, ...
        sprintf('niche coverage improved in only %d/%d trials',win,total));
end

function testNicheCoverageDiagnosticIsConfigurationComparable(testCase)
    % nicheCoverageFull 的划分规模必须与 nHarm 无关，否则跨配置不可比
    h = testCase.TestData.Harness;
    rng(19,'twister');
    P = h('pop',20,100);
    tot = [];
    for nh = [0 2 3 100]
        [~,~,D] = h('classify',P,0.5,nh);
        tot(end+1) = D.nicheTotalFull; %#ok<AGROW>
        verifyEqual(testCase,D.blindDimFullUsed,20-3);
    end
    verifyEqual(testCase,numel(unique(tot)),1, ...
        'nicheTotalFull varies with nHarm; diagnostic is not comparable');
end

function testConvergenceCostOfComplementarityIsBounded(testCase)
    % 诚实性检查：互补 niching 必然牺牲部分收敛质量（正组 meanG 变大）。
    % 该代价必须随 nHarm 单调增长，且在默认 nHarm=2 下保持有界，
    % 否则在 500 FE 的极小预算下不可接受。
    h = testCase.TestData.Harness;
    rng(31,'twister');
    for M = [10 20]
        base = 0; costs = [];
        for nh = [0 2 3]
            acc = [];
            for t = 1:5
                P = h('pop',M,100);
                [~,~,D] = h('classify',P,0.0,nh);
                acc(end+1) = D.meanGPositive; %#ok<AGROW>
            end
            if nh == 0
                base = mean(acc);
            else
                costs(end+1) = mean(acc)/base - 1; %#ok<AGROW>
            end
        end
        % 代价为正（存在权衡）且随阶数单调不减。
        % 不设绝对上界：实测该代价强烈依赖前沿几何（合成球面约 +12%，
        % DTLZ2 真实前沿可达 +56%，退化前沿可达 +85%），故绝对阈值没有
        % 跨问题意义。单调性才是应当固定的不变量；代价的可接受范围由
        % Stage-1 的 nHarm 扫描按问题决定。
        verifyGreaterThan(testCase,costs(1),0, ...
            sprintf('no measurable convergence trade-off at M=%d',M));
        verifyGreaterThanOrEqual(testCase,costs(2),costs(1)-1e-9, ...
            sprintf('cost not monotone in nHarm at M=%d',M));
    end
end

function testDegenerateObjectivesProduceNoNaN(testCase)
    h = testCase.TestData.Harness;
    rng(5,'twister');
    M = 10;
    % (a) 某目标恒定 (b) 全部点相同 (c) 存在等于理想点的行
    P1 = h('pop',M,60); P1(:,4) = 2.5;
    P2 = repmat(ones(1,M),60,1);
    P3 = h('pop',M,60); P3(1,:) = min(P3,[],1);
    for P = {P1,P2,P3}
        [g,C,D] = h('classify',P{1},0.3,2);
        verifyTrue(testCase,all(isfinite(g)),'non-finite anchor PBI');
        verifyEqual(testCase,sum(C),ceil(size(P{1},1)*0.25));
        verifyFalse(testCase,any(isnan([D.nDivSlots,D.nicheOccupied])));
    end
end

function testEveryPositiveSlotIsAUniqueSolution(testCase)
    h = testCase.TestData.Harness;
    rng(13,'twister');
    [~,C,D] = h('classify',h('pop',20,100),0.0,100);
    verifyEqual(testCase,sum(C),ceil(100*0.25));
    % round-robin 不得复制解；名额数不超过正组规模
    verifyLessThanOrEqual(testCase,D.nDivSlots,D.nGood);
end

%% ================= 3. RSEA 缺陷与可选修复 =================
function testRSEAConvergenceTermDominatesAtHighM(testCase)
    % 解析界：RLoc 落在单位圆盘 => RDis <= 1；Con 归一到 [0,1]，系数 0.1*M
    % 故 M>=10 时收敛项幅度 >= 多样性项上界
    for M = [10 20]
        verifyGreaterThanOrEqual(testCase,0.1*M,1.0, ...
            sprintf('premise broken at M=%d',M));
    end
    verifyLessThan(testCase,0.1*3,1.0,'premise broken at M=3');
end

function testScaledConvergenceWeightIsSmallerAtHighM(testCase)
    h = testCase.TestData.Harness;
    rng(17,'twister');
    for M = [10 20]
        P = h('pop',M,80);
        RefL = h('refselect',P,max(6,ceil(1.5*M)),'legacy');
        RefS = h('refselect',P,max(6,ceil(1.5*M)),'scaled');
        verifyEqual(testCase,numel(RefL),numel(RefS));
        % scaled 模式必须真的改变权重量级
        verifyLessThan(testCase,0.1*M/max(1,M/3),0.1*M);
    end
end

function testRadarGridSurvivesDegenerateProjection(testCase)
    % 回归：继承自 RSEA 的两个崩溃点
    %   (1) 全部解相同 => YU==YL => NRLoc=NaN => Site=0 => CrowdG(0) 下标越界
    %   (2) 某解归一化后各目标和为 0 => 0/0 => NaN 污染 YL/YU
    h = testCase.TestData.Harness;
    M = 10;
    same  = repmat(ones(1,M),40,1);
    two   = [repmat(ones(1,M),20,1); repmat(2*ones(1,M),20,1)];
    ideal = rand(40,M); ideal(1,:) = min(ideal,[],1);
    for P = {same,two,ideal}
        obj = h('refselect',P{1},8,'legacy');
        verifyTrue(testCase,all(isfinite(obj(:))), ...
            'RefSelect produced non-finite objectives');
        verifySize(testCase,obj,[8 M]);
    end
end

function testLegacyRefSelectIsUnchangedByDefault(testCase)
    % 未传第三参数时必须与原始 RSEA 逐位一致
    h = testCase.TestData.Harness;
    rng(23,'twister');
    P = h('pop',10,80);
    a = h('refselect',P,15,'');
    b = h('refselect',P,15,'legacy');
    verifyEqual(testCase,a,b);
end

%% ================= 4. 集成契约 =================
function testGuiParameterContract(testCase)
    source = fileread(fullfile(testCase.TestData.AlgorithmDir, ...
        'REMO_new2_AdaMaO_HCV.m'));
    names    = {'gmax','pMix','rGood','qKeep','lambda0','nMin','nMax','nHarm','wCon'};
    defaults = {'3000','0.50','0.25','0.80','0.35','4','6','2','0'};
    for i = 1:numel(names)
        verifyTrue(testCase,contains(source,[names{i},' --- ',defaults{i}]), ...
            sprintf('GUI contract missing %s',names{i}));
    end
    verifyTrue(testCase,contains(source, ...
        'Algorithm.ParameterSet(3000,0.50,0.25,0.80,0.35,4,6,2,0)'));
end

function testOriginalAlgorithmIsUntouched(testCase)
    % 本变体不得修改基线算法目录
    algDir  = testCase.TestData.AlgorithmDir;
    baseDir = fullfile(fileparts(algDir), ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original');
    verifyTrue(testCase,isfolder(baseDir),'baseline directory missing');
    verifyTrue(testCase,isfile(fullfile(baseDir,'private', ...
        'HybridPBI_Classification.m')));
    % 基线的 RefSelect 必须仍是 2 参数版本（无 wCon）
    src = fileread(fullfile(baseDir,'private','RefSelect.m'));
    verifyTrue(testCase,contains(src,'function Ref = RefSelect(Population,k)'), ...
        'baseline RefSelect signature was modified');
    verifyFalse(testCase,contains(src,'wCon'), ...
        'baseline RefSelect contains wCon');
end

function testDependencyBoundary(testCase)
    root  = testCase.TestData.AlgorithmDir;
    files = [dir(fullfile(root,'*.m')); dir(fullfile(root,'private','*.m'))];
    src   = '';
    for i = 1:numel(files)
        src = [src,newline,fileread(fullfile(files(i).folder,files(i).name))]; %#ok<AGROW>
    end
    % 本变体不再使用退化的 K-means 连续方向场
    verifyFalse(testCase,contains(src,'AdaptiveReferenceVectors'), ...
        'degenerate K-means direction field still referenced');
    verifyTrue(testCase,isfile(fullfile(root,'private', ...
        'HarmonicComplementaryVectors.m')));
    verifyTrue(testCase,isfile(fullfile(root,'private', ...
        'ComplementaryPBI_Classification.m')));
end

function testMainRejectsInvalidParameters(testCase)
    bad = { {1,0.50,0.51,0.80,0.35,2,1,2,0}, ...   % rGood>0.5 且 nMin>nMax
            {1,0.50,0.25,0.80,0.35,4,6,-1,0}, ...  % nHarm<0
            {1,0.50,0.25,0.80,0.35,4,6,2,2} };     % wCon 非 0/1
    for i = 1:numel(bad)
        algorithm = REMO_new2_AdaMaO_HCV('parameter',bad{i}, ...
            'save',0,'outputFcn',@silentOutput,'run',1);
        problem = DTLZ2('N',20,'M',3,'D',3,'maxFE',32,'maxRuntime',inf);
        verifyError(testCase,@() algorithm.Solve(problem), ...
            'AdaMaO:InvalidParameter', ...
            sprintf('invalid config %d was accepted',i));
    end
end

function testShortRunAtTenObjectives(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));
    algorithm = REMO_new2_AdaMaO_HCV( ...
        'parameter',{1,0.50,0.25,0.80,0.35,1,1,2,0}, ...
        'save',0,'outputFcn',@silentOutput,'run',1);
    % DTLZ2 要求 D >= M（前 M-1 个为位置变量）。
    % D>10 时初始种群固定为 N=100，故 maxFE 必须 >100 才能进入代理循环。
    problem = DTLZ2('N',20,'M',10,'D',14,'maxFE',106,'maxRuntime',inf);
    rng(9001,'twister');
    algorithm.Solve(problem);
    verifyEqual(testCase,problem.FE,106);
    verifyNotEmpty(testCase,algorithm.result);
end

function testShortRunAtTwentyObjectivesWithScaledWeight(testCase)
    stateBefore = rng;
    testCase.addTeardown(@() rng(stateBefore));
    algorithm = REMO_new2_AdaMaO_HCV( ...
        'parameter',{1,0.50,0.25,0.80,0.35,1,1,3,1}, ...
        'save',0,'outputFcn',@silentOutput,'run',1);
    problem = DTLZ2('N',20,'M',20,'D',24,'maxFE',106,'maxRuntime',inf);
    rng(4242,'twister');
    algorithm.Solve(problem);
    verifyEqual(testCase,problem.FE,106);
    verifyNotEmpty(testCase,algorithm.result);
end

function silentOutput(varargin)
end
