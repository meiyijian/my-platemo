function Next = CASurrogateSelection(Problem,Ref,Input,wmax,Smodel,divWeight)
% Generate candidates and screen them with a reliability-aware relation score.

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    used = 0;

    while used < wmax
        [rank,~] = scoreCandidates(Smodel,Next,Input,divWeight);
        keep = min(length(Ref),size(Next,1));
        InputInner = Next(rank(1:keep),:);
        Next = OperatorGA(Problem,[InputInner;Ref.decs],{1,15,1,5});
        used = used + size(Next,1);
    end

    [rank,score] = scoreCandidates(Smodel,Next,Input,divWeight);
    maxEval = min(4,size(Next,1));
    strong = find(score > 3.5*Smodel.reliability);
    if Smodel.mode ~= 0 && ~isempty(strong)
        [~,local] = sort(score(strong),'descend');
        chosen = strong(local(1:min(maxEval,numel(local))));
    else
        chosen = rank(1:maxEval);
    end
    Next = Next(chosen,:);
end

function [rank,score] = scoreCandidates(Smodel,Next,ArchiveDec,divWeight)
    relationScore = relationModelScore(Smodel,Next);
    if Smodel.mode == -1
        relationScore = -relationScore;
    elseif Smodel.mode == 0
        relationScore = zeros(size(relationScore));
    end
    relationScore = Smodel.reliability.*relationScore;

    diversityScore = decisionDiversity(Next,ArchiveDec);
    score = relationScore + divWeight.*diversityScore;
    [~,rank] = sort(score,'descend');
end

function score = relationModelScore(Smodel,Next)
    good = Smodel.anchorGood;
    bad  = Smodel.anchorBad;
    if isempty(good)
        good = Smodel.X(Smodel.Y==1,:);
    end
    if isempty(bad)
        bad = Smodel.X(Smodel.Y~=1,:);
    end

    score = zeros(size(Next,1),1);
    if ~isempty(good)
        [evidenceGood,evidenceBad] = anchorEvidence(Smodel,Next,good);
        score = score + evidenceGood - evidenceBad;
    end
    if ~isempty(bad)
        [evidenceGood,evidenceBad] = anchorEvidence(Smodel,Next,bad);
        score = score + evidenceGood - evidenceBad;
    end
end

function [evidenceGood,evidenceBad] = anchorEvidence(Smodel,Next,Anchor)
    nCand = size(Next,1);
    nAnch = size(Anchor,1);
    candIndex = repelem((1:nCand)',nAnch,1);
    anchIndex = repmat((1:nAnch)',nCand,1);

    anchorFirst = [Anchor(anchIndex,:),Next(candIndex,:)];
    candFirst   = [Next(candIndex,:),Anchor(anchIndex,:)];
    pAnchorFirst = predictPairs(Smodel,anchorFirst);
    pCandFirst   = predictPairs(Smodel,candFirst);

    goodVector = pAnchorFirst(:,2) + pAnchorFirst(:,3) + pCandFirst(:,1) + pCandFirst(:,2);
    badVector  = pAnchorFirst(:,1) + pCandFirst(:,3);

    evidenceGood = accumarray(candIndex,goodVector,[nCand,1],@mean,0);
    evidenceBad  = accumarray(candIndex,badVector,[nCand,1],@mean,0);
end

function prob = predictPairs(Smodel,PairDec)
    PairNor = mapminmax('apply',PairDec',Smodel.mp_struct)';
    prob = Smodel.net(PairNor')';
end

function score = decisionDiversity(Next,ArchiveDec)
    if isempty(ArchiveDec)
        score = zeros(size(Next,1),1);
        return;
    end
    dist = pdist2(Next,ArchiveDec);
    score = min(dist,[],2);
    if max(score) > 0
        score = score./max(score);
    end
end
