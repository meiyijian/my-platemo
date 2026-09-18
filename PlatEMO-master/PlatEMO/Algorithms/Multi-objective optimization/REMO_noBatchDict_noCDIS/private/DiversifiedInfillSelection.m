function Next = DiversifiedInfillSelection(Problem,Ref,Input,wmax,Smodel,qKeep,nMax)
%DiversifiedInfillSelection Explore-only candidate selection (CDIS removed).
%   Keeps the original relation-guided GA and candidate-pool accumulation.
%   The indicator criterion and the explore/indicator mode switch of CDIS are
%   removed, so every round uses the exploration criterion: the qKeep
%   relation-score quantile filter plus the constant ambiguity reward
%   A_t = R~ + 0.30*U~ inside the retained set. Batch construction uses
%   NoBatchDistWeightedBatchSelection, so the batch is the descending-A_t
%   order of the retained set and no in-batch distance term is computed.

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    allCandidates = Next;
    generated = size(Next,1);
    while generated < wmax && ~isempty(Next)
        [order,~,~] = model_select(Smodel,Next);
        keepNum = min(length(Ref),size(Next,1));
        if keepNum < 1
            break;
        end
        Input = Next(order(1:keepNum),:);
        Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        allCandidates = [allCandidates;Next]; %#ok<AGROW>
        generated = generated + size(Next,1);
    end
    allCandidates = unique(allCandidates,'rows','stable');
    if isempty(allCandidates)
        Next = allCandidates;
        return;
    end
    [~,scores,uncertainty] = model_select(Smodel,allCandidates);
    batchSize = min(nMax,max(0,floor(Problem.maxFE - Problem.FE)));
    ratio = Problem.FE/Problem.maxFE;
    Next = NoBatchDistWeightedBatchSelection( ...
        allCandidates,scores,uncertainty,qKeep,batchSize,ratio);
end

function [ind,scores,uncertainty] = model_select(Smodel,Next)
%model_select Summarize ordered-pair probabilities into R and ambiguity U.
%   Every candidate Xi is compared with the positive group C1 and the
%   non-positive group C2 in four ordered forms:
%   [C1,Xi], [Xi,C1], [C2,Xi], [Xi,C2].
%   The network outputs [+1,0,-1]: the first member belongs to a higher group,
%   to the same group, or to a lower group. The four averaged probabilities are
%   the paper's a, b, c, d and the relation score is
%   R(Xi) = 2*(c(-1)+d(+1)-a(+1)-b(-1)).
%
%   The exploration criterion weights each pair by its maximum class
%   probability; uncertainty returns the predicted ambiguity
%   U = 1-mean(max(pi)) averaged over the same ordered pairs.

    model_x = Smodel.X;
    % Split the Catalog into the positive group C1 and the rest C2.
    C1_data = model_x(Smodel.Y == 1,:);
    C2_data = model_x(Smodel.Y ~= 1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);
    scores      = zeros(Next_num,1);
    uncertainty = ones(Next_num,1);

    % Any empty training group or candidate set returns the initial scores.
    if C1_num == 0 || C2_num == 0 || Next_num == 0
        ind = (1:Next_num)';
        return;
    end

    % Number of test pairs generated per candidate.
    nPairPerSol = 2*(C1_num+C2_num);
    all_testdata = zeros(nPairPerSol*Next_num,2*size(C1_data,2));

    % Build the four pair classes for every candidate.
    for i = 1:Next_num
        original = (i-1)*nPairPerSol;

        % [C1, Xi] and [Xi, C1]
        Xi = repmat(Next(i,:),C1_num,1);
        all_testdata(original+1:original+C1_num,:) = [C1_data,Xi];
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi,C1_data];

        % [C2, Xi] and [Xi, C2]
        Xi = repmat(Next(i,:),C2_num,1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:) = [C2_data,Xi];
        all_testdata(original+1+C1_num*2+C2_num:original+nPairPerSol,:) = [Xi,C2_data];
    end

    % Predict every test pair with the relation network.
    TestIn_nor = mapminmax('apply',all_testdata',Smodel.mp_struct)';
    pre_out = Smodel.net(TestIn_nor')';
    % pair_conf is the maximum predicted class probability of each pair.
    pair_conf = max(pre_out,[],2);

    % Aggregate each candidate's relation score and predicted ambiguity.
    for i = 1:Next_num
        original = (i-1)*nPairPerSol;

        % Index ranges of the four ordered pair classes.
        idx_C1Xi = original+1 : original+C1_num;
        idx_XiC1 = original+C1_num+1 : original+C1_num*2;
        idx_C2Xi = original+C1_num*2+1 : original+C1_num*2+C2_num;
        idx_XiC2 = original+C1_num*2+C2_num+1 : original+nPairPerSol;

        % Exploration: weight each pair by its maximum class probability.
        pre_C1Xi = weighted_mean(pre_out(idx_C1Xi,:),pair_conf(idx_C1Xi));
        pre_XiC1 = weighted_mean(pre_out(idx_XiC1,:),pair_conf(idx_XiC1));
        pre_C2Xi = weighted_mean(pre_out(idx_C2Xi,:),pair_conf(idx_C2Xi));
        pre_XiC2 = weighted_mean(pre_out(idx_XiC2,:),pair_conf(idx_XiC2));

        % Accumulate the pairwise comparisons.
        C_SCORE = zeros(1,2);
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);

        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);

        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);

        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);

        % Relation score R against the positive and non-positive groups.
        scores(i) = C_SCORE(1) - C_SCORE(2);
        % Predicted ambiguity = 1 - mean maximum class probability over all
        % ordered pairs formed with both training groups.
        uncertainty(i) = 1 - mean(pair_conf([idx_C1Xi,idx_XiC1,idx_C2Xi,idx_XiC2]));
    end

    % Descending relation score order.
    [~,ind] = sort(scores,'descend');
end

%% ============ softmax sharpness weighted mean ============
function y = weighted_mean(x,w)
%weighted_mean Averages predicted probabilities weighted by pair confidence.

    w = w(:);
    y = sum(x.*w,1)./(sum(w) + eps);
end
