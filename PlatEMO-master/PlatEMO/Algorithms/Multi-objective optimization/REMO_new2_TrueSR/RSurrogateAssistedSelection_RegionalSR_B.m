function Next = RSurrogateAssistedSelection_RegionalSR_B(Problem,Ref,Input,wmax,Smodel)
% Route B surrogate selection: ensemble of local regional soft-ranking models.

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;
    while i < wmax
        [sortedIndex,~] = model_select_regional_b(Smodel,Next);
        keepNum = min(length(Ref),size(Next,1));
        Input   = Next(sortedIndex(1:keepNum),:);
        Next    = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i       = i + size(Next,1);
    end

    [~,scores,bestRegion] = model_select_regional_b(Smodel,Next);
    Next = SelectTopByRegion_RegionalSR(Next,scores,bestRegion,min(4,size(Next,1)));
end

function [ind,scores,bestRegion] = model_select_regional_b(Smodel,Next)
    modelX  = Smodel.X;
    Models  = Smodel.Models;
    nextNum = size(Next,1);

    regionScores = -inf(nextNum,numel(Models));
    modelRegions = zeros(1,numel(Models));

    for m = 1:numel(Models)
        anchorIndex = Models(m).anchorIndex(:);
        if isempty(anchorIndex)
            continue;
        end
        anchors   = modelX(anchorIndex,:);
        anchorNum = size(anchors,1);
        nextBlock = repelem(Next,anchorNum,1);
        ancBlock  = repmat(anchors,nextNum,1);

        forwardPairs = [nextBlock,ancBlock];
        reversePairs = [ancBlock,nextBlock];
        testPairs    = [forwardPairs;reversePairs];

        testPairsNor = mapminmax('apply',testPairs',Models(m).mp_struct)';
        prob = Models(m).net(testPairsNor')';
        prob = min(max(prob(:),0),1);

        pairNum     = nextNum * anchorNum;
        probForward = reshape(prob(1:pairNum),anchorNum,nextNum)';
        probReverse = reshape(prob(pairNum+1:end),anchorNum,nextNum)';
        pairScore   = 0.5 .* (probForward + 1 - probReverse);
        regionScores(:,m) = mean(pairScore,2);
        modelRegions(m) = Models(m).region;
    end

    [scores,bestIdx] = max(regionScores,[],2);
    scores(~isfinite(scores)) = 0;
    bestRegion = modelRegions(bestIdx)';
    [~,ind] = sort(scores,'descend');
end
