function [XXs,YYs,WWs,Info] = CARelationPairs(Input,Catalog,Confidence,confRatio)
% Construct relation pairs using high-confidence samples from both classes.
% Labels:  1 means the first solution is better, 0 means similar class,
%         -1 means the second solution is better.

    goodAll = find(Catalog == 1);
    badAll  = find(Catalog ~= 1);

    goodIndex = selectHighConfidence(goodAll,Confidence,confRatio);
    badIndex  = selectHighConfidence(badAll,Confidence,confRatio);

    if isempty(goodIndex) || isempty(badIndex)
        goodIndex = goodAll;
        badIndex  = badAll;
    end

    goodDec  = Input(goodIndex,:);
    badDec   = Input(badIndex,:);
    goodConf = Confidence(goodIndex);
    badConf  = Confidence(badIndex);

    [GG,WGG] = makePairs(goodDec,goodDec,goodConf,goodConf,true);
    [BB,WBB] = makePairs(badDec,badDec,badConf,badConf,true);
    [GB,WGB] = makePairs(goodDec,badDec,goodConf,badConf,false);
    [BG,WBG] = makePairs(badDec,goodDec,badConf,goodConf,false);

    targetSame = ceil(size(GB,1)/2);
    [GG,YGG,WGG] = takeTop(GG,zeros(size(GG,1),1),WGG,targetSame);
    [BB,YBB,WBB] = takeTop(BB,zeros(size(BB,1),1),WBB,targetSame);

    XXs = [GG;BB;GB;BG];
    YYs = [YGG;YBB;ones(size(GB,1),1);-ones(size(BG,1),1)];
    WWs = [WGG;WBB;WGB;WBG];

    Info.goodIndex = goodIndex;
    Info.badIndex  = badIndex;
end

function index = selectHighConfidence(pool,Confidence,ratio)
    if isempty(pool)
        index = pool;
        return;
    end
    keep = max(2,ceil(numel(pool)*ratio));
    keep = min(keep,numel(pool));
    [~,rank] = sort(Confidence(pool),'descend');
    index = pool(rank(1:keep));
end

function [Pairs,Weights] = makePairs(A,B,WA,WB,dropSelf)
    if isempty(A) || isempty(B)
        Pairs = zeros(0,size(A,2)+size(B,2));
        Weights = zeros(0,1);
        return;
    end

    [I,J] = ndgrid(1:size(A,1),1:size(B,1));
    I = I(:);
    J = J(:);
    if dropSelf && size(A,1) == size(B,1)
        keep = I ~= J;
        I = I(keep);
        J = J(keep);
    end
    Pairs   = [A(I,:),B(J,:)];
    Weights = min(WA(I),WB(J));
end

function [X,Y,W] = takeTop(X,Y,W,K)
    if size(X,1) > K
        [~,rank] = sort(W,'descend');
        rank = rank(1:K);
        X = X(rank,:);
        Y = Y(rank,:);
        W = W(rank,:);
    end
end
