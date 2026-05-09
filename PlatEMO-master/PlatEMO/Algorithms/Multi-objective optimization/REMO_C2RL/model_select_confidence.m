function [ind, scores, uncertainty] = model_select_confidence(Smodel, Next)
% 置信度感知关系打分（REMO_C2RL 创新点 2）
%
% 输入：
%   Smodel   : 训练好的代理模型结构体
%   Next     : N×D 候选解矩阵
%
% 输出：
%   ind         : 按 score 降序的索引
%   scores      : 每个候选解的 C_SCORE 净分数
%   uncertainty : 每个候选解的不确定性 ∈ [0, 1]
%                 = 1 - mean(softmax max prob)
%
% 设计动机：
%   patternnet 输出 softmax 分布 [P(+1), P(0), P(-1)]，max prob
%   是天然的预测置信度。低置信度对在聚合时应被弱化。
%   同时把候选解的平均不确定性返回给上层做 UCB 探索决策。
%
% 与原 model_select 的差异：
%   ① 计算每对的 confidence = max(pre_out, [], 2)
%   ② C_SCORE 聚合改为置信度加权平均（替代简单算术平均）
%   ③ 额外返回 uncertainty 数组供 UCB 使用

    model_x = Smodel.X;
    C1_data = model_x(Smodel.Y == 1, :);
    C2_data = model_x(Smodel.Y ~= 1, :);

    C1_num   = size(C1_data, 1);
    C2_num   = size(C2_data, 1);
    Next_num = size(Next, 1);

    scores      = zeros(Next_num, 1);
    uncertainty = zeros(Next_num, 1);

    % 兜底：若 C1 或 C2 为空，退化为零分零不确定性
    if C1_num == 0 || C2_num == 0
        ind = 1:Next_num;
        return;
    end

    %% 构造测试对（与原 model_select 完全一致）
    all_testdata = zeros(2*(C1_num + C2_num)*Next_num, 2*size(C1_data, 2));
    for i = 1:Next_num
        original = (i-1) * 2 * (C1_num + C2_num);
        Xi       = repmat(Next(i, :), C1_num, 1);
        all_testdata(original+1 : original+C1_num, :)            = [C1_data, Xi];   % C1Xi
        all_testdata(original+1+C1_num : original+C1_num*2, :)   = [Xi, C1_data];   % XiC1

        Xi = repmat(Next(i, :), C2_num, 1);
        all_testdata(original+1+C1_num*2 : original+C1_num*2+C2_num, :)        = [C2_data, Xi];  % C2Xi
        all_testdata(original+1+C2_num+C1_num*2 : original+C2_num*2+C1_num*2, :) = [Xi, C2_data]; % XiC2
    end

    %% 神经网络批量预测
    TestIn_nor = mapminmax('apply', all_testdata', Smodel.mp_struct)';
    pre_out    = Smodel.net(TestIn_nor')';     % size: N_pairs × 3

    %% 关键改动 ①：每对的置信度 = softmax max prob
    confidence = max(pre_out, [], 2);          % size: N_pairs × 1

    %% 关键改动 ②③：置信度加权聚合 + 计算每个候选解的 uncertainty
    for i = 1:Next_num
        original = (i-1) * 2 * (C1_num + C2_num);

        idx_C1Xi = (original+1)             : (original+C1_num);
        idx_XiC1 = (original+1+C1_num)      : (original+C1_num*2);
        idx_C2Xi = (original+1+C1_num*2)    : (original+C1_num*2+C2_num);
        idx_XiC2 = (original+1+C2_num+C1_num*2) : (original+C2_num*2+C1_num*2);

        % 每个组的置信度向量（列向量）
        w_C1Xi = confidence(idx_C1Xi);
        w_XiC1 = confidence(idx_XiC1);
        w_C2Xi = confidence(idx_C2Xi);
        w_XiC2 = confidence(idx_XiC2);

        % 置信度加权平均（替代原 sum(...)/N 简单平均）
        % 公式：weighted_mean(p) = sum(p .* w) / sum(w)
        pre_C1Xi = sum(pre_out(idx_C1Xi, :) .* w_C1Xi, 1) ./ (sum(w_C1Xi) + eps);
        pre_XiC1 = sum(pre_out(idx_XiC1, :) .* w_XiC1, 1) ./ (sum(w_XiC1) + eps);
        pre_C2Xi = sum(pre_out(idx_C2Xi, :) .* w_C2Xi, 1) ./ (sum(w_C2Xi) + eps);
        pre_XiC2 = sum(pre_out(idx_XiC2, :) .* w_XiC2, 1) ./ (sum(w_XiC2) + eps);

        %% C_SCORE 公式（保持与 REMO_new2 兼容）
        % pre_*(1) = P(+1) = "前者优于后者"
        % pre_*(2) = P(0)  = "同类"
        % pre_*(3) = P(-1) = "前者劣于后者"
        C_SCORE = zeros(1, 2);

        % (C1, Xi)：理想标签 = +1（C1 是好解，前者优于 Xi → Xi 差）
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);   % Xi 优于或同等于 C1 → Xi 好
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);                 % C1 优于 Xi → Xi 差

        % (Xi, C1)：理想标签 = -1
        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);   % Xi 优于或同等于 C1 → Xi 好
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);                 % C1 优于 Xi → Xi 差

        % (C2, Xi)：理想标签 = -1
        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);                 % C2 劣于 Xi → Xi 好
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);   % C2 优于或同等于 Xi → Xi 差

        % (Xi, C2)：理想标签 = +1
        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);                 % Xi 优于 C2 → Xi 好
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);   % C2 优于或同等于 Xi → Xi 差

        scores(i) = C_SCORE(1) - C_SCORE(2);

        %% 关键改动 ③：候选解的不确定性 = 1 - mean(置信度)
        all_w           = [w_C1Xi; w_XiC1; w_C2Xi; w_XiC2];
        uncertainty(i)  = 1 - mean(all_w);
    end

    [~, ind] = sort(scores, 'descend');
end
