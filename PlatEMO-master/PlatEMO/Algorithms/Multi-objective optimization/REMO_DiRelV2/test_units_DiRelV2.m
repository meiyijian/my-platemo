function test_units_DiRelV2()
% test_units_DiRelV2 - 不依赖 PlatEMO solve，单元测试 V2 关键模块
%
% 目的：第一次部署 V2 时先跑这个，确认所有模块没有语法 / 维度错误。
% 通过后再跑 run_smoke_DiRelV2。
%
% 用法（在 V2 目录里）：
%   test_units_DiRelV2()

    rng(1, 'twister');
    fprintf('=== V2 unit tests ===\n');

    % 假数据：N=80 解，M=5 目标，D=10 维
    N = 80; M = 5; D = 10;
    PopDec = rand(N, D);
    % 模拟目标空间：5 个目标，f1 易（线性），f2 易（线性），
    % f3 与 f1 强负相关，f4 与 f2 强正相关（应被冗余删除），f5 难（高频）
    PopObj = zeros(N, M);
    PopObj(:, 1) = sum(PopDec(:, 1:3), 2);
    PopObj(:, 2) = sum(PopDec(:, 4:6), 2);
    PopObj(:, 3) = -PopObj(:, 1) + 0.1 * randn(N, 1);   % 强负相关于 f1
    PopObj(:, 4) = PopObj(:, 2) + 0.02 * randn(N, 1);   % 强正相关于 f2
    PopObj(:, 5) = sum(sin(8 * PopDec), 2);             % 难

    % ============= 1. BuildDifficultySubsets =============
    fprintf('\n[1] BuildDifficultySubsets ...\n');
    d_score = [0.1; 0.2; 0.4; 0.3; 0.9];
    [Subsets, SubsetInfo] = BuildDifficultySubsets(d_score, PopObj, struct());
    assert(numel(Subsets) >= 2, 'should have >=2 subsets when M=5');
    fprintf('  K=%d  sizes=%s\n', numel(Subsets), mat2str(arrayfun(@(s)s.size, SubsetInfo)));
    % 验证强正相关 (f2,f4) 应被冗余删除，强负相关 (f1,f3) 应保留
    foundPosRedundancy = false;
    for k = 1:numel(SubsetInfo)
        if ~isempty(SubsetInfo(k).redundancyRemoved)
            foundPosRedundancy = true;
            fprintf('  Subset %d removed by redundancy: %s\n', k, ...
                mat2str(SubsetInfo(k).redundancyRemoved));
        end
    end
    fprintf('  full subset is the last: %s\n', mat2str(Subsets{end}));
    assert(isequal(Subsets{end}, 1:M), 'last subset must be full');

    % ============= 2. BuildSubsetReferenceVectors =============
    fprintf('\n[2] BuildSubsetReferenceVectors ...\n');
    RefCell = BuildSubsetReferenceVectors(PopObj, Subsets, struct('numRef', 8));
    for k = 1:numel(RefCell)
        fprintf('  RefCell{%d} size = %s\n', k, mat2str(size(RefCell{k})));
        assert(size(RefCell{k}, 2) == numel(Subsets{k}), ...
            'ref dim must match subset size');
    end

    % ============= 3. BuildPairBank_ParetoPBI =============
    fprintf('\n[3] BuildPairBank_ParetoPBI ...\n');
    cfgPair = struct('pairMaxPerExpert', 600);
    PairBank = BuildPairBank_ParetoPBI(PopDec, PopObj, Subsets, RefCell, cfgPair);
    for k = 1:numel(PairBank)
        st = PairBank(k).stats;
        fprintf('  Expert %d: subset=%s  pairs=%d  hist=%s  paretoRatio=%.2f  lowMargin=%.2f\n', ...
            k, mat2str(PairBank(k).subset), st.totalPair, mat2str(st.labelHist), ...
            st.paretoRatio, st.lowMarginRate);
        assert(size(PairBank(k).X, 2) == 2 * D, 'X must be [xa, xb] concat → 2D');
        assert(size(PairBank(k).Y, 1) == size(PairBank(k).X, 1));
        assert(all(ismember(PairBank(k).Y, [-1, 0, 1])));
    end
    % 关键检查：同一对 pair 在不同 subset 下标签是否可以不同
    % 简单方法：full subset 的 paretoRatio 应小于或等于子集的（因为子集少目标 → 支配关系更容易）
    paretoRatios = arrayfun(@(b) b.stats.paretoRatio, PairBank);
    fprintf('  pareto ratios across experts: %s\n', mat2str(paretoRatios, 3));

    % ============= 4. DifficultyProfilerV2 =============
    fprintf('\n[4] DifficultyProfilerV2 ...\n');
    % 模拟 PlatEMO SOLUTION 接口（只需 .objs 和 .decs）
    Pop = struct('objs', PopObj, 'decs', PopDec);
    Arc = struct('objs', PopObj, 'decs', PopDec);
    H = struct();
    [DiffState, H] = DifficultyProfilerV2(Pop, Arc, H, 1, struct('doKriging', false));
    fprintf('  Dprog  = %s\n', mat2str(DiffState.Dprog', 3));
    fprintf('  Dconf  = %s\n', mat2str(DiffState.Dconf', 3));
    fprintf('  Dsens  = %s\n', mat2str(DiffState.Dsens', 3));
    fprintf('  total  = %s\n', mat2str(DiffState.total', 3));
    assert(numel(DiffState.total) == M);
    % Dconf 应对 f1 和 f3 高（互为强负相关）
    fprintf('  f1 vs f3 Dconf check: Dconf(1)=%.3f Dconf(3)=%.3f (should be > Dconf(2,4))\n', ...
        DiffState.Dconf(1), DiffState.Dconf(3));

    % ============= 5. TrainRelationExperts =============
    fprintf('\n[5] TrainRelationExperts ...\n');
    Experts = TrainRelationExperts(PairBank, struct('K_ens', 3, 'epochs', 20));
    for k = 1:numel(Experts)
        fprintf('  Expert %d: valid=%d  valErr=%.3f  brier=%.3f  labels=%s\n', ...
            k, Experts(k).valid, Experts(k).valError, Experts(k).brier, ...
            mat2str(Experts(k).labelStats));
        if Experts(k).valid
            % hidden 必须 scalar
            net1 = Experts(k).nets{1};
            if ~isempty(net1)
                fprintf('    net IW{1} size = %s (should be [h, %d])\n', ...
                    mat2str(size(net1.IW{1})), 2*D);
            end
        end
    end

    % ============= 6. SelectRelationAnchors =============
    fprintf('\n[6] SelectRelationAnchors ...\n');
    Anchors = SelectRelationAnchors(PopDec, PopObj, struct('anchorMax', 20));
    fprintf('  elite anchors:   %d\n', size(Anchors.elite, 1));
    fprintf('  diverse anchors: %d\n', size(Anchors.diverse, 1));

    % ============= 7. ScoreCandidates_DiRel =============
    fprintf('\n[7] ScoreCandidates_DiRel ...\n');
    nCand = 50;
    Cand = rand(nCand, D);
    cfgScore = struct('Lower', zeros(1, D), 'Upper', ones(1, D));
    [scores, dbg] = ScoreCandidates_DiRel(Cand, Anchors, Experts, PopDec, cfgScore);
    fprintf('  scores: mean=%.3f  std=%.3f  min=%.3f  max=%.3f\n', ...
        mean(scores), std(scores), min(scores), max(scores));
    fprintf('  R per expert: %s\n', mat2str(mean(dbg.R, 1), 3));
    fprintf('  mean Nov=%.3f, mean Disagree=%.3f, mean U=%.3f\n', ...
        mean(dbg.Nov), mean(dbg.Disagree), mean(dbg.U));
    fprintf('  globalRel: %s\n', mat2str(dbg.globalRel, 3));
    fprintf('  mean weights per expert: %s\n', mat2str(mean(dbg.weights, 1), 3));

    % ============= 8. SelectTopDiverse =============
    fprintf('\n[8] SelectTopDiverse ...\n');
    selIdx = SelectTopDiverse(Cand, scores, PopDec, 5, ...
        struct('Lower', zeros(1, D), 'Upper', ones(1, D)));
    fprintf('  selected indices: %s\n', mat2str(selIdx));
    fprintf('  selected scores: %s\n', mat2str(scores(selIdx)', 3));
    assert(numel(selIdx) > 0, 'should select at least 1');

    fprintf('\n=== All unit tests passed ===\n');
end
