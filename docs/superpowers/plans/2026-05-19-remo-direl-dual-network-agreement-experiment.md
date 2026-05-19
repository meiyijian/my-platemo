# REMO_DiRel 双网络一致性实验 — 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 REMO_DiRel 加装一份独立的、带探针的算法副本，在 4 个 expensive MOP 问题 × 10 次 run × 5 个进度点采集三层一致性数据并输出 3 张可视化图。

**Architecture:** 在 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/` 下做一份算法副本 `REMO_DiRel_probed.m`，把 [ArbitratorScore.m](../../PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/ArbitratorScore.m) 和 [TrainDualScaleNet.m](../../PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/TrainDualScaleNet.m) 里需要复用的私有局部函数提取成包内公共函数。探针在 5 个进度比触发点处调用一次 `compute_agreement`，将结果写 `.mat`。最后跑独立的 3 个绘图脚本读 `.mat` 出图。

**Tech Stack:** MATLAB R2020b+，PlatEMO 框架，Neural Network Toolbox（patternnet）。

---

## 文件结构

将创建：
- `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/REMO_DiRel_probed.m` — 加探针的算法副本
- `.../REMO_DiRel_AgreementProbe/scoreAllByEnsemble_probe.m` — 从 ArbitratorScore 抽出的辅助函数
- `.../REMO_DiRel_AgreementProbe/ensemblePredict_probe.m` — 从 TrainDualScaleNet 抽出的辅助函数
- `.../REMO_DiRel_AgreementProbe/compute_agreement.m` — 三层一致性计算与持久化
- `.../REMO_DiRel_AgreementProbe/run_probe_experiment.m` — 实验入口脚本
- `.../REMO_DiRel_AgreementProbe/plot_line_over_gens.m` — 图 1
- `.../REMO_DiRel_AgreementProbe/plot_boxplot.m` — 图 2
- `.../REMO_DiRel_AgreementProbe/plot_objective_scatter.m` — 图 3
- `.../REMO_DiRel_AgreementProbe/results/` — 输出目录（运行时由脚本创建）
- `.../REMO_DiRel_AgreementProbe/figures/` — 图片输出目录

将不会修改任何 PlatEMO 原始文件或 REMO_DiRel 原算法文件。

---

## Task 1: 创建实验目录与算法副本骨架

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/REMO_DiRel_probed.m`

- [ ] **Step 1: 创建目录**

```bash
mkdir -p "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/results"
mkdir -p "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/figures"
```

- [ ] **Step 2: 复制 REMO_DiRel.m 为副本**

```bash
cp "PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_DiRel/REMO_DiRel.m" \
   "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/REMO_DiRel_probed.m"
```

- [ ] **Step 3: 把副本类名改为 REMO_DiRel_probed**

打开 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/REMO_DiRel_probed.m`，将第 1 行：

```matlab
classdef REMO_DiRel < ALGORITHM
```

改为：

```matlab
classdef REMO_DiRel_probed < ALGORITHM
```

并在头部注释里增加一段：

```matlab
% PROBE: This is an instrumented copy of REMO_DiRel used by the
% AgreementProbe experiment. The original algorithm is unmodified.
% The probe records three-level network agreement at 5 progress checkpoints.
```

- [ ] **Step 4: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/"
git commit -m "实验脚手架：建立 REMO_DiRel_AgreementProbe 目录与副本"
```

---

## Task 2: 抽取 ensemblePredict 为公共函数

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/ensemblePredict_probe.m`

理由：原函数是 [TrainDualScaleNet.m](../../PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/TrainDualScaleNet.m) 文件内的局部函数（253-294 行），外部无法调用，必须复制一份到实验包供 L3 用。

- [ ] **Step 1: 创建函数文件**

新建 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/ensemblePredict_probe.m`，内容：

```matlab
function pred = ensemblePredict_probe(nets, X)
% ensemblePredict_probe - Local copy of TrainDualScaleNet's private
% ensemblePredict, used by the AgreementProbe experiment.
%
% Inputs:
%   nets - 1xK cell of patternnet, may contain empty cells
%   X    - n x D normalized input (rows are samples)
%
% Output:
%   pred - n x 1 label vector in {+1, 0, -1}
%
% Algorithm: each valid net predicts onehot, label is argmax mapped back;
% final label is the mode across K nets.

    N = size(X, 1);

    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    if isempty(nets_v)
        pred = zeros(N, 1);
        return;
    end

    K = numel(nets_v);
    votes = zeros(N, K);

    for i = 1:K
        try
            out_oh = nets_v{i}(X')';
            [~, maxind] = max(out_oh, [], 2);
            v = zeros(N, 1);
            v(maxind == 1) =  1;
            v(maxind == 3) = -1;
            votes(:, i) = v;
        catch
            votes(:, i) = 0;
        end
    end

    pred = mode(votes, 2);
end
```

