function Next = RSurrogateAssistedSelection(Problem, Ref, Input, wmax, Smodel)
% RSurrogateAssistedSelection - 两阶段筛选：关系网络粗筛 + 指标 SVR 精挑（v4 累积候选池版本）
%
% 输入：
%   Problem : PlatEMO 问题对象
%   Ref     : 参考解集合
%   Input   : 当前种群决策变量
%   wmax    : 代理模型评估上限
%   Smodel  : 含 net（关系网络）+ IndicatorModel（指标 SVR）+ X/Y/mp_struct
%
% 输出：
%   Next : 选出的真实评估候选解
%
% v4 关键改进（vs PIEA3）：
%   - PIEA3 的 while 循环每次覆盖 Next，循环结束时只剩最后一代 ~12 个候选
%     → 粗筛 top-30% 只剩 4 个 → SVR 精排实际是 4 选 4，毫无意义
%   - v4 累积所有 GA 内循环候选到 all_candidates，去重后量级数百
%     → 粗筛 / 精排都在大候选池上做，两阶段筛选才真正起作用
%
% 设计要点：
%   1. 两阶段筛选：先关系（粗）再指标（精），不是加权融合
%   2. 内循环用关系得分驱动 GA 进化（关系排序更鲁棒）
%   3. v4：累积所有 GA 候选到 all_candidates（关键修复）
%   4. 末尾用 quantile 取代 `>3.9` 死阈值
%   5. 每代选 5~8 个解（不是 PIEA 的 1 个，避免 maxFE 用不完）

    %% Step 1: 用关系网络驱动 GA 内循环（同时累积候选池）
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
    all_candidates = Next;          % v4 新增：累积池起点
    i = size(Next, 1);
    while i < wmax
        [sorted_idx, ~] = model_select_relation(Smodel, Next);
        Input_new = Next(sorted_idx(1 : min(length(Ref), size(Next, 1))), :);
        Next = OperatorGA(Problem, [Input_new; Ref.decs], {1, 15, 1, 5});
        all_candidates = [all_candidates; Next];   % v4 新增：累加
        i = i + size(Next, 1);
    end

    %% v4 新增：累积池去重（避免完全相同的候选解）
    all_candidates = unique(all_candidates, 'rows', 'stable');

    %% Step 2: 关系网络在累积池上粗筛 top-30%
    [~, scores_rel] = model_select_relation(Smodel, all_candidates);
    n_keep = max(20, ceil(size(all_candidates, 1) * 0.3));
    n_keep = min(n_keep, size(all_candidates, 1));
    [~, idx_rel] = sort(scores_rel, 'descend');
    coarse_keep = idx_rel(1 : n_keep);
    coarse_set  = all_candidates(coarse_keep, :);

    %% Step 3: 指标 SVR 在 top-30% 内精排
    if ~isempty(Smodel.IndicatorModel)
        try
            scores_ind = predict(Smodel.IndicatorModel, coarse_set);
        catch
            scores_ind = scores_rel(coarse_keep);
        end
    else
        scores_ind = scores_rel(coarse_keep);
    end

    %% Step 4: 分位数阈值取 5~8 个真实评估
    q70 = quantile(scores_ind, 0.7);
    keep = scores_ind > q70;
    if sum(keep) < 5
        [~, ind] = sort(scores_ind, 'descend');
        keep = false(size(scores_ind));
        keep(ind(1 : min(5, length(ind)))) = true;
    end

    cand_idx = find(keep);
    score_in_keep = scores_ind(cand_idx);
    [~, order] = sort(score_in_keep, 'descend');
    n_eval = min(8, max(5, length(cand_idx)));
    n_eval = min(n_eval, length(cand_idx));
    selected = cand_idx(order(1 : n_eval));
    Next = coarse_set(selected, :);
end


function [ind, scores] = model_select_relation(Smodel, Next)
% 复制自原 REMO_new2/RSurrogateAssistedSelection 的 model_select 子函数
% 用于关系网络打分（保持原 onehot 三类语义不变）

    model_x = Smodel.X;
    C1_data = model_x(Smodel.Y == 1, :);
    C2_data = model_x(Smodel.Y ~= 1, :);

    C1_num   = size(C1_data, 1);
    C2_num   = size(C2_data, 1);
    Next_num = size(Next, 1);

    if C1_num == 0 || C2_num == 0
        scores = zeros(Next_num, 1);
        ind = (1 : Next_num)';
        return;
    end

    scores = zeros(Next_num, 1);

    all_testdata = zeros(2 * (C1_num + C2_num) * Next_num, 2 * size(C1_data, 2));
    for i = 1 : Next_num
        original = (i - 1) * 2 * (C1_num + C2_num);
        Xi = repmat(Next(i, :), C1_num, 1);
        all_testdata(original + 1                : original + C1_num,         :) = [C1_data, Xi];
        all_testdata(original + 1 + C1_num       : original + C1_num * 2,     :) = [Xi, C1_data];

        Xi = repmat(Next(i, :), C2_num, 1);
        all_testdata(original + 1 + C1_num * 2          : original + C1_num * 2 + C2_num,         :) = [C2_data, Xi];
        all_testdata(original + 1 + C2_num + C1_num * 2 : original + C2_num * 2 + C1_num * 2,     :) = [Xi, C2_data];
    end

    TestIn_nor = mapminmax('apply', all_testdata', Smodel.mp_struct)';
    pre_out = Smodel.net(TestIn_nor')';

    for i = 1 : Next_num
        C_SCORE  = zeros(1, 2);
        original = (i - 1) * 2 * (C1_num + C2_num);

        pre_C1Xi   = sum(pre_out(original + 1 : original + C1_num, :), 1) ./ C1_num;
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);

        pre_XiC1   = sum(pre_out(original + 1 + C1_num : original + C1_num * 2, :), 1) ./ C1_num;
        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);

        pre_C2Xi   = sum(pre_out(original + 1 + C1_num * 2 : original + C1_num * 2 + C2_num, :), 1) ./ C2_num;
        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);

        pre_XiC2   = sum(pre_out(original + 1 + C2_num + C1_num * 2 : original + C2_num * 2 + C1_num * 2, :), 1) ./ C2_num;
        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);

        scores(i) = C_SCORE(1) - C_SCORE(2);
    end
    [~, ind] = sort(scores, 'descend');
end
