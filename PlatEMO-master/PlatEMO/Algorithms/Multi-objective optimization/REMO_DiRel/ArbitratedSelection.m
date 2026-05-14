function Next = ArbitratedSelection(Problem, Ref, Input, wmax, Smodel)
% ArbitratedSelection - 模块③：仲裁器辅助选择
%
% 框架与 RSurrogateAssistedSelection 相同：用 GA 内循环累积 wmax 个候选解，
% 但内循环每步都用"双尺度仲裁评分"做候选筛选，最终用同样的仲裁评分挑出
% 送真实评估的解。
%
% 与 REMO 原版的区别：
%   model_select -> ArbitratorScore（融合 net_F、net_S，逐解逆方差权重）
%
% 输入：
%   Problem : PlatEMO 问题对象
%   Ref     : 参考解
%   Input   : N × D 当前种群决策变量
%   wmax    : GA 内循环最多累积多少候选
%   Smodel  : 含 DualNet/S_easy/Y_F/Y_S/tau_conf 等的代理模型结构体
%
% 输出：
%   Next : 选出的候选解（送真实评估）

    % ---- GA 初始子代 ----
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
    i = 0;

    while i < wmax
        [sorted_idx, ~] = scoreAndSort(Smodel, Next);
        nKeep = length(Ref);
        nKeep = min(nKeep, size(Next, 1));
        Selected = Next(sorted_idx(1:nKeep), :);
        Next = OperatorGA(Problem, [Selected; Ref.decs], {1, 15, 1, 5});
        i    = i + size(Next, 1);
    end

    % ---- 最终评分 + 阈值挑选 ----
    [~, scores] = scoreAndSort(Smodel, Next);
    if sum(scores > 3.9) < 4
        [~, ind] = sort(scores, 'descend');
        Next = Next(ind(1:min(4, size(Next,1))), :);
    else
        Next = Next(scores > 3.9, :);
    end
end

% ============================================================
function [ind, scores] = scoreAndSort(Smodel, Candidates)
% 调用 ArbitratorScore 给候选解打分，并返回排序索引
    scores = ArbitratorScore(Smodel, Candidates);
    [~, ind] = sort(scores, 'descend');
end
