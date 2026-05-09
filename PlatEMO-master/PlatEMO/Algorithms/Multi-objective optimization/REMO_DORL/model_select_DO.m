function [ind, scores, conf_final] = model_select_DO(Smodel, Next)
% 决策-目标联合输入的关系打分（创新点 1 + 创新点 4）
%
% 输入：
%   Smodel : 训练好的代理模型结构体，含字段：
%              X         (N×D)  种群决策变量
%              F         (N×M)  种群目标值（已评估）
%              Y         (N×1)  Catalog（true=好解）
%              mp_struct        mapminmax 归一化结构（在 2D+2M 输入上）
%              net              patternnet 关系网络
%              LOS              轻量目标回归器（创新 2，可为 [] 退化）
%              use_LOS          是否启用 LOS（消融用）
%              use_ORC          是否启用 ORC 一致性（消融用）
%   Next   : K×D 候选解
%
% 输出：
%   ind        : 按 score 降序的索引
%   scores     : 每个候选解的 C_SCORE 净分数
%   conf_final : 每个候选解的最终平均置信度（含 ORC 加权）
%
% 关键改动（vs 原 model_select / model_select_confidence）：
%   ① 测试对维度从 2D 扩展到 2D + 2M：[x_C, x_new, f̃_C, f̃_new]
%   ② x_new 的 f 通过 LOS 预测得到（无需真实评估）
%   ③ ORC 一致性：网络预测的关系符号与 LOS 预测的目标差符号需一致
%      不一致则降权，conf_final = softmax_max_prob × (0.5 + 0.5×agree)

    D = size(Smodel.X, 2);
    M = size(Smodel.F, 2);
    Next_num = size(Next, 1);

    %% 创新 2：LOS 预测 Next 的目标值
    if Smodel.use_LOS && ~isempty(Smodel.LOS)
        F_next_hat = ObjectiveSurrogate('predict', Smodel.LOS, Next);
    else
        % 退化：LOS 关闭时用零向量占位（输入仍是 2D+2M，与训练保持维度一致）
        % 注意：训练时 f̃ 是种群真实目标值的归一化，此处推理用 0 不会引入对齐偏差
        % 因为只是软先验，关系网络本身仍能从 [x_i, x_j] 部分提取信息
        F_next_hat = zeros(Next_num, M);
    end

    %% 目标值归一化（与 GetRelationPairs_DO 保持完全一致：仅用种群 F 算 z_min/z_max）
    %  训练对中 f̃ 是基于种群目标值归一化的，推理时也必须用同一基准
    %  对预测的 F_next_hat 用同一组 z_min/z_max 归一化（可能落在 [0,1] 之外，但符合训练分布）
    z_min = min(Smodel.F, [], 1);
    z_max = max(Smodel.F, [], 1);
    F_pop_norm  = (Smodel.F      - z_min) ./ (z_max - z_min + eps);   % N×M
    F_next_norm = (F_next_hat    - z_min) ./ (z_max - z_min + eps);   % K×M

    %% 拆分种群为 C1 / C2
    C1_mask = Smodel.Y == 1;
    C2_mask = Smodel.Y ~= 1;

    C1_dec  = Smodel.X(C1_mask, :);          % n1×D
    C2_dec  = Smodel.X(C2_mask, :);          % n2×D
    C1_obj  = F_pop_norm(C1_mask, :);        % n1×M
    C2_obj  = F_pop_norm(C2_mask, :);        % n2×M

    C1_num = size(C1_dec, 1);
    C2_num = size(C2_dec, 1);

    scores      = zeros(Next_num, 1);
    conf_final  = zeros(Next_num, 1);

    %% 兜底：C1 或 C2 为空时返回零分零置信度
    if C1_num == 0 || C2_num == 0
        ind = (1:Next_num)';
        return;
    end

    %% 构造测试对：每个候选 Xi 与 C1/C2 形成 4 组测试对
    %  每组测试对的输入维度 = 2D + 2M
    %  顺序与原 model_select 保持一致：C1Xi, XiC1, C2Xi, XiC2
    pair_dim = 2*D + 2*M;
    n_per_xi = 2 * (C1_num + C2_num);
    all_testdata = zeros(n_per_xi * Next_num, pair_dim);

    % 同时记录每对的"目标差"用于 ORC 一致性判断
    % objgap_pair(k, :) = f̃_j - f̃_i (M 维)，k 是该对在 all_testdata 中的索引
    objgap_pair = zeros(n_per_xi * Next_num, M);

    for i = 1:Next_num
        original = (i-1) * n_per_xi;
        Xi_dec   = repmat(Next(i, :),       C1_num, 1);
        Xi_obj   = repmat(F_next_norm(i,:), C1_num, 1);

        % (C1, Xi) — first = C1, second = Xi
        rng = (original+1) : (original+C1_num);
        all_testdata(rng, :) = [C1_dec, Xi_dec, C1_obj, Xi_obj];
        objgap_pair(rng, :)  = Xi_obj - C1_obj;     % f̃_j - f̃_i

        % (Xi, C1)
        rng = (original+1+C1_num) : (original+C1_num*2);
        all_testdata(rng, :) = [Xi_dec, C1_dec, Xi_obj, C1_obj];
        objgap_pair(rng, :)  = C1_obj - Xi_obj;

        Xi_dec = repmat(Next(i, :),       C2_num, 1);
        Xi_obj = repmat(F_next_norm(i,:), C2_num, 1);

        % (C2, Xi)
        rng = (original+1+C1_num*2) : (original+C1_num*2+C2_num);
        all_testdata(rng, :) = [C2_dec, Xi_dec, C2_obj, Xi_obj];
        objgap_pair(rng, :)  = Xi_obj - C2_obj;

        % (Xi, C2)
        rng = (original+1+C2_num+C1_num*2) : (original+C2_num*2+C1_num*2);
        all_testdata(rng, :) = [Xi_dec, C2_dec, Xi_obj, C2_obj];
        objgap_pair(rng, :)  = C2_obj - Xi_obj;
    end

    %% 神经网络批量预测
    TestIn_nor = mapminmax('apply', all_testdata', Smodel.mp_struct)';
    pre_out    = Smodel.net(TestIn_nor')';     % N_pairs × 3 softmax 概率分布

    %% 创新 4：ORC 一致性置信度
    confidence_softmax = max(pre_out, [], 2);     % softmax max prob ∈ [1/3, 1]

    if Smodel.use_ORC
        % sign_obj：LOS 看（目标空间）认为 first 与 second 谁好
        %   sum(objgap_pair, 2) 简单聚合（M 维相加）— 正向支配的近似度量
        %   > 0 表示 second 总体更差（second - first 平均 > 0），即 first 更优 → 标签倾向 +1
        %   < 0 表示 first 更差 → 标签倾向 -1
        sign_obj = sign(sum(objgap_pair, 2));     % {-1, 0, +1}

        % sign_net：网络预测最大类对应的标签
        sign_net = onehotconv(pre_out, 2);        % {-1, 0, +1}

        % 一致性：符号相同 → 1，否则 0；中性 (0) 按 0.5 处理
        agree_strict = sign_obj .* sign_net;
        agree_score  = zeros(size(agree_strict));
        agree_score(agree_strict > 0)  = 1;
        agree_score(agree_strict == 0) = 0.5;
        agree_score(agree_strict < 0)  = 0;

        % 软一致性：conf × (0.5 + 0.5 × agree_score) → 范围 [0.5×conf, conf]
        confidence = confidence_softmax .* (0.5 + 0.5 * agree_score);
    else
        confidence = confidence_softmax;
    end

    %% 置信度加权聚合 C_SCORE（继承 REMO_C2RL）
    for i = 1:Next_num
        original = (i-1) * n_per_xi;

        idx_C1Xi = (original+1)               : (original+C1_num);
        idx_XiC1 = (original+1+C1_num)        : (original+C1_num*2);
        idx_C2Xi = (original+1+C1_num*2)      : (original+C1_num*2+C2_num);
        idx_XiC2 = (original+1+C2_num+C1_num*2) : (original+C2_num*2+C1_num*2);

        w_C1Xi = confidence(idx_C1Xi);
        w_XiC1 = confidence(idx_XiC1);
        w_C2Xi = confidence(idx_C2Xi);
        w_XiC2 = confidence(idx_XiC2);

        % 置信度加权平均
        pre_C1Xi = sum(pre_out(idx_C1Xi, :) .* w_C1Xi, 1) ./ (sum(w_C1Xi) + eps);
        pre_XiC1 = sum(pre_out(idx_XiC1, :) .* w_XiC1, 1) ./ (sum(w_XiC1) + eps);
        pre_C2Xi = sum(pre_out(idx_C2Xi, :) .* w_C2Xi, 1) ./ (sum(w_C2Xi) + eps);
        pre_XiC2 = sum(pre_out(idx_XiC2, :) .* w_XiC2, 1) ./ (sum(w_XiC2) + eps);

        % C_SCORE 公式（与 REMO_new2 / REMO_C2RL 兼容）
        % pre_*(1) = P(+1) = "前者优于后者"
        % pre_*(2) = P(0)
        % pre_*(3) = P(-1) = "前者劣于后者"
        C_SCORE = zeros(1, 2);

        % (C1, Xi)：理想 +1
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);

        % (Xi, C1)：理想 -1
        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);

        % (C2, Xi)：理想 -1
        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);

        % (Xi, C2)：理想 +1
        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);

        scores(i) = C_SCORE(1) - C_SCORE(2);

        % 候选解的总平均置信度
        conf_final(i) = mean([w_C1Xi; w_XiC1; w_C2Xi; w_XiC2]);
    end

    [~, ind] = sort(scores, 'descend');
end
