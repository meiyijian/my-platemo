function Next = SubproblemSurrogateSelection(Problem, Ref, Input, wmax, classifiers, sub_weights)
% Surrogate-assisted selection using multiple subproblem classifiers.
% Ref      - reference solutions (used as benchmark for scoring)
% Input    - current population decision vectors
% wmax     - number of solutions to generate via surrogate
% classifiers - cell array of trained classifiers (each with predict method)
% sub_weights - cell array of weight vectors for each classifier (optional, for scoring)
% Output:
%   Next    - selected solutions for real evaluation

    % Generate initial offspring via GA (same as REMO)
    Next = OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5});
    i = 0;
    while i < wmax
        % Score all generated solutions using voting with reference set
        scores = score_solutions(Next, Ref, classifiers);
        % Sort by score (higher is better)
        [~, idx] = sort(scores, 'descend');
        % Select top len(Ref) as new parents
        Input = Next(idx(1:length(Ref)), :);
        % Generate new offspring
        Next = OperatorGA(Problem, [Input; Ref.decs], {1,15,1,5});
        i = i + size(Next, 1);
    end
    % Final scoring and selection
    scores = score_solutions(Next, Ref, classifiers);
    if sum(scores > 3.9) < 4
        [~, ind] = sort(scores, 'descend');
        Next = Next(ind(1:4), :);
    else
        Next = Next(scores > 3.9, :);
    end
end

function scores = score_solutions(Candidates, Ref, classifiers)
% Score each candidate by comparing it with reference solutions using all classifiers.
% Candidates: matrix of decision vectors (each row = one candidate)
% Ref: INDIVIDUAL array of reference solutions
% Returns: score for each candidate (higher is better)

    RefDec = [Ref.decs];
    n_ref = size(RefDec, 1);
    n_cand = size(Candidates, 1);
    n_cls = length(classifiers);
    
    scores = zeros(n_cand, 1);
    % For each candidate, compare with each reference
    for c = 1:n_cand
        cand = Candidates(c, :);
        for r = 1:n_ref
            % Construct two pairs: (cand, ref) and (ref, cand)
            pair1 = [cand, RefDec(r,:)];
            pair2 = [RefDec(r,:), cand];
            % Use each classifier to predict probability that first is better
            total = 0;
            for k = 1:n_cls
                prob1 = classifiers{k}.predict(pair1);
                prob2 = classifiers{k}.predict(pair2);
                % If prob1 > 0.5, classifier says cand is better than ref.
                % If prob2 > 0.5, classifier says ref is better than cand.
                % So overall score: (prob1) - (prob2)
                total = total + (prob1 - prob2);
            end
            scores(c) = scores(c) + total;
        end
    end
    % Normalize by number of reference points and classifiers (optional)
    scores = scores / (n_ref * n_cls);
end