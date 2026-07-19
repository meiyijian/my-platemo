function Next = AdaMaOSelectionFactorial( ...
    Problem,Ref,Input,wmax,Smodel,q_keep,n_min,n_max)
%AdaMaOSelectionFactorial Select candidates with reciprocal preferences.

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    allCandidates = Next;
    generated = size(Next,1);

    while generated < wmax && ~isempty(Next)
        [order,~,~] = relationScore(Smodel,Next);
        keepNumber = min(length(Ref),size(Next,1));
        if keepNumber < 1
            break;
        end
        parents = Next(order(1:keepNumber),:);
        Next = OperatorGA(Problem,[parents;Ref.decs],{1,15,1,5});
        allCandidates = [allCandidates;Next]; %#ok<AGROW>
        generated = generated + size(Next,1);
    end

    if isempty(allCandidates)
        Next = [];
        return;
    end
    allCandidates = unique(allCandidates,'rows','stable');

    switch Smodel.mode
        case 'indicator'
            Next = selectIndicator(Smodel,allCandidates,n_min,n_max);
        case 'explore'
            Next = selectExplore( ...
                Smodel,allCandidates,q_keep,n_min,n_max);
        otherwise
            error('AdaMaO:UnknownFactorialCandidateMode', ...
                'CPR supports only explore and indicator candidate modes.');
    end
end

function Next = selectExplore(Smodel,Candidates,q_keep,n_min,n_max)
    [~,scores,ambiguity] = relationScore(Smodel,Candidates);
    scoreNormalized = norm01(scores);
    ambiguityNormalized = norm01(ambiguity);

    pError = Smodel.p_err;
    if ~isscalar(pError) || ~isfinite(pError)
        pError = 1;
    end
    ambiguityWeight = Smodel.lambda0*(1-Smodel.ratio)* ...
        max(0,1-pError/0.45);
    augmented = scoreNormalized + ambiguityWeight.*ambiguityNormalized;

    threshold = quantile(augmented,q_keep);
    candidateIndex = find(augmented >= threshold);
    if numel(candidateIndex) < n_min
        [~,order] = sort(augmented,'descend');
        candidateIndex = order(1:min(n_min,numel(order)));
    end

    evaluationNumber = min(n_max,max(n_min,numel(candidateIndex)));
    evaluationNumber = min(evaluationNumber,numel(candidateIndex));
    selected = diversitySelect( ...
        Candidates,candidateIndex,augmented,evaluationNumber);
    Next = Candidates(selected,:);
end

function Next = selectIndicator(Smodel,Candidates,n_min,n_max)
    [~,relationScores] = relationScore(Smodel,Candidates);
    keepNumber = max(20,ceil(size(Candidates,1)*0.30));
    keepNumber = min(keepNumber,size(Candidates,1));
    [~,relationOrder] = sort(relationScores,'descend');
    coarseIndex = relationOrder(1:keepNumber);
    coarseSet = Candidates(coarseIndex,:);

    indicatorScores = relationScores(coarseIndex);
    if isfield(Smodel,'IndicatorModel') && ~isempty(Smodel.IndicatorModel)
        try
            prediction = predict(Smodel.IndicatorModel,coarseSet);
            if all(isfinite(prediction))
                indicatorScores = prediction;
            end
        catch
            indicatorScores = relationScores(coarseIndex);
        end
    end

    threshold = quantile(indicatorScores,0.70);
    candidateIndex = find(indicatorScores >= threshold);
    if numel(candidateIndex) < n_min
        [~,order] = sort(indicatorScores,'descend');
        candidateIndex = order(1:min(n_min,numel(order)));
    end
    [~,order] = sort(indicatorScores(candidateIndex),'descend');
    evaluationNumber = min(n_max,max(n_min,numel(candidateIndex)));
    evaluationNumber = min(evaluationNumber,numel(candidateIndex));
    selected = candidateIndex(order(1:evaluationNumber));
    Next = coarseSet(selected,:);
end

function [order,scores,ambiguity] = relationScore(Smodel,Candidates)
    [order,scores,ambiguity] = ScoreSDEFactorialCandidates( ...
        Smodel.RelationModel,Candidates,Smodel.X,Smodel.AggregationMode);
end

function selected = diversitySelect(Next,candidateIndex,scores,count)
    candidateIndex = candidateIndex(:);
    if numel(candidateIndex) <= count
        [~,order] = sort(scores(candidateIndex),'descend');
        selected = candidateIndex(order);
        return;
    end

    [~,first] = max(scores(candidateIndex));
    selected = candidateIndex(first);
    remain = candidateIndex;
    remain(first) = [];
    while numel(selected) < count && ~isempty(remain)
        distance = min(pdist2(Next(remain,:),Next(selected,:)),[],2);
        acquisition = 0.75.*norm01(scores(remain)) + ...
            0.25.*norm01(distance);
        [~,best] = max(acquisition);
        selected(end+1,1) = remain(best); %#ok<AGROW>
        remain(best) = [];
    end
end

function scaled = norm01(values)
    values = values(:);
    if isempty(values)
        scaled = values;
        return;
    end
    lower = min(values);
    upper = max(values);
    if upper-lower < 1e-12
        scaled = 0.5.*ones(size(values));
    else
        scaled = (values-lower)./(upper-lower);
    end
end
