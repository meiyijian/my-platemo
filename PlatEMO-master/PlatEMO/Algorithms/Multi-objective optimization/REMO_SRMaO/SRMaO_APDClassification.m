function [Catalog, Ref, info] = SRMaO_APDClassification(Population, ratio, Nref, k)
% APD/SDE binary state labelling for many-objective relation learning.
%
% Catalog is true for high-quality solutions.  The scoring combines
% RVEA-style APD, shift-based density estimation, and non-dominated rank.

    N      = length(Population);
    PopObj = Population.objs;
    [~,M]  = size(PopObj);

    [V,~] = UniformPoint(Nref,M);
    V = normalizeRows(V);

    PopObjT = PopObj - repmat(min(PopObj,[],1),N,1);
    zeroRow = vecnorm(PopObjT,2,2) < 1e-12;
    PopObjT(zeroRow,:) = 1 ./ max(M,1);

    cosV = 1 - pdist2(V,V,'cosine');
    cosV(logical(eye(size(cosV,1)))) = 0;
    gamma = min(acos(max(min(cosV,1),-1)),[],2);
    gamma(gamma < 1e-6) = 1e-6;

    Angle = acos(max(min(1 - pdist2(PopObjT,V,'cosine'),1),-1));
    [AngMin,assoc] = min(Angle,[],2);

    theta = (ratio^2) * M;
    NormF = sqrt(sum(PopObjT.^2,2));
    APD   = (1 + theta.*AngMin./gamma(assoc)) .* NormF;

    SDE = SRMaO_CalSDE(PopObj);
    [FrontNo,~] = NDSort(PopObj,N);

    apdScore   = 1 - norm01(APD);
    sdeScore   = norm01(SDE);
    frontScore = 1 - norm01(FrontNo(:));
    score      = 0.55*apdScore + 0.25*sdeScore + 0.20*frontScore;

    [~,idx]  = sort(score,'descend');
    goodNum  = max(1,ceil(N/4));
    Catalog  = false(N,1);
    Catalog(idx(1:goodNum)) = true;

    k   = min(k,N);
    Ref = Population(idx(1:k));

    margin = abs(score - median(score));
    info = struct();
    info.score      = score;
    info.confidence = 0.50 + 0.50*norm01(margin);
    info.apd        = APD;
    info.sde        = SDE;
    info.frontNo    = FrontNo(:);
    info.assoc      = assoc;
    info.refDirs    = V;
end

function X = normalizeRows(X)
    n = vecnorm(X,2,2);
    bad = n < 1e-12;
    if any(bad)
        X(bad,:) = 1 ./ max(1,size(X,2));
        n = vecnorm(X,2,2);
    end
    X = X ./ max(n,eps);
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