- [ ] **Step 2: MATLAB 语法校验**

启动 MATLAB（或用 octave 替代）执行：

```matlab
addpath("PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe");
which ensemblePredict_probe   % 期望打印出文件路径
```

预期：路径打印出来。

如果手头没有 MATLAB，跳过此步，留待 Task 8 整体跑通时一起验证。

- [ ] **Step 3: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/ensemblePredict_probe.m"
git commit -m "抽取 ensemblePredict 为 probe 包内的公共函数"
```

---

## Task 3: 抽取 scoreAllByEnsemble 为公共函数

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/scoreAllByEnsemble_probe.m`

理由：原函数是 [ArbitratorScore.m](../../PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/ArbitratorScore.m) 文件内的局部函数（134-185 行），外部无法调用。L2 一致性需要直接调用它获取 `mu_F`、`mu_S`。

实现复制了原函数代码，并把其依赖的两个局部 helper（`selectAnchors`、`scoreOneNet`、`minmaxNorm`）一并放在本文件中。

- [ ] **Step 1: 创建函数文件**

新建 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/scoreAllByEnsemble_probe.m`，内容：

```matlab
function [mu, sigma2] = scoreAllByEnsemble_probe(X_train, Y_train, nets, mp_struct, Candidates, anchorMax)
% scoreAllByEnsemble_probe - Local copy of ArbitratorScore's private
% scoreAllByEnsemble, used by the AgreementProbe experiment.
%
% Inputs/Outputs are identical to the original.

    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    K = numel(nets_v);
    nCand = size(Candidates, 1);

    if K == 0
        mu = zeros(nCand, 1);
        sigma2 = ones(nCand, 1);
        return;
    end

    C1 = selectAnchors(X_train(Y_train == 1, :), anchorMax);
    C2 = selectAnchors(X_train(Y_train ~= 1, :), anchorMax);

    sample_scores = zeros(nCand, K);
    for kk = 1:K
        sample_scores(:, kk) = scoreOneNet(C1, C2, nets_v{kk}, mp_struct, Candidates);
    end

    mu = mean(sample_scores, 2);
    if K >= 2
        sigma2 = var(sample_scores, 0, 2);
    else
        sigma2 = ones(nCand, 1);
    end
end


function X = selectAnchors(X, anchorMax)
    n = size(X, 1);
    if n <= anchorMax
        return;
    end
    idx = unique(round(linspace(1, n, anchorMax)), 'stable');
    X = X(idx, :);
end


