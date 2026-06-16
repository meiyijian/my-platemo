function [Next, SelectInfo] = ArbitratedSelection_LKC(Problem, Ref, Input, wmax, Smodel)
% ArbitratedSelection_LKC - GA candidate generation with LKC arbitration.

    gaParam = difficultyAwareGAParam(Smodel);
    Next = OperatorGA(Problem, [Input; Ref.decs], gaParam);
    SelectInfo = struct();

    i = 0;
    while i < wmax
        [sorted_idx, ~] = scoreAndSort(Smodel, Next);
        nKeep = min(length(Ref), size(Next, 1));
        if nKeep <= 0
            break;
        end
        Selected = Next(sorted_idx(1:nKeep), :);
        Next = OperatorGA(Problem, [Selected; Ref.decs], gaParam);
        i = i + size(Next, 1);
    end

    [~, scores, SelectInfo] = scoreAndSort(Smodel, Next);
    threshold = getField(Smodel, 'scoreThreshold', 3.4);
    if sum(scores > threshold) < 4
        [~, ind] = sort(scores, 'descend');
        Next = Next(ind(1:min(4, size(Next, 1))), :);
    else
        Next = Next(scores > threshold, :);
    end
end


function [ind, scores, info] = scoreAndSort(Smodel, Candidates)
    [scores, info] = ArbitratorScore_LKC(Smodel, Candidates);
    [~, ind] = sort(scores, 'descend');
end


function param = difficultyAwareGAParam(Smodel)
    diff = Smodel.easyDifficulty;
    if isempty(diff) || isnan(diff)
        diff = 0.5;
    end
    diff = min(max(diff, 0), 1);
    disC = round(10 + 20 * (1 - diff));
    disM = round(5 + 20 * (1 - diff));
    proM = 1 + 0.5 * diff;
    param = {1, disC, proM, disM};
end


function value = getField(S, name, defaultValue)
    if isstruct(S) && isfield(S, name) && ~isempty(S.(name))
        value = S.(name);
    else
        value = defaultValue;
    end
end
