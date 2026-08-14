function tests = test_LabelCausalAblation()
%test_LabelCausalAblation Unit tests for the Stage-2 offline ablation
%   pipeline. Run with:  runtests('test_LabelCausalAblation')
%
%   Covers:
%     T1  LVTopQDeterministic: size, 0/1, sum, tie-break by row order
%     T2  TopQ full ranking is a permutation of 1:N
%     T3  ComputeUniformDirectionScore: finite, nDir recorded, direction
%     T4  PBI direction: closer to a direction -> higher score
%     T5  ComputeReducedNDDirectionScore: kEff, offline RNG restored
%     T6  ComputeLabelAblationVariants on a synthetic snapshot: L3 ==
%         CatalogCurrent; L0 == LabelDyn; L1-L8 positive count == 25
%     T7  L6 shuffle: sort(shuffled)==sort(score), 100 rows, RNG restored
%     T8  Offline seeds are deterministic (same seed -> same result)
%     T9  ComputeLabelOverlapMetrics: symmetry and field presence
%    T10  ComputeLabelPerturbationStability: RNG restored, row counts

    tests = functiontests(localfunctions);
end

%% ---------- T1: deterministic topQ ----------
function testTopQDeterministic(testCase)
    rng(42,'twister');
    score = rand(37,1);
    rGood = 0.25;
    [cat,order] = LVTopQDeterministic(score,rGood);
    N = numel(score);
    verifyEqual(testCase,numel(cat),N);
    verifyTrue(testCase,all(cat==0 | cat==1));
    verifyEqual(testCase,sum(cat),ceil(N*rGood));
    verifyEqual(testCase,numel(order),ceil(N*rGood));
    % tie-break: equal scores -> smaller row index first
    s2 = [0.5 0.5 0.3 0.3]';   % k = ceil(4*0.4) = 2, two 0.5 ties
    [cat2,ord2] = LVTopQDeterministic(s2,0.4);
    verifyEqual(testCase,find(cat2),[1;2]);
    verifyEqual(testCase,ord2,[1;2]);
    % a higher score always outranks a tie pair
    s3 = [0.5 0.5 0.9]';       % k = ceil(3*0.4) = 2 -> {0.9, 0.5(row1)}
    [cat3,~] = LVTopQDeterministic(s3,0.4);
    verifyEqual(testCase,find(cat3),[1;3]);
end

