function Next = SRMaOSelection(Problem, Ref, Input, wmax, Smodel, qKeep, nMin, nMax)
% Unified state-aware acquisition for expensive evaluations.

    if nargin < 6 || isempty(qKeep)
        qKeep = 0.80;
    end
    if nargin < 7 || isempty(nMin)
        nMin = 5;
    end
    if nargin < 8 || isempty(nMax)
        nMax = 8;
    end

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    allCandidates = Next;
    used = size(Next,1);

    while used < wmax && ~isempty(Next)
        [~,acq] = scoreCandidates(Smodel,Next);
        [~,order] = sort(acq,'descend');
        keepNum = min([length(Ref),size(Next,1),numel(order)]);
        if keepNum < 1
            break;
        end
        parent = Next(order(1:keepNum),:);
        Next = OperatorGA(Problem,[parent;Ref.decs],{1,15,1,5});
        allCandidates = [allCandidates;Next];
        used = used + size(Next,1);
    end

    if isempty(allCandidates)
        Next = [];
        return;
    end
    allCandidates = unique(allCandidates,'rows','stable');

    [~,acq,parts] = scoreCandidates(Smodel,allCandidates);
    if isempty(acq)
        Next = [];
        return;
    end

    threshold = quantile(acq,qKeep);
    candIdx = find(acq >= threshold);
    if numel(candIdx) < nMin
        [~,order] = sort(acq,'descend');
        candIdx = order(1:min(nMin,numel(order)));
    end

    nEval = min(nMax,max(nMin,numel(candIdx)));
    nEval = min(nEval,numel(candIdx));
    selected = diversitySelect(allCandidates,candIdx,acq,parts.coverage,nEval);
    Next = allCandidates(selected,:);
end

function [order,acq,parts] = scoreCandidates(Smodel,Candidates)
    if isempty(Candidates)
        order = [];
        acq = [];
        parts = struct();
        return;
    end

    [rel,entropy,variance] = relationScore(Smodel,Candidates);
    coverage  = coverageGain(Smodel,Candidates);
    indicator = indicatorGain(Smodel,Candidates);

    relN = norm01(rel);
    entN = norm01(entropy);
    varN = norm01(variance);
    uncN = 0.55*entN + 0.45*varN;
    covN = norm01(coverage);
    indN = norm01(indicator);

    w = Smodel.stateWeights;
    acq = w.relation.*relN + ...
          w.uncertainty.*uncN + ...
          w.coverage.*covN + ...
          w.indicator.*indN;

    parts = struct('relation',relN,'entropy',entN,'variance',varN, ...
                   'uncertainty',uncN,'coverage',covN,'indicator',indN);
    [~,order] = sort(acq,'descend');
end

