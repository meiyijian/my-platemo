function tests = test_IndependentUtilityValidation()
%test_IndependentUtilityValidation Unit tests for Stage-3 modules (§ Task 1).
%   tests = test_IndependentUtilityValidation() runs focused unit tests for
%   LVIGDPlus, ComputeGreedyIGDPlusOracle, ComputeLeaveOneOutIGDPlus,
%   ReconstructFutureLabelOutcomes and ComputeExternalLabelMetrics.

    tests = functiontests(localfunctions);
end

%% ============ LVIGDPlus ============
function testLVIGDPlusDirection(t)
    % A solution that is component-wise worse must not lower IGD+
    % (plan § Task 1: "近似解变差时 IGD+ 不得下降")
    R = [0 0; 1 0; 0 1];
    A_good = [0 0; 1 0; 0 1];     % covers all refs exactly
    A_bad  = [0.5 0.5; 1 0; 0 1]; % first solution worse
    vGood = LVIGDPlus(A_good,R);
    vBad  = LVIGDPlus(A_bad,R);
    verifyEqual(t, vGood, 0, 'AbsTol', 1e-12);
    verifyGreaterThan(t, vBad, vGood);
    % exact value: ref(0,0) min over {(.5,.5):.707, (1,0):1, (0,1):1} = .707
    % ref(1,0) min = 0; ref(0,1) min = 0 -> mean = .707/3
    verifyEqual(t, vBad, sqrt(0.5)/3, 'AbsTol', 1e-12);
end

function testLVIGDPlusPerpendicular(t)
    % reference point exactly covered -> 0; worse solution -> larger
    R = [0.5 0.5];
    A = [0.5 0.5];
    verifyEqual(t, LVIGDPlus(A,R), 0, 'AbsTol', 1e-12);
    A2 = [0.8 0.8];
    verifyEqual(t, LVIGDPlus(A2,R), 0.3*sqrt(2), 'AbsTol', 1e-12);
    A3 = [1.0 1.0];
    verifyEqual(t, LVIGDPlus(A3,R), 0.5*sqrt(2), 'AbsTol', 1e-12);
    verifyGreaterThan(t, LVIGDPlus(A3,R), LVIGDPlus(A2,R));
end

%% ============ Greedy Oracle ============
function testGreedyOracleTieByEvalID(t)
    R = [0 0; 1 0; 0 1];
    P = [0 0; 1 0; 0 1; 0.5 0.5];
    EID = [10 20 30 40]';
    out = ComputeGreedyIGDPlusOracle(P,R,EID);
    % first pick covers a ref exactly; all three exact covers tie, pick 10
    verifyEqual(t, out.OracleGreedyTop25(1), 10);
    verifyEqual(t, out.FinalIGDPlus, 0, 'AbsTol', 1e-12);
    verifyEqual(t, numel(out.OracleGreedyTop25), 4);
end

function testGreedyOracleMarginalGain(t)
    % a dominated interior solution adds no new coverage and must be last
    R = [0 0; 1 0; 0 1];
    P = [0 0; 1 0; 0 1; 0.5 0.5];  % 4th is dominated by (0,0)
    EID = [1 2 3 4]';
    out = ComputeGreedyIGDPlusOracle(P,R,EID);
    verifyEqual(t, out.FinalIGDPlus, 0, 'AbsTol', 1e-9);
    % dominated solution selected last
    verifyEqual(t, out.OracleGreedyTop25(4), 4);
end

%% ============ Leave-one-out ============
function testLOORedundantDominance(t)
    R = [0 0; 1 0; 0 1];
    P = [0 0; 1 0; 0 1; 0.5 0.5];  % last one dominated
    EID = [1 2 3 4]';
    loo = ComputeLeaveOneOutIGDPlus(P,R,EID);
    verifyEqual(t, loo.UtilityLOO(4), 0, 'AbsTol', 1e-9);
    verifyGreaterThanOrEqual(t, min(loo.UtilityLOO), -1e-9);
end

