function Next = ArbitratedSelection_FullArb(Problem, Ref, Input, wmax, Smodel)
% ArbitratedSelection_FullArb - 消融变体辅助：全局 stateWeights 仲裁
%
% 模仿 SRMaO 的"每代一个全局权重"思路：把整批候选解 sigma_F / sigma_S 的均值作为
% 全局不确定性，据此算一个对所有候选共享的 w_F、w_S，再做加权融合。
%
% 与 ArbitratedSelection 的差异：评分调用 ArbitratorScore_FullArb

    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});
    i = 0;
    while i < wmax
        scores = ArbitratorScore_FullArb(Smodel, Next);
        [~, sorted_idx] = sort(scores, 'descend');
        nKeep = min(length(Ref), size(Next, 1));
        Selected = Next(sorted_idx(1:nKeep), :);
        Next = OperatorGA(Problem, [Selected; Ref.decs], {1, 15, 1, 5});
        i    = i + size(Next, 1);
    end
    scores = ArbitratorScore_FullArb(Smodel, Next);
    if sum(scores > 3.9) < 4
        [~, ind] = sort(scores, 'descend');
        Next = Next(ind(1:min(4, size(Next,1))), :);
    else
        Next = Next(scores > 3.9, :);
    end
end
