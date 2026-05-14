function Next = ArbitratedSelection_AvgArb(Problem, Ref, Input, wmax, Smodel)
% ArbitratedSelection_AvgArb - 消融变体辅助：用 0.5/0.5 简单平均仲裁
%
% 与 ArbitratedSelection 的唯一差异：评分时调用 ArbitratorScore_AvgArb

    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
    i = 0;
    while i < wmax
        scores = ArbitratorScore_AvgArb(Smodel, Next);
        [~, sorted_idx] = sort(scores, 'descend');
        nKeep = min(length(Ref), size(Next, 1));
        Selected = Next(sorted_idx(1:nKeep), :);
        Next = OperatorGA(Problem, [Selected; Ref.decs], {1, 15, 1, 5});
        i    = i + size(Next, 1);
    end
    scores = ArbitratorScore_AvgArb(Smodel, Next);
    if sum(scores > 3.9) < 4
        [~, ind] = sort(scores, 'descend');
        Next = Next(ind(1:min(4, size(Next,1))), :);
    else
        Next = Next(scores > 3.9, :);
    end
end