function scoreVec = scoreOneNet(C1, C2, net, mp_struct, Candidates)
    n1 = size(C1, 1);
    n2 = size(C2, 1);
    nCand = size(Candidates, 1);

    if nCand == 0 || (n1 + n2) == 0
        scoreVec = zeros(nCand, 1);
        return;
    end

    D = size(Candidates, 2);

    rowCount = 2 * (n1 + n2) * nCand;
    all_pairs = zeros(rowCount, 2 * D);

    for i = 1:nCand
        base = (i-1) * 2 * (n1 + n2);
        if n1 > 0
            Xi = repmat(Candidates(i, :), n1, 1);
            all_pairs(base+1 : base+n1, :)      = [C1, Xi];
            all_pairs(base+1+n1 : base+2*n1, :) = [Xi, C1];
        end
        if n2 > 0
            Xi = repmat(Candidates(i, :), n2, 1);
            p0 = base + 2*n1;
            all_pairs(p0+1 : p0+n2, :)      = [C2, Xi];
            all_pairs(p0+1+n2 : p0+2*n2, :) = [Xi, C2];
        end
    end

    try
        TestIn_nor = mapminmax('apply', all_pairs', mp_struct)';
        pre_out = net(TestIn_nor')';
    catch
        scoreVec = zeros(nCand, 1);
        return;
    end

    scoreVec = zeros(nCand, 1);
    for i = 1:nCand
        base = (i-1) * 2 * (n1 + n2);
        Cscore = [0, 0];
        if n1 > 0
            pre_C1Xi = sum(pre_out(base+1 : base+n1, :), 1) ./ n1;
            Cscore(1) = Cscore(1) + pre_C1Xi(2) + pre_C1Xi(3);
            Cscore(2) = Cscore(2) + pre_C1Xi(1);
            pre_XiC1 = sum(pre_out(base+1+n1 : base+2*n1, :), 1) ./ n1;
            Cscore(1) = Cscore(1) + pre_XiC1(2) + pre_XiC1(1);
            Cscore(2) = Cscore(2) + pre_XiC1(3);
        end
        if n2 > 0
            p0 = base + 2*n1;
            pre_C2Xi = sum(pre_out(p0+1 : p0+n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_C2Xi(3);
            Cscore(2) = Cscore(2) + pre_C2Xi(2) + pre_C2Xi(1);
            pre_XiC2 = sum(pre_out(p0+1+n2 : p0+2*n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_XiC2(1);
            Cscore(2) = Cscore(2) + pre_XiC2(2) + pre_XiC2(3);
        end
        scoreVec(i) = Cscore(1) - Cscore(2);
    end
end
```

- [ ] **Step 2: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/scoreAllByEnsemble_probe.m"
git commit -m "抽取 scoreAllByEnsemble 为 probe 包内的公共函数"
```

---

## Task 4: 实现 compute_agreement.m（三层指标计算）

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/compute_agreement.m`

- [ ] **Step 1: 创建函数文件**

新建 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/compute_agreement.m`，内容：

```matlab
function rec = compute_agreement(Population, Catalog_F, Catalog_S, DualNet, S_easy, anchorMax, gen, FE)
% compute_agreement - Compute L1/L2/L3 agreement between full-objective and
% sub-objective networks for one snapshot.
%
% Inputs:
%   Population - PlatEMO population at this generation (N solutions)
%   Catalog_F  - N x 1 PBI label vector from full-objective (+1 / non+1)
%   Catalog_S  - N x 1 PBI label vector from sub-objective  (+1 / non+1)
%   DualNet    - struct from TrainDualScaleNet
%   S_easy     - easy-objective subset index (row vector)
%   anchorMax  - max anchor count for scoreAllByEnsemble_probe
%   gen        - current generation number
%   FE         - current Problem.FE
%
% Output:
%   rec - struct containing all metrics for this snapshot. Caller saves it.

    Input  = Population.decs;
    PopObj = Population.objs;
    N      = size(Input, 1);
    nPairsCap = 2000;

    rec = struct();
    rec.gen    = gen;
    rec.FE     = FE;
    rec.N      = N;
    rec.PopObj = PopObj;
    rec.S_easy = S_easy;

    % ----------------------------------------------------------------
    % L1: PBI label agreement
    % ----------------------------------------------------------------
    cf = Catalog_F(:);
    cs = Catalog_S(:);
    rec.label_F = cf;
    rec.label_S = cs;
    rec.agree_L1 = mean(cf == cs);
    % Binary confusion matrix on "is +1?"
    rec.confmat_L1 = confusionmat_binary(cf == 1, cs == 1);

    % ----------------------------------------------------------------
    % L2: ArbitratorScore mu sign agreement (population as candidates)
    % ----------------------------------------------------------------
    [mu_F, ~] = scoreAllByEnsemble_probe(Input, cf, DualNet.nets_F, DualNet.mp_struct_F, Input, anchorMax);

    % Sub-network input is decisions in full D (decision space) — the
    % network was trained on [x_i, x_j] of full D-dim decision vectors;
    % only the *label space* used sub-objectives. So candidates fed to
    % nets_S are the same Input matrix (full D), normalized by mp_struct_S.
    [mu_S, ~] = scoreAllByEnsemble_probe(Input, cs, DualNet.nets_S, DualNet.mp_struct_S, Input, anchorMax);

    rec.mu_F = mu_F;
    rec.mu_S = mu_S;
    sf = sign(mu_F);
    ss = sign(mu_S);
    rec.agree_L2 = mean(sf == ss);
    rec.confmat_L2 = confusionmat_binary(sf >= 0, ss >= 0);

    % ----------------------------------------------------------------
    % L3: relation-pair prediction agreement on a shared pair set
    % ----------------------------------------------------------------
    if N >= 2
        allPairs = nchoosek(1:N, 2);
        if size(allPairs, 1) > nPairsCap
            sel = randperm(size(allPairs, 1), nPairsCap);
            allPairs = allPairs(sel, :);
        end
        XX_shared = [Input(allPairs(:,1), :), Input(allPairs(:,2), :)];

        XF_nor = mapminmax('apply', XX_shared', DualNet.mp_struct_F)';
        XS_nor = mapminmax('apply', XX_shared', DualNet.mp_struct_S)';
        yhat_F = ensemblePredict_probe(DualNet.nets_F, XF_nor);
        yhat_S = ensemblePredict_probe(DualNet.nets_S, XS_nor);

        rec.yhat_F = yhat_F;
        rec.yhat_S = yhat_S;
        rec.agree_L3 = mean(yhat_F == yhat_S);
        rec.confmat_L3 = confusionmat3(yhat_F, yhat_S);
    else
        rec.yhat_F = [];
        rec.yhat_S = [];
        rec.agree_L3 = NaN;
        rec.confmat_L3 = zeros(3, 3);
    end
end


function C = confusionmat_binary(a, b)
% Rows = a (true), cols = b (predicted). Both logical.
    a = logical(a); b = logical(b);
    C = zeros(2, 2);
    C(1, 1) = sum(~a & ~b);
    C(1, 2) = sum(~a &  b);
    C(2, 1) = sum( a & ~b);
    C(2, 2) = sum( a &  b);
end


function C = confusionmat3(a, b)
% 3x3 confusion for labels in {+1, 0, -1}, row = a, col = b.
    classes = [1, 0, -1];
    C = zeros(3, 3);
    for i = 1:3
        for j = 1:3
            C(i, j) = sum(a == classes(i) & b == classes(j));
        end
    end
end
```

- [ ] **Step 2: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/compute_agreement.m"
git commit -m "实现三层一致性计算函数 compute_agreement"
```

---

## Task 5: 在 REMO_DiRel_probed.m 中嵌入探针

**Files:**
- Modify: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/REMO_DiRel_probed.m`

- [ ] **Step 1: 修改 main 函数签名**

PlatEMO 算法类的 `main(Algorithm, Problem)` 没办法直接传入实验上下文，所以走"超参数尾部塞 probe_out_path 字符串"的路子。把第 29-30 行的 ParameterSet 调用扩展：

把：

```matlab
            [k_easy_user, tau_conf, alpha, k, gmax, K_ens, win_K] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 1000, 3, 3);
```

改为：

```matlab
            [k_easy_user, tau_conf, alpha, k, gmax, K_ens, win_K, probe_out_path] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 1000, 3, 3, '');
```

注意：`probe_out_path` 必须是字符串。`run_probe_experiment` 会传具体路径。如果为空则不写文件（运行时是普通算法）。

- [ ] **Step 2: 在主循环外初始化探针状态**

在 [REMO_DiRel.m](../../PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/REMO_DiRel.m) 第 88 行 `gen = 0;` 之后，添加：

```matlab
            % ====== PROBE state ======
            probe_checkpoints = [0.04, 0.20, 0.40, 0.60, 0.80];
            probe_fired = false(1, numel(probe_checkpoints));
            probe_records = {};   % cell array of snapshot structs
            % =========================
```

- [ ] **Step 3: 在 Smodel 构建后插入探针调用**

定位副本中相当于原 [REMO_DiRel.m](../../PlatEMO-master/PlatEMO/Algorithms/Multi-objective%20optimization/REMO_DiRel/REMO_DiRel.m) 第 173 行（`Smodel.easyDifficulty = mean(d_score(S_easy));`）之后、第 178 行 `ArbitratedSelection` 调用之前，插入：

```matlab
                    % ====== PROBE: snapshot at progress checkpoints ======
                    if ~isempty(probe_out_path)
                        progress = Problem.FE / Problem.maxFE;
                        hit = find(progress >= probe_checkpoints & ~probe_fired);
                        if ~isempty(hit)
                            probe_fired(hit) = true;
                            try
                                rec = compute_agreement(Population, Catalog_F, Catalog_S, ...
                                                        DualNet, S_easy, anchorMax, gen, Problem.FE);
                                rec.checkpoint_idx = hit(end);
                                rec.checkpoint_val = probe_checkpoints(hit(end));
                                probe_records{end+1} = rec;
                            catch ME
                                warning('Probe failed at gen %d: %s', gen, ME.message);
                            end
                        end
                    end
                    % =====================================================
```

- [ ] **Step 4: 在算法结束时保存 .mat**

在 `while Algorithm.NotTerminated(Archive)` 循环之后（原算法第 200 行 `end` 之后、`end` 方法之前），添加：

```matlab
            % ====== PROBE: persist all snapshots ======
            if ~isempty(probe_out_path) && ~isempty(probe_records)
                probe_data = probe_records;   %#ok<NASGU>
                problem_name = class(Problem);
                M_val = Problem.M;
                D_val = Problem.D;
                maxFE_val = Problem.maxFE;
                save(probe_out_path, 'probe_data', 'problem_name', ...
                     'M_val', 'D_val', 'maxFE_val', '-v7');
            end
            % ==========================================
```

- [ ] **Step 5: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/REMO_DiRel_probed.m"
git commit -m "在算法副本中嵌入探针、checkpoint 触发与持久化"
```

---

## Task 6: 实现 run_probe_experiment.m 实验入口

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/run_probe_experiment.m`

- [ ] **Step 1: 创建脚本**

新建 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/run_probe_experiment.m`，内容：

```matlab
function run_probe_experiment(varargin)
% run_probe_experiment - 跑 REMO_DiRel_probed 的一致性实验。
%
% Usage:
%   run_probe_experiment                    % 跑全部 4 问题 x 10 run
%   run_probe_experiment('runs', 3)         % 只跑 3 run，快速冒烟测试
%   run_probe_experiment('problems', {{@DTLZ2, 3, 10}})  % 只跑指定问题

    p = inputParser;
    p.addParameter('runs', 10);
    p.addParameter('problems', { ...
        {@DTLZ2, 3, 10}, ...
        {@DTLZ2, 5, 10}, ...
        {@MaF1,  5, 10}, ...
        {@MaF3,  8, 10}  ...
    });
    p.addParameter('maxFE', 300);
    p.parse(varargin{:});
    opt = p.Results;

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    if ~exist(results_dir, 'dir')
        mkdir(results_dir);
    end
    addpath(this_dir);

    % 把 PlatEMO 根目录加到 path（必要时）
    platemo_root = fileparts(fileparts(fileparts(this_dir)));   % .../PlatEMO
    addpath(genpath(platemo_root));

    total = numel(opt.problems) * opt.runs;
    counter = 0;
    t_all = tic;

    for pi = 1:numel(opt.problems)
        prob_spec = opt.problems{pi};
        ProbFcn = prob_spec{1};
        M_val = prob_spec{2};
        D_val = prob_spec{3};
        prob_name = func2str(ProbFcn);

        for r = 1:opt.runs
            counter = counter + 1;
            out_file = fullfile(results_dir, sprintf('probe_%s_M%d_run%d.mat', prob_name, M_val, r));

            if exist(out_file, 'file')
                fprintf('[%d/%d] SKIP (exists): %s\n', counter, total, out_file);
                continue;
            end

            fprintf('[%d/%d] %s M=%d D=%d run=%d ... ', counter, total, prob_name, M_val, D_val, r);
            t0 = tic;
            try
                platemo( ...
                    'algorithm', {@REMO_DiRel_probed, -1, 0.3, 0.6, 6, 1000, 3, 3, out_file}, ...
                    'problem',   ProbFcn, ...
                    'M', M_val, 'D', D_val, ...
                    'maxFE', opt.maxFE, ...
                    'save', 0, ...
                    'run', r);
                fprintf('done (%.1fs)\n', toc(t0));
            catch ME
                fprintf('FAILED: %s\n', ME.message);
            end
        end
    end

    fprintf('All done in %.1f min.\n', toc(t_all)/60);
end
```

- [ ] **Step 2: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/run_probe_experiment.m"
git commit -m "实验驱动脚本 run_probe_experiment"
```

---

## Task 7: 冒烟测试（1 问题 × 1 run）

**Files:**
- None (run-only验证)

- [ ] **Step 1: 启动 MATLAB 并进入仓库**

```matlab
cd 'd:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe';
```

- [ ] **Step 2: 跑一次最小实验**

```matlab
run_probe_experiment('runs', 1, 'problems', {{@DTLZ2, 3, 10}});
```

预期输出：

```
[1/1] DTLZ2 M=3 D=10 run=1 ... done (xx.xs)
All done in x.x min.
```

且 `results/probe_DTLZ2_M3_run1.mat` 文件存在。

- [ ] **Step 3: 验证 .mat 内容**

```matlab
S = load('results/probe_DTLZ2_M3_run1.mat');
fprintf('snapshots: %d\n', numel(S.probe_data));
fprintf('problem: %s, M=%d, D=%d, maxFE=%d\n', S.problem_name, S.M_val, S.D_val, S.maxFE_val);
for i = 1:numel(S.probe_data)
    rec = S.probe_data{i};
    fprintf('  gen=%d FE=%d ckpt=%.2f L1=%.3f L2=%.3f L3=%.3f\n', ...
        rec.gen, rec.FE, rec.checkpoint_val, rec.agree_L1, rec.agree_L2, rec.agree_L3);
end
```

预期：snapshots 数量在 1~5 之间（取决于 300 FE 内有多少代触及 checkpoint），所有 L1/L2/L3 都是 [0, 1] 之间的有限值。

如果 snapshots = 0：说明 `Problem.FE / Problem.maxFE` 触发条件没命中，需要调试探针位置。最常见原因：进入主循环时 Problem.FE 已经超过 0.04 阈值（初始评估消耗了 11D-1=109 ≈ 36% 的 FE）——这时候第一次循环就该一次性命中多个 checkpoint，正常。

- [ ] **Step 4: 不 commit（仅本地验证）**

如果上述都正常，进入下一任务。如果有问题，回到 Task 4/5 修复。

---

## Task 8: 实现图 1（折线带误差带）

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_line_over_gens.m`

- [ ] **Step 1: 创建脚本**

新建 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_line_over_gens.m`，内容：

```matlab
function plot_line_over_gens()
% plot_line_over_gens - 图1：一致性随 checkpoint 进度变化的折线图（带误差带）

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    fig_dir = fullfile(this_dir, 'figures');
    if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

    problems = {{'DTLZ2', 3}, {'DTLZ2', 5}, {'MaF1', 5}, {'MaF3', 8}};
    checkpoints = [0.04, 0.20, 0.40, 0.60, 0.80];
    n_ckpt = numel(checkpoints);

    fig = figure('Position', [100, 100, 1200, 800]);
    for pi = 1:numel(problems)
        prob_name = problems{pi}{1};
        M_val = problems{pi}{2};

        files = dir(fullfile(results_dir, sprintf('probe_%s_M%d_run*.mat', prob_name, M_val)));
        if isempty(files)
            warning('No data for %s M=%d', prob_name, M_val);
            continue;
        end

        % 按 (ckpt_idx, run) 收集 L1/L2/L3
        L1 = nan(numel(files), n_ckpt);
        L2 = nan(numel(files), n_ckpt);
        L3 = nan(numel(files), n_ckpt);

        for fi = 1:numel(files)
            S = load(fullfile(results_dir, files(fi).name));
            for k = 1:numel(S.probe_data)
                rec = S.probe_data{k};
                ci = rec.checkpoint_idx;
                if isnan(L1(fi, ci)) || rec.gen > 0
                    % 一个 ckpt 一次值（取第一次命中），如果命中多次就用最新
                    L1(fi, ci) = rec.agree_L1;
                    L2(fi, ci) = rec.agree_L2;
                    L3(fi, ci) = rec.agree_L3;
                end
            end
        end

        subplot(2, 2, pi); hold on;
        plot_band(checkpoints, L1, [0.20, 0.40, 0.80], 'L1 PBI');
        plot_band(checkpoints, L2, [0.85, 0.40, 0.20], 'L2 mu-sign');
        plot_band(checkpoints, L3, [0.30, 0.70, 0.30], 'L3 pair-pred');
        xlabel('Progress (FE / maxFE)');
        ylabel('Agreement ratio');
        title(sprintf('%s (M=%d)', prob_name, M_val));
        ylim([0, 1]); xlim([0, 1]); grid on;
        legend('Location', 'southoutside', 'Orientation', 'horizontal');
    end

    sgtitle('REMO\_DiRel: full-net vs sub-net agreement over training progress');
    saveas(fig, fullfile(fig_dir, 'fig1_line_over_progress.png'));
    savefig(fig, fullfile(fig_dir, 'fig1_line_over_progress.fig'));
    fprintf('Saved fig1 to %s\n', fig_dir);
end


function plot_band(x, Y, rgb, name)
    mu = mean(Y, 1, 'omitnan');
    sd = std(Y, 0, 1, 'omitnan');
    valid = ~isnan(mu);
    x = x(valid); mu = mu(valid); sd = sd(valid);
    fill([x, fliplr(x)], [mu+sd, fliplr(mu-sd)], rgb, ...
         'FaceAlpha', 0.18, 'EdgeColor', 'none', 'HandleVisibility', 'off');
    plot(x, mu, 'Color', rgb, 'LineWidth', 1.6, 'Marker', 'o', ...
         'MarkerFaceColor', rgb, 'DisplayName', name);
end
```

- [ ] **Step 2: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_line_over_gens.m"
git commit -m "图 1：进度-一致性折线图（带误差带）"
```

---

## Task 9: 实现图 2（末代箱线图）

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_boxplot.m`

- [ ] **Step 1: 创建脚本**

新建 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_boxplot.m`，内容：

```matlab
function plot_boxplot()
% plot_boxplot - 图2：末代（进度 80%）一致性箱线图

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    fig_dir = fullfile(this_dir, 'figures');
    if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

    problems = {{'DTLZ2', 3}, {'DTLZ2', 5}, {'MaF1', 5}, {'MaF3', 8}};
    last_ckpt = 5;     % 进度 80% 那一个 checkpoint
    levels = {'L1', 'L2', 'L3'};
    fld    = {'agree_L1', 'agree_L2', 'agree_L3'};

    vals = [];     % 数值
    grp_prob = {};  % 问题名
    grp_lvl = {};   % 层

    for pi = 1:numel(problems)
        prob_name = problems{pi}{1};
        M_val = problems{pi}{2};
        prob_label = sprintf('%s\\_M%d', prob_name, M_val);

        files = dir(fullfile(results_dir, sprintf('probe_%s_M%d_run*.mat', prob_name, M_val)));
        for fi = 1:numel(files)
            S = load(fullfile(results_dir, files(fi).name));
            rec = [];
            for k = 1:numel(S.probe_data)
                if S.probe_data{k}.checkpoint_idx == last_ckpt
                    rec = S.probe_data{k};
                end
            end
            if isempty(rec); continue; end
            for li = 1:3
                vals(end+1, 1) = rec.(fld{li}); %#ok<AGROW>
                grp_prob{end+1, 1} = prob_label; %#ok<AGROW>
                grp_lvl{end+1, 1} = levels{li}; %#ok<AGROW>
            end
        end
    end

    if isempty(vals)
        warning('No data found for boxplot.');
        return;
    end

    fig = figure('Position', [100, 100, 1100, 500]);
    % 用复合 group 让箱子按 problem 分组、层并排
    grp = strcat(grp_prob, '\_', grp_lvl);
    boxplot(vals, grp, 'LabelOrientation', 'inline');
    ylabel('Agreement ratio at final checkpoint (FE = 80% maxFE)');
    title('Per-problem per-level agreement distribution across 10 runs');
    ylim([0, 1]); grid on;

    saveas(fig, fullfile(fig_dir, 'fig2_boxplot_final.png'));
    savefig(fig, fullfile(fig_dir, 'fig2_boxplot_final.fig'));
    fprintf('Saved fig2 to %s\n', fig_dir);
end
```

- [ ] **Step 2: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_boxplot.m"
git commit -m "图 2：末代一致性箱线图"
```

---

## Task 10: 实现图 3（目标空间散点 / 平行坐标）

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_objective_scatter.m`

- [ ] **Step 1: 创建脚本**

新建 `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_objective_scatter.m`，内容：

```matlab
function plot_objective_scatter()
% plot_objective_scatter - 图3：目标空间散点图（DTLZ2 M=3 散点 + MaF3 M=8 平行坐标）

    this_dir = fileparts(mfilename('fullpath'));
    results_dir = fullfile(this_dir, 'results');
    fig_dir = fullfile(this_dir, 'figures');
    if ~exist(fig_dir, 'dir'); mkdir(fig_dir); end

    last_ckpt = 5;

    fig = figure('Position', [100, 100, 1300, 550]);

    % --- 左：DTLZ2 M=3，3D 散点 ---
    rec = load_one(results_dir, 'DTLZ2', 3, 1, last_ckpt);
    subplot(1, 2, 1);
    if ~isempty(rec)
        plot_scatter3(rec);
    else
        title('DTLZ2 M=3 run=1: missing');
    end

    % --- 右：MaF3 M=8，平行坐标 ---
    rec = load_one(results_dir, 'MaF3', 8, 1, last_ckpt);
    subplot(1, 2, 2);
    if ~isempty(rec)
        plot_parallel(rec);
    else
        title('MaF3 M=8 run=1: missing');
    end

    sgtitle('Two-network agreement vs conflict in objective space');
    saveas(fig, fullfile(fig_dir, 'fig3_objective_scatter.png'));
    savefig(fig, fullfile(fig_dir, 'fig3_objective_scatter.fig'));
    fprintf('Saved fig3 to %s\n', fig_dir);
end


function rec = load_one(results_dir, prob_name, M_val, run_id, ckpt_idx)
    fp = fullfile(results_dir, sprintf('probe_%s_M%d_run%d.mat', prob_name, M_val, run_id));
    rec = [];
    if ~exist(fp, 'file'); return; end
    S = load(fp);
    for k = 1:numel(S.probe_data)
        if S.probe_data{k}.checkpoint_idx == ckpt_idx
            rec = S.probe_data{k};
            rec.problem_name = S.problem_name;
            rec.M_val = S.M_val;
            return;
        end
    end
end


function [g, names, colors] = grouping(rec)
% 4 类：F+S+, F-S-, F+S-, F-S+ (按 PBI 标签是否 == 1)
    f = (rec.label_F == 1);
    s = (rec.label_S == 1);
    g = zeros(numel(f), 1);
    g( f &  s) = 1;
    g(~f & ~s) = 2;
    g( f & ~s) = 3;
    g(~f &  s) = 4;
    names = {'F+ S+ (both +1)', 'F- S- (both non+1)', 'F+ S- (full only)', 'F- S+ (sub only)'};
    colors = [0.20, 0.40, 0.80;
              0.70, 0.70, 0.70;
              0.85, 0.40, 0.20;
              0.30, 0.70, 0.30];
end


function plot_scatter3(rec)
    Obj = rec.PopObj;
    [g, names, C] = grouping(rec);
    hold on;
    for cls = 1:4
        mask = (g == cls);
        if any(mask)
            scatter3(Obj(mask, 1), Obj(mask, 2), Obj(mask, 3), 60, C(cls, :), ...
                'filled', 'MarkerEdgeColor', 'k', 'DisplayName', names{cls});
        end
    end
    xlabel('f_1'); ylabel('f_2'); zlabel('f_3');
    title(sprintf('%s M=%d, gen=%d (L1=%.2f)', rec.problem_name, rec.M_val, rec.gen, rec.agree_L1));
    view(45, 25); grid on;
    legend('Location', 'eastoutside');
end


function plot_parallel(rec)
    Obj = rec.PopObj;
    M = size(Obj, 2);
    Obj_n = (Obj - min(Obj, [], 1)) ./ max(range(Obj, 1), 1e-12);
    [g, names, C] = grouping(rec);
    hold on;
    handles = gobjects(4, 1);
    for cls = 1:4
        mask = (g == cls);
        rows = find(mask);
        for i = 1:numel(rows)
            h = plot(1:M, Obj_n(rows(i), :), 'Color', [C(cls, :), 0.5], 'LineWidth', 1);
            if i == 1; handles(cls) = h; end
        end
    end
    xlabel('Objective index'); ylabel('Normalized value');
    title(sprintf('%s M=%d, gen=%d (L1=%.2f)', rec.problem_name, rec.M_val, rec.gen, rec.agree_L1));
    xticks(1:M); ylim([0, 1.05]); grid on;
    valid = isgraphics(handles);
    legend(handles(valid), names(valid), 'Location', 'eastoutside');
end
```

- [ ] **Step 2: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/plot_objective_scatter.m"
git commit -m "图 3：目标空间散点 / 平行坐标"
```

---

## Task 11: 跑完整实验 + 出三张图

**Files:**
- None (运行)

- [ ] **Step 1: 跑完整实验**

```matlab
cd 'd:/PlatEMO-master/PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe';
run_probe_experiment();
```

预计耗时：4 问题 × 10 run × 单 run 约 30s-2min（取决于机器和 M），总共 ≈ 30-90 分钟。

预期产出：`results/` 目录下出现 40 个 `.mat` 文件，命名形如 `probe_DTLZ2_M3_run1.mat` 等。

- [ ] **Step 2: 检查文件数**

```matlab
files = dir(fullfile('results', 'probe_*.mat'));
fprintf('Got %d .mat files (expected 40)\n', numel(files));
```

预期：40。如果少于 40，找出缺失的并重跑那部分（脚本里有 SKIP 逻辑，再次调用会自动续跑）。

- [ ] **Step 3: 出图**

```matlab
plot_line_over_gens();
plot_boxplot();
plot_objective_scatter();
```

预期：`figures/` 下出现 6 个文件（每张图 .png + .fig）。

- [ ] **Step 4: 把图也加入 git**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/figures/"
git commit -m "实验结果：3 张一致性可视化图"
```

注意：**results/ 不要 commit**（40 个 .mat 文件可能很大）。建议在该目录加个 `.gitignore` 排除：

```bash
echo "*.mat" > "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/results/.gitignore"
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/results/.gitignore"
git commit -m "ignore probe .mat results"
```

---

## Task 12: 写一段结论分析

**Files:**
- Create: `PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/RESULTS.md`

- [ ] **Step 1: 看图、读三层数值，写一份不超过一页的结论**

模板：

```markdown
# REMO_DiRel 双网络一致性实验结果

## 数据
4 问题（DTLZ2 M=3/5, MaF1 M=5, MaF3 M=8） × 10 run × 5 checkpoint，maxFE=300。

## 三层末代一致率（10 run 均值±标准差）

| 问题 | L1 PBI | L2 mu-sign | L3 pair-pred |
|---|---|---|---|
| DTLZ2 M=3 | 填入 | 填入 | 填入 |
| DTLZ2 M=5 | 填入 | 填入 | 填入 |
| MaF1 M=5  | 填入 | 填入 | 填入 |
| MaF3 M=8  | 填入 | 填入 | 填入 |

## 关键观察
1. ...
2. ...
3. ...

## 对 ArbitratorScore 权重策略的建议
- 如果 L2 整体偏低（<0.6） → 当前逆方差融合的边际收益弱
- 如果 L1 高 L3 低 → 网络拟合不够，考虑加大训练 epoch 或集成规模
- 如果 L3 在难问题上明显低于易问题 → 子目标网络可能在难场景下崩坏，应降低其权重
```

- [ ] **Step 2: Commit**

```bash
git add "PlatEMO-master/PlatEMO/Experiments/REMO_DiRel_AgreementProbe/RESULTS.md"
git commit -m "实验结论与权重权衡建议"
```

---

## 自我审查

- **Spec 覆盖：** spec 三层指标 → Task 4；探针位置/checkpoint → Task 5；4 问题 × 10 run × 300 FE → Task 6/11；3 张图 → Task 8/9/10。✓
- **Placeholder 扫描：** 无 TBD；compute_agreement 完整给出；plot_* 完整给出。✓
- **类型一致：**
  - `compute_agreement` 输出字段：`agree_L1`、`agree_L2`、`agree_L3`、`label_F`、`label_S`、`PopObj`、`checkpoint_idx`（在 Task 5 由探针补上）。Task 8/9/10 都用这些字段名 — 一致。✓
  - `scoreAllByEnsemble_probe` 签名与原函数完全一致。✓
  - `ensemblePredict_probe` 签名与原 private 函数一致。✓
- **风险点提醒：** Task 7 步骤 3 已经预警过"初始评估消耗 FE=109，首次循环可能一次命中多个 checkpoint"的情况。L3 对齐用同决策对而非同 (xx_F, xx_S)，避开了关系对样本不对齐问题。
