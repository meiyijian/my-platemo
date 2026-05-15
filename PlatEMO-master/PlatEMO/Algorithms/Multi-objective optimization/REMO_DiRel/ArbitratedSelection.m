function Next = ArbitratedSelection(Problem, Ref, Input, wmax, Smodel)
%ArbitratedSelection - Budgeted surrogate-assisted GA selection.

    gaParam = difficultyAwareGAParam(Smodel);
    Next = OperatorGA(Problem, [Input; Ref.decs], gaParam);
    i = 0;

    while i < wmax
        [sorted_idx, ~] = scoreAndSort(Smodel, Next);
        nKeep = min(length(Ref), size(Next, 1));
        Selected = Next(sorted_idx(1:nKeep), :);
        Next = OperatorGA(Problem, [Selected; Ref.decs], gaParam);
        i = i + size(Next, 1);
    end

    [~, scores] = scoreAndSort(Smodel, Next);
    if sum(scores > 3.9) < 4
        [~, ind] = sort(scores, 'descend');
        Next = Next(ind(1:min(4, size(Next,1))), :);
    else
        Next = Next(scores > 3.9, :);
    end
end

function [ind, scores] = scoreAndSort(Smodel, Candidates)
    scores = ArbitratorScore(Smodel, Candidates);
    [~, ind] = sort(scores, 'descend');
end

function param = difficultyAwareGAParam(Smodel)
    diff = Smodel.easyDifficulty;
    if isempty(diff) || isnan(diff)
        diff = 0.5;
    end
    diff = min(max(diff, 0), 1);

    % Larger distribution indices make SBX/mutation more local. Easy and
    % improving subsets exploit locally; hard/stagnant subsets explore more.
    disC = round(10 + 20*(1-diff));
    disM = round(5  + 20*(1-diff));
    proM = 1 + 0.5*diff;
    param = {1, disC, proM, disM};
end
