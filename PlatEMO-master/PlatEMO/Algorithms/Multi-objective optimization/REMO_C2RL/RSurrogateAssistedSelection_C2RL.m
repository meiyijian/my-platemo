function Next = RSurrogateAssistedSelection_C2RL(Problem, Ref, Input, wmax, Smodel, q_keep)
% UCB 探索 + 分位数阈值的代理辅助选择（REMO_C2RL 创新点 3）
%
% 输入：
%   Problem  : PlatEMO 问题对象
%   Ref      : 参考解集合
%   Input    : 当前种群决策变量（N×D）
%   wmax     : GA 内循环最大尝试次数（代理评估上限）
%   Smodel   : 训练好的代理模型，含字段：
%                X, Y, mp_struct, net, p_err, stage, lambda
%   q_keep   : 末尾筛选分位数（默认 0.7）
%
% 输出：
%   Next     : 经 UCB 增广打分后选出的候选解（5~8 个）
%
% 设计动机：
%   原 REMO_new2 末尾用死阈值 `>3.9`，M=10 时关系预测噪声大，
%   往往不够 3.9 → 总是兜底回 top-4。本算法改为：
%     1. score_aug = score + lambda * uncertainty （UCB 探索）
%     2. quantile(score_aug, q_keep) 自适应阈值（替代死阈值）
%     3. lambda 由主文件控制随进化衰减（早探索后利用）

    %% Stage A：GA 内循环（关系网络驱动子代生成）
    % 这部分逻辑与 REMO_new2 原版一致，只是 model_select_confidence 替代 model_select
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
    i    = 0;
    while i < wmax
        % 在内循环中只用 score 排序（不引入 uncertainty 干扰 GA 多代演化）
        [sorted_index, ~, ~] = model_select_confidence(Smodel, Next);
        Input = Next(sorted_index(1:length(Ref)), :);
        Next  = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
        i     = i + size(Next, 1);
    end

    %% Stage B：末尾打分（含 uncertainty）
    [~, scores, uncertainty] = model_select_confidence(Smodel, Next);

    %% UCB 增广分数：score_aug = score + lambda * uncertainty
    % lambda 由主文件根据 ratio 动态计算（lambda0 * (1 - ratio)），早期大后期小
    score_aug = scores + Smodel.lambda * uncertainty;

    %% 分位数阈值替代死阈值 `>3.9`
    if length(score_aug) < 4
        % 候选数过少时直接全部返回
        return;
    end

    q          = quantile(score_aug, q_keep);
    keep_mask  = score_aug >= q;
    n_keep     = sum(keep_mask);

    if n_keep < 4
        % 兜底：高分候选不足 4 个时取 top-4
        [~, ind] = sort(score_aug, 'descend');
        Next     = Next(ind(1:4), :);
    else
        % 正常路径：在通过分位数阈值的解中，按 score_aug 取前 5~8 个
        kept             = find(keep_mask);
        [~, order]       = sort(score_aug(kept), 'descend');
        n_eval           = min(8, max(4, length(kept)));
        Next             = Next(kept(order(1:n_eval)), :);
    end
end
