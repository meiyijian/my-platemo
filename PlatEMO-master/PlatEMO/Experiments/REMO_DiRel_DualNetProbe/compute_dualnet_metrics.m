function rec = compute_dualnet_metrics(Problem, Population, Candidates, Smodel, gen, FE)
% compute_dualnet_metrics - 记录双网络对候选解的详细预测数据和真实标签。
%
% 对每个候选解记录：
%   - 两个模型的预测(mu)和方差(sigma2)
%   - 逆方差融合权重(w_F)
%   - 融合得分(base)
%   - 冲突/弃权/子目标主导标记
%   - 真实Pareto支配关系（候选 vs 种群）—— 用 Problem.CalObj 旁路评估，
%     不增加 Problem.FE。同时保留决策空间最近邻估计 (NN) 作为对比基线。
%   - PBI分类标签（全目标/子目标）
%
% 输入：
%   Problem    - PlatEMO PROBLEM 对象（用于 CalObj 旁路评估）
%   Population - 当前种群
%   Candidates - nCand×D 候选解决策变量
%   Smodel     - 代理模型结构体
%   gen        - 当前代数
%   FE         - 当前评估次数
%
% 输出：
%   rec - 包含所有数据的结构体

    nCand = size(Candidates, 1);
    PopObj = Population.objs;
    PopDec = Population.decs;
    N = size(PopObj, 1);
    M = size(PopObj, 2);

    rec = struct();
    rec.gen = gen;
    rec.FE  = FE;
    rec.nCand = nCand;
    rec.N   = N;
    rec.M   = M;
    rec.S_easy = Smodel.S_easy;
    rec.PopObj = PopObj;

    if nCand == 0
        return;
    end

    % ===================================================================
    % 第一步：用两个集成网络分别评分
    % ===================================================================
    [mu_F, sigma2_F] = scoreAllByEnsemble_local( ...
        Smodel.X, Smodel.Y_F, Smodel.DualNet.nets_F, ...
        Smodel.DualNet.mp_struct_F, Candidates, Smodel.anchorMax);

    [mu_S, sigma2_S] = scoreAllByEnsemble_local( ...
        Smodel.X, Smodel.Y_S, Smodel.DualNet.nets_S, ...
        Smodel.DualNet.mp_struct_S, Candidates, Smodel.anchorMax);

    % ===================================================================
    % 第二步：计算融合权重和得分（复现 ArbitratorScore 逻辑）
    % ===================================================================
    s_F = sqrt(max(sigma2_F, 0));
    s_S = sqrt(max(sigma2_S, 0));

    n_F = minmaxNorm_local(s_F);
    n_S = minmaxNorm_local(s_S);

    tildeS_F = minmaxNormScore_local(mu_F);
    tildeS_S = minmaxNormScore_local(mu_S);

    eps_v = 1e-6;
    invF = 1 ./ (s_F.^2 + eps_v);
    invS = 1 ./ (s_S.^2 + eps_v);
    w_F  = invF ./ (invF + invS);
    w_S  = 1 - w_F;

    base = w_F .* tildeS_F + w_S .* tildeS_S;

    tau = Smodel.tau_conf;
    conflict  = (sign(mu_F) .* sign(mu_S)) < 0;
    abstain   = conflict & (n_F > tau) & (n_S > tau);
    subwin    = conflict & (mu_S > 0) & (mu_F < 0) & (n_F > tau) & (n_S <= tau);

    base(abstain) = 0;

    % ===================================================================
    % 第三步：计算真实Pareto支配关系
    % ===================================================================
    % 真实评估：直接调用 Problem.CalObj 计算候选解的真实目标值，
    % 不增加 Problem.FE（旁路评估，仅用于 probe，不影响算法）。
    % 同时保留决策空间最近邻估计 (NN) 作为对比基线，
    % 可用于量化 NN 估计相对真值的偏差。
    CandObj_nn = estimateCandidateObj(Candidates, PopDec, PopObj);
    try
        % Problem.CalDec 做边界裁剪+整数修复，与 Evaluation 保持一致
        CandDec_repaired = Problem.CalDec(Candidates);
        CandObj_real = Problem.CalObj(CandDec_repaired);
        has_real = true;
    catch ME
        warning('CalObj bypass failed at gen %d: %s. Falling back to NN.', gen, ME.message);
        CandObj_real = CandObj_nn;
        has_real = false;
    end

    % 主分析使用真实目标值
    CandObj = CandObj_real;

    % --- 基于真实目标值计算 Pareto 支配关系 ---
    [dominated_by_pop, dominates_pop, true_quality] = ...
        computePopDominance(CandObj_real, PopObj);
    nondominated = ~(dominated_by_pop & ~dominates_pop) & ...
                   ~(dominates_pop & ~dominated_by_pop);

    % --- 同时基于 NN 估计算一遍，用于诊断 NN 误差 ---
    [dominated_by_pop_nn, dominates_pop_nn, true_quality_nn] = ...
        computePopDominance(CandObj_nn, PopObj);

    % --- 消融 A：子空间下的真实 Pareto 支配（同源评估 S 网络）---
    % 把候选解和种群都投影到 S_easy 子目标空间，再做支配判定。
    % 这样 S 网络的"考卷"就和它的"训练课程"一致了，消除评估口径不公平。
    S_easy_vec_local = double(Smodel.S_easy(:)');
    CandObjSub = CandObj_real(:, S_easy_vec_local);
    PopObjSub  = PopObj(:, S_easy_vec_local);
    [dominated_by_pop_sub, dominates_pop_sub, true_quality_S] = ...
        computePopDominance(CandObjSub, PopObjSub);

    % ===================================================================
    % 第四步：PBI分类标签（全目标和子目标）
    % ===================================================================
    % 用种群参考解来做PBI分类
    k = min(6, N);
    try
        Ref = RefSelect(Population, k);
    catch
        Ref = RefSelect_local(Population, k);
    end
    RefObj = Ref.objs;

    % 全目标PBI标签
    AllObj_F = [PopObj; CandObj];
    try
        Catalog_all_F = GetOutput_PBI(AllObj_F, RefObj);
    catch
        Catalog_all_F = GetOutput_PBI_local(AllObj_F, RefObj);
    end
    Catalog_cand_F = Catalog_all_F(N+1:end);

    % 子目标PBI标签
    S_easy = double(Smodel.S_easy(:)');
    AllObj_S = AllObj_F(:, S_easy);
    Ref_S_obj = RefObj(:, S_easy);
    P_min  = min(AllObj_S, [], 1);
    P_span = max(max(AllObj_S, [], 1) - P_min, 1e-12);
    Ref_S_obj = Ref_S_obj .* P_span + P_min;
    try
        Catalog_all_S = GetOutput_PBI(AllObj_S, Ref_S_obj);
    catch
        Catalog_all_S = GetOutput_PBI_local(AllObj_S, Ref_S_obj);
    end
    Catalog_cand_S = Catalog_all_S(N+1:end);

    % ===================================================================
    % 第五步：打包所有逐候选数据
    % ===================================================================
    rec.mu_F     = mu_F;
    rec.sigma2_F = sigma2_F;
    rec.s_F      = s_F;
    rec.n_F      = n_F;
    rec.tildeS_F = tildeS_F;

    rec.mu_S     = mu_S;
    rec.sigma2_S = sigma2_S;
    rec.s_S      = s_S;
    rec.n_S      = n_S;
    rec.tildeS_S = tildeS_S;

    rec.w_F      = w_F;
    rec.w_S      = w_S;
    rec.base     = base;

    rec.conflict = conflict;
    rec.abstain  = abstain;
    rec.subwin   = subwin;

    rec.dominated_by_pop = dominated_by_pop;
    rec.dominates_pop    = dominates_pop;
    rec.nondominated     = nondominated;
    rec.true_quality     = true_quality;            % 基于真值（主）
    rec.true_quality_S   = true_quality_S;          % 基于子空间真值（消融A，同源评估S网络）
    rec.dominated_by_pop_sub = dominated_by_pop_sub;
    rec.dominates_pop_sub    = dominates_pop_sub;
    rec.true_quality_nn  = true_quality_nn;         % 基于 NN 估计（对比基线）
    rec.has_real_obj     = has_real;

    rec.CandObj          = CandObj;                 % = CandObj_real（主）
    rec.CandObj_real     = CandObj_real;
    rec.CandObj_nn       = CandObj_nn;
    rec.Catalog_cand_F   = Catalog_cand_F;
    rec.Catalog_cand_S   = Catalog_cand_S;

    % ===================================================================
    % 第六步：汇总统计
    % ===================================================================
    rec.stat_agree_sign   = mean(sign(mu_F) == sign(mu_S));
    rec.stat_agree_catalog = mean(Catalog_cand_F == Catalog_cand_S);
    rec.stat_conflict_rate = mean(conflict);
    rec.stat_abstain_rate  = mean(abstain);
    rec.stat_subwin_rate   = mean(subwin);
    rec.stat_w_F_mean      = mean(w_F);
    rec.stat_w_F_std       = std(w_F);

    % 准确率：mu_F符号 vs 真实质量（基于真值）
    rec.stat_acc_F = mean(sign(mu_F) == true_quality);
    rec.stat_acc_S = mean(sign(mu_S) == true_quality);
    % 同时记录 NN 基线下的准确率，便于评估 NN 估计偏差
    rec.stat_acc_F_nn = mean(sign(mu_F) == true_quality_nn);
    rec.stat_acc_S_nn = mean(sign(mu_S) == true_quality_nn);
    % 消融A：在 S 网络原生子空间下的同源准确率
    rec.stat_acc_F_sub = mean(sign(mu_F) == true_quality_S);
    rec.stat_acc_S_sub = mean(sign(mu_S) == true_quality_S);
    % 全空间标签 vs 子空间标签的一致率（衡量两个任务有多不一样）
    rec.stat_label_agree_full_sub = mean(true_quality == true_quality_S);
    % NN 与真值在标签层面的一致率（衡量 NN 假冒 ground truth 的质量）
    rec.stat_label_agree_real_nn = mean(true_quality == true_quality_nn);

    % 冲突时谁更准确（基于真值）
    if any(conflict)
        rec.stat_acc_F_conflict = mean(sign(mu_F(conflict)) == true_quality(conflict));
        rec.stat_acc_S_conflict = mean(sign(mu_S(conflict)) == true_quality(conflict));
    else
        rec.stat_acc_F_conflict = NaN;
        rec.stat_acc_S_conflict = NaN;
    end

    % 选择一致性：按各模型单独选 vs 融合选
    threshold = 3.9;
    sel_F = tildeS_F > threshold;
    sel_S = tildeS_S > threshold;
    sel_fused = base > threshold;
    rec.stat_sel_overlap_FS = mean(sel_F & sel_S);  % 两模型都选
    rec.stat_sel_only_F    = mean(sel_F & ~sel_S);   % 只有全目标选
    rec.stat_sel_only_S    = mean(sel_S & ~sel_F);   % 只有子目标选
    rec.stat_sel_fused     = mean(sel_fused);         % 融合选
end


%% ========================================================================
%  辅助函数
%  ========================================================================

function [dominated_by_pop, dominates_pop, true_quality] = computePopDominance(CandObj, PopObj)
% 计算候选解与种群的 Pareto 支配关系。
%   dominated_by_pop(i) = true  : 候选i 被种群中至少一个解严格支配
%   dominates_pop(i)    = true  : 候选i 严格支配种群中至少一个解
%   true_quality        ∈ {-1,1}: 被支配=-1，否则=1（支配或互不支配）
    nCand = size(CandObj, 1);
    N     = size(PopObj, 1);
    dominated_by_pop = false(nCand, 1);
    dominates_pop    = false(nCand, 1);

    for i = 1:nCand
        ci = CandObj(i, :);
        for j = 1:N
            pj = PopObj(j, :);
            if all(ci <= pj) && any(ci < pj)
                dominates_pop(i) = true;
            elseif all(pj <= ci) && any(pj < ci)
                dominated_by_pop(i) = true;
            end
        end
    end

    true_quality = ones(nCand, 1);
    true_quality(dominated_by_pop & ~dominates_pop) = -1;
end


function CandObj = estimateCandidateObj(Candidates, PopDec, PopObj)
% 用决策空间最近邻来估计候选解的目标值（仅作为对比基线）
    nCand = size(Candidates, 1);
    M = size(PopObj, 2);
    CandObj = zeros(nCand, M);
    for i = 1:nCand
        dist = sum((PopDec - Candidates(i, :)).^2, 2);
        [~, idx] = min(dist);
        CandObj(i, :) = PopObj(idx, :);
    end
end


function [mu, sigma2] = scoreAllByEnsemble_local(X_train, Y_train, nets, mp_struct, Candidates, anchorMax)
    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    K = numel(nets_v);
    nCand = size(Candidates, 1);

    if K == 0
        mu = zeros(nCand, 1);
        sigma2 = ones(nCand, 1);
        return;
    end

    C1 = selectAnchors_local(X_train(Y_train == 1, :), anchorMax);
    C2 = selectAnchors_local(X_train(Y_train ~= 1, :), anchorMax);

    sample_scores = zeros(nCand, K);
    for kk = 1:K
        sample_scores(:, kk) = scoreOneNet_local(C1, C2, nets_v{kk}, mp_struct, Candidates);
    end

    mu = mean(sample_scores, 2);
    if K >= 2
        sigma2 = var(sample_scores, 0, 2);
    else
        sigma2 = ones(nCand, 1);
    end
end


function X = selectAnchors_local(X, anchorMax)
    n = size(X, 1);
    if n <= anchorMax
        return;
    end
    idx = unique(round(linspace(1, n, anchorMax)), 'stable');
    X = X(idx, :);
end


function scoreVec = scoreOneNet_local(C1, C2, net, mp_struct, Candidates)
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


function y = minmaxNorm_local(x)
    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if span < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end


function y = minmaxNormScore_local(x)
    y = minmaxNorm_local(x) .* 4;
end


function Ref = RefSelect_local(Population, k)
% 简化版RefSelect：从种群中均匀选k个解作为参考解
    N = length(Population);
    if k >= N
        Ref = Population;
        return;
    end
    idx = unique(round(linspace(1, N, k)), 'stable');
    Ref = Population(idx);
end


function Output = GetOutput_PBI_local(Pop, Ref)
% GetOutput_PBI_local - 简化版PBI分类（当真实函数不可用时的fallback）。
% 复现 REMO/GetOutput_PBI.m 的核心逻辑。
    delt_l = -20; delt_u = 20;
    r = 0;
    Output = true(size(Pop,1), 1);
    for iter = 1:50
        delt_c = (delt_l + delt_u) / 2;
        if abs(delt_l - delt_u) < 1e-1
            break;
        end
        [Output, r] = split_data_local(Pop, Ref, delt_c);
        if r > 0.7
            delt_l = delt_c;
        elseif r < 0.3
            delt_u = delt_c;
        end
    end
    [Output, ~] = split_data_local(Pop, Ref, (delt_l + delt_u) / 2);
end

function [Output, rate] = split_data_local(Pop, Ref, delt)
    N = size(Pop, 1);
    Output = true(N, 1);
    [~, ref_index] = max(1 - pdist2(Pop, Ref, 'cosine'), [], 2);
    Z = min(Pop, [], 1);
    for i = 1:size(Ref, 1)
        sub_mask = (ref_index == i);
        if ~any(sub_mask)
            continue;
        end
        sub_pop = Pop(sub_mask, :);
        BOUND = Ref(i, :);
        w = BOUND - Z;
        W = w ./ sqrt(sum(w.^2, 2));
        normW = sqrt(sum(W.^2, 2));
        normP = sqrt(sum((sub_pop - Z).^2, 2));
        normR = sqrt(sum((BOUND - Z).^2, 2));
        CosineP = (sum((sub_pop - Z) .* W, 2) ./ normW ./ normP) - 1e-6;
        g = normP .* CosineP + delt * normP .* sqrt(1 - CosineP.^2);
        g = g ./ normR;
        sub_idx = find(sub_mask);
        Output(sub_idx(g > 1)) = false;
    end
    rate = sum(Output) / N;
end
