function Next = RSurrogateAssistedSelection_SR(Problem, Ref, Input, wmax, Smodel)
% 基于软关系评分的代理辅助选择

    Next = OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5});
    i = 0;
    while i < wmax
        [sorted_index, ~] = model_select_SR(Smodel, Next);
        Input = Next(sorted_index(1:length(Ref)), :);
        Next  = OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5});
        i     = i + size(Next, 1);
    end
    
    [~, scores] = model_select_SR(Smodel, Next);
    % 选取得分最高的一些解进行真实评估
    [~, idx_sorted] = sort(scores, 'descend');
    Next = Next(idx_sorted(1:min(4, size(Next,1))), :);
end

function [ind, scores] = model_select_SR(Smodel, Next)
% 基于锚点解的软关系评分
% 锚点：当前种群中R2适应度最高的几个解
    Input = Smodel.X;
    Fitness = Smodel.fitness;
    net = Smodel.net;

    % 选取锚点（适应度前K个）
    K = min(5, length(Fitness));
    [~, anchor_idx] = sort(Fitness, 'descend');
    anchors = Input(anchor_idx(1:K), :);
    
    Nnext = size(Next, 1);
    scores = zeros(Nnext, 1);
    
    for i = 1:Nnext
        xi = Next(i, :);
        prob_sum = 0;
        for a = 1:K
            xa = anchors(a, :);
            % 构造配对特征：候选解在前，锚点在后
            pair = [xi, xa];
            % 网络预测P(候选解优于锚点)
            p = net(pair');
            prob_sum = prob_sum + p;
        end
        scores(i) = prob_sum / K;   % 平均优于锚点的概率
    end
    
    [~, ind] = sort(scores, 'descend');
end