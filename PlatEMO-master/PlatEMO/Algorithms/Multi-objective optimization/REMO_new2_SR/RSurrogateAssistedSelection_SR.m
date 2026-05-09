function Next = RSurrogateAssistedSelection_SR(Problem, Ref, Input, wmax, Smodel)
    Next = OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5});
    i = 0;
    while i < wmax
        [sorted_index, ~] = model_select_SR(Smodel, Next);
        Input = Next(sorted_index(1:length(Ref)), :);
        Next  = OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5});
        i     = i + size(Next, 1);
    end
    
    [~, scores] = model_select_SR(Smodel, Next);
    [~, idx_sorted] = sort(scores, 'descend');
    Next = Next(idx_sorted(1:min(4, size(Next,1))), :);
end

function [ind, scores] = model_select_SR(Smodel, Next)
    Input = Smodel.X;
    Fitness = Smodel.fitness;
    net = Smodel.net;

    K = min(5, length(Fitness));
    [~, anchor_idx] = sort(Fitness, 'descend');
    anchors = Input(anchor_idx(1:K), :);
    
    Nnext = size(Next, 1);
    scores = zeros(Nnext, 1);
    for i = 1:Nnext
        xi = Next(i, :);
        prob_sum = 0;
        for a = 1:K
            pair = [xi, anchors(a, :)];
            p = net(pair');
            prob_sum = prob_sum + p;
        end
        scores(i) = prob_sum / K;
    end
    [~, ind] = sort(scores, 'descend');
end