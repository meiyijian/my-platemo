function Next = DiversifiedInfillSelection(Problem,Ref,Input,wmax,Smodel,qKeep,nMax)
%DiversifiedInfillSelection Generate candidates and apply a pruned criterion.
%   Keeps the original relation-guided GA and candidate-pool accumulation.
%   Exploration uses the unchanged relation-score quantile filter, then adds a
%   constant reward on the predicted ambiguity inside the retained set:
%   A_t = R~ + 0.30*U~. The reward weight comes from
%   the fixed selector constant; no p_err gate, no minimum batch completion or second
%   indicator filter are used.
%   Batch construction (the only change from Lambdat030): the 0.25*d in-batch
%   distance term is deleted, so the batch is the descending-A_t order of the
%   retained set (see NoBatchDistWeightedBatchSelection).
%   Indicator mode uses the 30-percent relation shortlist and direct ranking.

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
    switch Smodel.mode
        case 'explore'
            ratio = Problem.FE/Problem.maxFE;
            [Next,info] = NoBatchDistWeightedBatchSelection( ...
                allCandidates,scores,uncertainty,qKeep,batchSize, ...
                ratio);
            recordNoBatchDistDiagnostics(info,Problem,nMax,size(allCandidates,1));
        case 'indicator'
            Next = PrunedIndicatorSelection( ...
                allCandidates,scores,Smodel.IndicatorModel,batchSize);
        otherwise
            error('AdaMaO:InvalidMode','Expected explore or indicator mode.');
    end
end

function recordNoBatchDistDiagnostics(info,Problem,nMax,nCandidates)
%recordNoBatchDistDiagnostics Append one exploration record to the collector.
%   The collector is a plain struct and no random number is drawn here, so it
%   cannot disturb the optimization stream.
    global ADAMAO_NOBATCHDIST_DIAG
    if ~isstruct(ADAMAO_NOBATCHDIST_DIAG) || ...
            ~isfield(ADAMAO_NOBATCHDIST_DIAG,'enabled') || ...
            ~ADAMAO_NOBATCHDIST_DIAG.enabled
        return;
    end
    info.FE = Problem.FE;
    info.nMax = nMax;
    info.nCandidates = nCandidates;
    ADAMAO_NOBATCHDIST_DIAG.iterations = ADAMAO_NOBATCHDIST_DIAG.iterations + 1;
    ADAMAO_NOBATCHDIST_DIAG.records{end+1} = info;
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
%   probability; the indicator criterion uses the arithmetic mean.
%   uncertainty returns the predicted ambiguity U = 1-mean(max(pi)) that the
%   Original criterion used, averaged over the same ordered pairs.

    model_x = Smodel.X;
    % Split the PAQC Catalog into the positive group C1 and the rest C2.
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

        % Average method depends on the active criterion.
        mode = 'conservative';
        if isfield(Smodel,'mode') && ~isempty(Smodel.mode)
            mode = Smodel.mode;
        end
        if strcmp(mode,'explore')
            % Exploration: weight each pair by its maximum class probability.
            pre_C1Xi = weighted_mean(pre_out(idx_C1Xi,:),pair_conf(idx_C1Xi));
            pre_XiC1 = weighted_mean(pre_out(idx_XiC1,:),pair_conf(idx_XiC1));
            pre_C2Xi = weighted_mean(pre_out(idx_C2Xi,:),pair_conf(idx_C2Xi));
            pre_XiC2 = weighted_mean(pre_out(idx_XiC2,:),pair_conf(idx_XiC2));
        else
            % Indicator and fallback branches: arithmetic mean.
            pre_C1Xi = mean(pre_out(idx_C1Xi,:),1);
            pre_XiC1 = mean(pre_out(idx_XiC1,:),1);
            pre_C2Xi = mean(pre_out(idx_C2Xi,:),1);
            pre_XiC2 = mean(pre_out(idx_XiC2,:),1);
        end

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
        % ordered pairs formed with both training groups, as in Original.
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