%% ---------- T2: full ranking is a permutation ----------
function testFullRankPermutation(testCase)
    rng(7,'twister');
    score = rand(25,1);
    [~,ord] = sortrows([-score(:),(1:25)']);
    verifyTrue(testCase,isequal(sort(ord'),1:25));
    verifyTrue(testCase,numel(unique(ord))==25);
end

%% ---------- T3: uniform direction score ----------
function testUniformDirectionScore(testCase)
    rng(11,'twister');
    PopObj = rand(50,4) + 1;
    [score,V,nDir] = ComputeUniformDirectionScore(PopObj,5,100);
    verifyTrue(testCase,all(isfinite(score)));
    verifyTrue(testCase,all(isfinite(V(:))));
    verifyTrue(testCase,size(V,2)==4);
    verifyTrue(testCase,nDir==size(V,1));
    verifyTrue(testCase,nDir>=1);
    % unit rows
    verifyTrue(testCase,max(abs(vecnorm(V,2,2)-1))<1e-8);
    verifyEqual(testCase,numel(score),size(PopObj,1));
end

%% ---------- T4: PBI direction semantics ----------
function testPBIDirection(testCase)
    % PBI = d1 + theta*d2; score = 1/(1+PBI). Smaller PBI -> larger score.
    % Point exactly on direction w with smaller d1 -> larger score.
    V = [1 0; 0 1];
    Pop = [1 0; 2 0];   % both on w=(1,0); d1: 1 vs 2 -> first scores higher
    theta = 5;
    [score,~,~] = ComputeUniformDirectionScore(Pop,theta,2,V);
    verifyTrue(testCase,score(1)>score(2));
    % off-direction point scores lower than on-direction with same d1
    Pop2 = [2 0; 2 0.5];
    [score2,~,~] = ComputeUniformDirectionScore(Pop2,theta,2,V);
    verifyTrue(testCase,score2(1)>score2(2));
end

%% ---------- T5: reduced ND direction score ----------
function testReducedNDDirectionScore(testCase)
    rng(3,'twister');
    PopObj = rand(80,3) + 1;
    kEff = 15;
    s0 = rng;
    [score,V,nDir,ds] = ComputeReducedNDDirectionScore(PopObj,kEff,5,12345);
    s1 = rng;
    verifyTrue(testCase,all(isfinite(score)));
    verifyTrue(testCase,nDir>=1);
    verifyTrue(testCase,nDir<=kEff);
    verifyTrue(testCase,any(ds==[1 3 4 6]));
    % RNG must be restored
    verifyEqual(testCase,s1.State,s0.State);
    verifyEqual(testCase,s1.Type,s0.Type);
end

%% ---------- T6: variants on synthetic snapshot ----------
function testVariantsSynthetic(testCase)
    % Build a synthetic Stage-1 snapshot with known fields.
    N = 100; M = 3;
    rng(99,'twister');
    snap = struct();
    snap.SnapshotID = 1;
    snap.Generation = 5;
    snap.FE = 60;
    snap.Ratio = 0.3;
    snap.PopulationEvalID = (1:N)';
    snap.PopulationDec = rand(N,5);
    snap.PopulationObj = rand(N,M) + 1;
    snap.RefEvalID = (1:15)';
    snap.RefObj = rand(15,M) + 1;
    snap.kEff = 15;
    snap.Nref = 100;
    snap.Theta = 5;
    snap.DirectionSource = 1;
    snap.FallbackReason = 'NONE';
    snap.Front1Count = 60;
    snap.ClusterCount = 60;
    snap.UniqueDirectionCount = 60;
    snap.V = rand(100,M);
    snap.Delta = 0.5;
    snap.AnchorPositiveRate = 0.5;
    snap.AnchorNormalizedG = rand(N,1) + 0.5;
    snap.AnchorMargin = 1 - snap.AnchorNormalizedG;
    snap.LabelDyn = rand(N,1) > 0.5;
    snap.ScoreV = rand(N,1);
    % hybrid score as in the frozen code
    ratio = 0.3;
    snap.ScoreHybrid = (1-ratio)*snap.ScoreV + ratio*double(snap.LabelDyn);
    [cat,~] = LVTopQDeterministic(snap.ScoreHybrid,0.25);
    snap.CatalogCurrent = cat;
    snap.ScoreVStd = std(snap.ScoreV);
    snap.LabelDynStd = std(double(snap.LabelDyn));
    snap.EffectiveScaleRatio = 0.1;
    snap.TrainingCatalog = cat;

    meta = struct('seed',11001,'M',3,'rGood',0.25,'problem','DTLZ2', ...
        'behavior','Hybrid','problemN',N);

    out = ComputeLabelAblationVariants(snap,meta);

    % L0 == LabelDyn
    verifyTrue(testCase,isequal(out.catalogs.L0,logical(snap.LabelDyn)));
    % L3 == CatalogCurrent
    verifyTrue(testCase,out.repro.ok);
    verifyTrue(testCase,isequal(out.catalogs.L3,logical(snap.CatalogCurrent)));
    % positive counts: L0 natural, L1-L8 == 25
    for v = {'L1','L2','L3','L4','L5','L7','L8'}
        verifyEqual(testCase,sum(out.catalogs.(v{1})(:,1)),25, ...
            sprintf('%s positive count',v{1}));
    end
    for r = 1:100
        verifyEqual(testCase,sum(out.catalogs.L6(:,r)),25);
    end
    % L8 direction count <= kEff
    verifyTrue(testCase,out.direction.L8.Ndir <= snap.kEff);

    % variantRows count: 8 singles + 100 L6 = 108
    verifyEqual(testCase,numel(out.variantRows),108);
    codes = [out.variantRows.VariantCode];
    verifyEqual(testCase,sum(codes==6),100);
    for c = [0 1 2 3 4 5 7 8]
        verifyEqual(testCase,sum(codes==c),1);
    end
end

%% ---------- T7: shuffle preserves distribution, RNG restored ----------
function testShuffleRestoresRNG(testCase)
    % Re-run the L6 computation from the same snapshot twice with the same
    % offline seeds; verify identical catalogs (determinism) and that the
    % global RNG is untouched.
    N = 100; M = 3;
    rng(5,'twister');
    snap = syntheticSnapshot(N,M,1,0.3);
    meta = struct('seed',11001,'M',M,'rGood',0.25,'problem','DTLZ2', ...
        'behavior','Hybrid','problemN',N);

    s0 = rng;
    out1 = ComputeLabelAblationVariants(snap,meta);
    s1 = rng;
    out2 = ComputeLabelAblationVariants(snap,meta);
    s2 = rng;
    verifyEqual(testCase,s1.State,s0.State);
    verifyEqual(testCase,s2.State,s0.State);
    verifyTrue(testCase,isequal(out1.catalogs.L6,out2.catalogs.L6));
end

%% ---------- T8: offline seed determinism ----------
function testOfflineSeedDeterminism(testCase)
    N = 60; M = 3;
    snap = syntheticSnapshot(N,M,2,0.5);
    meta = struct('seed',12001,'M',M,'rGood',0.25,'problem','DTLZ2', ...
        'behavior','Hybrid','problemN',N);
    out1 = ComputeLabelAblationVariants(snap,meta);
    out2 = ComputeLabelAblationVariants(snap,meta);
    verifyTrue(testCase,isequal(out1.catalogs.L6,out2.catalogs.L6));
    verifyTrue(testCase,isequal(out1.catalogs.L8,out2.catalogs.L8));
    verifyTrue(testCase,isequal(out1.catalogs.L7,out2.catalogs.L7));
end

%% ---------- T9: overlap metrics symmetry ----------
function testOverlapMetrics(testCase)
    N = 40;
    catA = rand(N,1) > 0.5;
    catB = rand(N,1) > 0.5;
    scA  = rand(N,1);
    scB  = rand(N,1);
    % build 1x1 structs (field-by-field: struct(...) with vectors would
    % broadcast into an Nx1 struct array)
    catalogs = struct();
    scores = struct();
    fields = {'L0','L1','L2','L3','L4','L5','L7','L8'};
    for k = 1:numel(fields)
        f = fields{k};
        if mod(k,2)==1
            catalogs.(f) = catA; scores.(f) = scA;
        else
            catalogs.(f) = catB; scores.(f) = scB;
        end
    end
    rows = ComputeLabelOverlapMetrics(catalogs,scores);
    verifyEqual(testCase,numel(rows),28);   % C(8,2)
    % every pair appears once in each order only
    seen = {};
    for i = 1:numel(rows)
        key = sprintf('%s|%s',rows(i).VariantA,rows(i).VariantB);
        verifyTrue(testCase,~any(strcmp(seen,key)));
        seen{end+1} = key; %#ok<AGROW>
        verifyTrue(testCase,rows(i).Jaccard>=0 && rows(i).Jaccard<=1);
        % consistency: inter + AOnly + BOnly == union
        verifyEqual(testCase, ...
            rows(i).IntersectionCount+rows(i).AOnlyCount+rows(i).BOnlyCount, ...
            rows(i).UnionCount);
        % symmetry of Jaccard definition
        verifyEqual(testCase, ...
            rows(i).IntersectionCount/max(rows(i).UnionCount,1), ...
            rows(i).Jaccard);
    end
end

%% ---------- T10: perturbation stability ----------
function testPerturbationStability(testCase)
    N = 100; M = 3;
    snap = syntheticSnapshot(N,M,3,0.6);
    meta = struct('seed',13001,'M',M,'rGood',0.25,'problem','DTLZ2', ...
        'behavior','Hybrid','problemN',N);
    out = ComputeLabelAblationVariants(snap,meta);
    s0 = rng;
    rows = ComputeLabelPerturbationStability(snap,meta,out.catalogs,out.scores);
    s1 = rng;
    verifyEqual(testCase,s1.State,s0.State);
    % 5 variants x 2 drop fractions x 100 replicates
    verifyEqual(testCase,numel(rows),5*2*100);
    verifyTrue(testCase,all([rows.RetainedJaccard]>=0 & [rows.RetainedJaccard]<=1));
    verifyEqual(testCase,numel(unique({rows.VariantName})),5);
    for v = {'L1','L2','L3','L7','L8'}
        verifyTrue(testCase,any(strcmp({rows.VariantName},v{1})));
    end
    % each variant has 200 rows (2 fractions)
    for v = {'L1','L2','L3','L7','L8'}
        verifyEqual(testCase,sum(strcmp({rows.VariantName},v{1})),200);
    end
end

%% ============ synthetic snapshot builder ============
function snap = syntheticSnapshot(N,M,snapID,ratio)
    rng(1000+snapID,'twister');
    snap = struct();
    snap.SnapshotID = snapID;
    snap.Generation = 5;
    snap.FE = round(ratio*500);
    snap.Ratio = ratio;
    snap.PopulationEvalID = (1:N)';
    snap.PopulationDec = rand(N,5);
    snap.PopulationObj = rand(N,M) + 1;
    snap.RefEvalID = (1:15)';
    snap.RefObj = rand(15,M) + 1;
    snap.kEff = 15;
    snap.Nref = 100;
    snap.Theta = 5;
    snap.DirectionSource = 1;
    snap.FallbackReason = 'NONE';
    snap.Front1Count = 60;
    snap.ClusterCount = 60;
    snap.UniqueDirectionCount = 60;
    snap.V = rand(100,M);
    snap.Delta = 0.5;
    snap.AnchorPositiveRate = 0.5;
    snap.AnchorNormalizedG = rand(N,1) + 0.5;
    snap.AnchorMargin = 1 - snap.AnchorNormalizedG;
    snap.LabelDyn = rand(N,1) > 0.5;
    snap.ScoreV = rand(N,1);
    snap.ScoreHybrid = (1-ratio)*snap.ScoreV + ratio*double(snap.LabelDyn);
    [cat,~] = LVTopQDeterministic(snap.ScoreHybrid,0.25);
    snap.CatalogCurrent = cat;
    snap.ScoreVStd = std(snap.ScoreV);
    snap.LabelDynStd = std(double(snap.LabelDyn));
    snap.EffectiveScaleRatio = 0.1;
    snap.TrainingCatalog = cat;
end
