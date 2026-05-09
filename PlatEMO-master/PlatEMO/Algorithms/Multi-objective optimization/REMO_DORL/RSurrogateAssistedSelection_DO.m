function Next = RSurrogateAssistedSelection_DO(Problem, Ref, Input, wmax, Smodel)
% 决策-目标联合关系学习的代理辅助选择
%
% 输入：
%   Problem : PlatEMO 问题对象
%   Ref     : 参考解集合（HybridPBI_Classification 输出）
%   Input   : 当前种群决策变量（N×D）
%   wmax    : GA 内循环最大尝试次数（代理评估上限）
%   Smodel  : 训练好的代理模型，含字段：
%               X, F, Y, mp_struct, net, p_err, stage, LOS, use_LOS, use_ORC
%
% 输出：
%   Next : 经 DO 关系网络打分选出的候选解（4~8 个）
%
% 流程（与 REMO_C2RL 类似但调用 model_select_DO）：
%   Stage A: GA 内循环（关系网络驱动子代生成，仅用 score 排序）
%   Stage B: 末尾打分 + 分位数阈值筛选

    %% Stage A：GA 内循环
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
    i    = 0;
    while i < wmax
        % 内循环只用 score 排序（不引入 confidence 干扰 GA 多代演化）
        [sorted_index, ~, ~] = model_select_DO(Smodel, Next);
        Input = Next(sorted_index(1:length(Ref)), :);
        Next  = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
        i     = i + size(Next, 1);
    end

    %% Stage B：末尾打分（含 ORC 一致性置信度）
    [~, scores, ~] = model_select_DO(Smodel, Next);

    %% 分位数阈值（替代原 REMO_new2 的死阈值 >3.9）
    %  q_keep = 0.7 表示保留 score 在 70 分位以上的候选
    q_keep = 0.7;

    if length(scores) < 4
        return;
    end

    q          = quantile(scores, q_keep);
    keep_mask  = scores >= q;
    n_keep     = sum(keep_mask);

    if n_keep < 4
        % 兜底：高分候选不足 4 时取 top-4
        [~, ind] = sort(scores, 'descend');
        Next     = Next(ind(1:4), :);
    else
        % 正常路径：在通过分位数阈值的解中按 score 取前 4~8
        kept       = find(keep_mask);
        [~, order] = sort(scores(kept), 'descend');
        n_eval     = min(8, max(4, length(kept)));
        Next       = Next(kept(order(1:n_eval)), :);
    end
end