%% ============ Future outcomes ============
function testFutureReconstructionCensor(t)
    % 5 snapshots, non-fallback training every generation
    snap = struct();
    for s = 1:5
        snap(s).SnapshotID = s;
        snap(s).FE = 100*s;
        snap(s).Ratio = 0.2*s;
        snap(s).PopulationEvalID = (1+(s-1)*4 : 4+(s-1)*4)';
        snap(s).PopulationObj = repmat([1 1],4,1) + (s-1)*0.01;
    end
    traj = struct('CandidateMode','explore','FEBefore',0,'FEAfter',0, ...
        'PopulationEvalIDAfter',[]);
    for s = 1:5
        traj(s).CandidateMode = 'explore';
        traj(s).FEBefore = snap(s).FE;
        traj(s).FEAfter  = snap(s).FE + 6;
        traj(s).PopulationEvalIDAfter = snap(s).PopulationEvalID;
    end
    ev = struct('EvalID',(1:500)','Objective',rand(500,2),'Decision',[],'Generation',[]);
    out = ReconstructFutureLabelOutcomes(snap,traj,ev,1);
    verifyEqual(t, out.H1snapIdx, 2);
    verifyEqual(t, out.H3snapIdx, 4);
    % snapshot1 population is 1:4; H1 population (snapshot 2) is 5:8
    verifyFalse(t, out.censoredH1);
    verifyEqual(t, numel(out.InPopulationH1), 4);
    verifyFalse(t, out.InPopulationH1(1));   % EvalID 1 not in H1 population
    verifyFalse(t, any(out.InFinalPopulation)); % final pop is 17:20, disjoint
    % last snapshot (index 5) -> H1 censored
    out5 = ReconstructFutureLabelOutcomes(snap,traj,ev,5);
    verifyTrue(t, out5.censoredH1);
    verifyTrue(t, all(isnan(out5.InPopulationH1)));
end

%% ============ External label metrics ============
function testExternalMetricsShape(t)
    N = 100;
    cat = struct(); sc = struct();
    for v = {'L0','L1','L2','L3','L4','L5','L7','L8'}
        cat.(v{1}) = false(N,1);
        sc.(v{1})  = rand(N,1);
    end
    cat.L1(1:25) = true;
    cat.L2(1:30) = true;
    cat.L6 = false(N,100);
    for r = 1:100, cat.L6(1:25,r) = true; end
    sc.L6 = rand(N,100);

    loo = struct('UtilityLOO',rand(N,1),'EvalID',(1:N)');
    future = struct('InPopulationH1',true(N,1),'InPopulationH3',true(N,1), ...
        'InFinalPopulation',true(N,1));
    rows = ComputeExternalLabelMetrics(cat,sc,loo,(1:25)',future,0.25);
    verifyEqual(t, nnz(strcmp({rows.VariantName},'L1')), 1);
    verifyEqual(t, nnz(strcmp({rows.VariantName},'L6')), 100);
    l1 = rows(strcmp({rows.VariantName},'L1'));
    verifyEqual(t, l1.PrecisionAt25, 1, 'AbsTol', 1e-9);
    verifyEqual(t, l1.JaccardAt25, 1, 'AbsTol', 1e-9);
    l0 = rows(strcmp({rows.VariantName},'L0'));
    verifyFalse(t, isnan(l0.NativePositiveCount));
end

%% ============ Disagreement utility ============
function testDisagreementUtilitySampleGuard(t)
    N = 100;
    cat = struct();
    for v = {'L1','L2','L3'}
        cat.(v{1}) = false(N,1);
    end
    cat.L1(1:25) = true;
    cat.L2(1:25) = true;
    cat.L3(26:50) = true;
    loo = struct('UtilityLOO',rand(N,1),'EvalID',(1:N)');
    future = struct('InPopulationH1',true(N,1),'InPopulationH3',true(N,1), ...
        'InFinalPopulation',true(N,1));
    rows = ComputeDisagreementUtility(cat,loo,(1:25)',future);
    r = rows(strcmp({rows.VariantA},'L2') & strcmp({rows.VariantB},'L1'));
    verifyEqual(t, r.AOnlyCount, 0);
    verifyEqual(t, r.BOnlyCount, 0);
    r2 = rows(strcmp({rows.VariantA},'L3') & strcmp({rows.VariantB},'L1'));
    verifyEqual(t, r2.AOnlyCount, 25);
    verifyEqual(t, r2.BOnlyCount, 25);
    verifyFalse(t, isnan(r2.DisagreementUtilityDelta));
end
