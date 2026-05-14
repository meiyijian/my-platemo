function Next = RSurrogateAssistedSelection_RegionalSR_A(Problem,Ref,Input,wmax,Smodel)
% Route A surrogate selection: one context-aware soft ranking model.

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;
    while i < wmax
        [sortedIndex,~] = model_select_regional_a(Smodel,Next);
        keepNum = min(length(Ref),size(Next,1));
        Input   = Next(sortedIndex(1:keepNum),:);
        Next    = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i       = i + size(Next,1);
    end

    [~,scores,bestRegion] = model_select_regional_a(Smodel,Next);
    Next = SelectTopByRegion_RegionalSR(Next,scores,bestRegion,min(4,size(Next,1)));
end

function [ind,scores,bestRegion] = model_select_regional_a(Smodel,Next)
    modelX        = Smodel.X;
    W             = Smodel.W;
    Info          = Smodel.Info;
    activeRegions = Smodel.activeRegions(:)';
    net           = Smodel.net;
    nextNum       = size(Next,1);

    if isempty(activeRegions)
        activeRegions = unique(Info.region(:))';
    end

    regionScores = -inf(nextNum,numel(activeRegions));
    for rr = 1:numel(activeRegions)
        r = activeRegions(rr);
        pool = ExpandRegionPool_RegionalSR(Info.region,W,r,Smodel.neighborNum,2);
        anchorIndex = SelectAnchorsForRegion_RegionalSR(Info.localScoreMatrix(:,r),pool,Smodel.anchorNum);
        if isempty(anchorIndex)
            continue;
        end

        anchors   = modelX(anchorIndex,:);
        anchorNum = size(anchors,1);
        nextBlock = repelem(Next,anchorNum,1);
        ancBlock  = repmat(anchors,nextNum,1);
        context   = repmat(W(r,:),nextNum*anchorNum,1);

        forwardPairs = [nextBlock,ancBlock,context];
        reversePairs = [ancBlock,nextBlock,context];
        testPairs    = [forwardPairs;reversePairs];

        testPairsNor = mapminmax('apply',testPairs',Smodel.mp_struct)';
        prob = net(testPairsNor')';
        prob = min(max(prob(:),0),1);

        pairNum     = nextNum * anchorNum;
        probForward = reshape(prob(1:pairNum),anchorNum,nextNum)';
        probReverse = reshape(prob(pairNum+1:end),anchorNum,nextNum)';
        pairScore   = 0.5 .* (probForward + 1 - probReverse);
        regionScores(:,rr) = mean(pairScore,2);
    end

    [scores,bestIdx] = max(regionScores,[],2);
    scores(~isfinite(scores)) = 0;
    bestRegion = activeRegions(bestIdx)';
    [~,ind] = sort(scores,'descend');
end