function [scores,entropy,variance] = relationScore(Smodel,Next)
% Ensemble preference score against good and bad labelled samples.

    modelX = Smodel.X;
    C1 = modelX(Smodel.Y == 1,:);
    C2 = modelX(Smodel.Y == 0,:);
    nC1 = size(C1,1);
    nC2 = size(C2,1);
    nN  = size(Next,1);
    D   = size(modelX,2);

    scores   = zeros(nN,1);
    entropy  = ones(nN,1);
    variance = ones(nN,1);

    if nC1 == 0 || nC2 == 0 || nN == 0
        return;
    end

    pairPerSol = 2*(nC1+nC2);
    testData = zeros(pairPerSol*nN,2*D);
    for i = 1 : nN
        base = (i-1)*pairPerSol;

        Xi = repmat(Next(i,:),nC1,1);
        testData(base+1:base+nC1,:) = [C1,Xi];
        testData(base+nC1+1:base+2*nC1,:) = [Xi,C1];

        Xi = repmat(Next(i,:),nC2,1);
        testData(base+2*nC1+1:base+2*nC1+nC2,:) = [C2,Xi];
        testData(base+2*nC1+nC2+1:base+pairPerSol,:) = [Xi,C2];
    end

    testNor = mapminmax('apply',testData',Smodel.mp_struct)';
    K = length(Smodel.nets);
    out = zeros(size(testNor,1),2,K);
    for k = 1 : K
        out(:,:,k) = Smodel.nets{k}(testNor')';
    end
    outMean = mean(out,3);
    outStd  = std(out,0,3);
    outMean = max(outMean,eps);
    outMean = outMean ./ repmat(sum(outMean,2),1,2);

    pairEntropy = -sum(outMean.*log(outMean),2) ./ log(2);
    pairVar     = mean(outStd,2);

    for i = 1 : nN
        base = (i-1)*pairPerSol;
        idxC1Xi = base+1 : base+nC1;
        idxXiC1 = base+nC1+1 : base+2*nC1;
        idxC2Xi = base+2*nC1+1 : base+2*nC1+nC2;
        idxXiC2 = base+2*nC1+nC2+1 : base+pairPerSol;

        p = outMean(idxC1Xi,:);
        sC1Xi = mean(p(:,2) - p(:,1));
        p = outMean(idxXiC1,:);
        sXiC1 = mean(p(:,1) - p(:,2));
        p = outMean(idxC2Xi,:);
        sC2Xi = mean(p(:,2) - p(:,1));
        p = outMean(idxXiC2,:);
        sXiC2 = mean(p(:,1) - p(:,2));

        scores(i) = sC1Xi + sXiC1 + sC2Xi + sXiC2;
        idx = base+1 : base+pairPerSol;
        entropy(i)  = mean(pairEntropy(idx));
        variance(i) = mean(pairVar(idx));
    end
end

function gain = coverageGain(Smodel,Candidates)
% Decision-space proxy for filling sparse reference-vector niches.

    X = Smodel.X;
    n = size(Candidates,1);
    gain = zeros(n,1);
    if isempty(X) || n == 0
        return;
    end

    dist = pdist2(Candidates,X);
    [nearestDist,nearestIdx] = min(dist,[],2);
    novelty = norm01(nearestDist);

    nicheSparse = zeros(size(Smodel.refDirs,1),1);
    if isfield(Smodel,'popObj') && ~isempty(Smodel.popObj)
        Obj = Smodel.popObj;
        Obj = Obj - repmat(min(Obj,[],1),size(Obj,1),1);
        bad = vecnorm(Obj,2,2) < 1e-12;
        Obj(bad,:) = 1 ./ max(1,size(Obj,2));
        dir = Obj ./ max(vecnorm(Obj,2,2),eps);
        angle = acos(max(min(1 - pdist2(dir,Smodel.refDirs,'cosine'),1),-1));
        [~,assoc] = min(angle,[],2);
        count = accumarray(assoc,1,[size(Smodel.refDirs,1),1],@sum,0);
        nicheSparse = 1 ./ (1 + count);
        nicheSparse = norm01(nicheSparse);
    end

    if any(nicheSparse)
        Obj = Smodel.popObj;
        Obj = Obj - repmat(min(Obj,[],1),size(Obj,1),1);
        bad = vecnorm(Obj,2,2) < 1e-12;
        Obj(bad,:) = 1 ./ max(1,size(Obj,2));
        dir = Obj ./ max(vecnorm(Obj,2,2),eps);
        angle = acos(max(min(1 - pdist2(dir,Smodel.refDirs,'cosine'),1),-1));
        [~,assoc] = min(angle,[],2);
        sparseByNearest = nicheSparse(assoc(nearestIdx));
    else
        sparseByNearest = zeros(n,1);
    end

    gain = 0.55*novelty + 0.45*sparseByNearest;
end

function gain = indicatorGain(Smodel,Candidates)
% kNN proxy of APD/SDE indicator quality in the decision space.

    X = Smodel.X;
    y = Smodel.classScore(:);
    n = size(Candidates,1);
    gain = zeros(n,1);
    if isempty(X) || isempty(y) || n == 0
        return;
    end

    dist = pdist2(Candidates,X);
    k = min(5,size(X,1));
    [sd,idx] = sort(dist,2,'ascend');
    idx = idx(:,1:k);
    sd  = sd(:,1:k);
    w = 1 ./ (sd + 1e-9);
    w = w ./ repmat(sum(w,2),1,k);
    vals = y(idx);
    gain = sum(vals.*w,2);
end

function selected = diversitySelect(Candidates,candIdx,acq,coverage,nEval)
    candIdx = candIdx(:);
    if numel(candIdx) <= nEval
        [~,order] = sort(acq(candIdx),'descend');
        selected = candIdx(order);
        return;
    end

    [~,first] = max(acq(candIdx));
    selected = candIdx(first);
    remain = candIdx;
    remain(first) = [];

    while numel(selected) < nEval && ~isempty(remain)
        d = min(pdist2(Candidates(remain,:),Candidates(selected,:)),[],2);
        local = 0.65*norm01(acq(remain)) + ...
                0.20*norm01(d) + ...
                0.15*norm01(coverage(remain));
        [~,best] = max(local);
        selected(end+1,1) = remain(best);
        remain(best) = [];
    end
end

function s = norm01(x)
    x = x(:);
    if isempty(x)
        s = x;
        return;
    end
    a = min(x);
    b = max(x);
    if b - a < 1e-12
        s = ones(size(x))*0.5;
    else
        s = (x - a) ./ (b - a);
    end
end
