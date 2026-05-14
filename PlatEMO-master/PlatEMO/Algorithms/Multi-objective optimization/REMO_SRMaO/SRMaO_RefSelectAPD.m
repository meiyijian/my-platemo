function Ref = SRMaO_RefSelectAPD(Population, N, ratio)
% APD environmental selection with robust normalization.

    if nargin < 3 || isempty(ratio)
        ratio = 0.5;
    end

    PopObj = Population.objs;
    [Np,M] = size(PopObj);
    if Np <= N
        Ref = Population;
        return;
    end

    [FrontNo,MaxFNo] = NDSort(PopObj,N);
    Next = FrontNo < MaxFNo;
    Last = find(FrontNo == MaxFNo);
    need = N - sum(Next);
    if need <= 0
        Ref = Population(Next);
        return;
    end

    PopObjN = robustNormalize(PopObj);
    LastObj = PopObjN(Last,:);

    [V,~] = UniformPoint(N,M);
    V = V ./ max(vecnorm(V,2,2),eps);

    cosV = 1 - pdist2(V,V,'cosine');
    cosV(logical(eye(size(cosV,1)))) = 0;
    gamma = min(acos(max(min(cosV,1),-1)),[],2);
    gamma(gamma < 1e-6) = 1e-6;

    bad = vecnorm(LastObj,2,2) < 1e-12;
    LastObj(bad,:) = 1 ./ max(1,M);
    Angle = acos(max(min(1 - pdist2(LastObj,V,'cosine'),1),-1));
    [AngMin,assoc] = min(Angle,[],2);
    NormF = sqrt(sum(LastObj.^2,2));
    APD = (1 + (0.5 + ratio)*M.*AngMin./gamma(assoc)) .* NormF;

    selected = false(length(Last),1);
    for v = unique(assoc)'
        cur = find(assoc == v);
        [~,best] = min(APD(cur));
        selected(cur(best)) = true;
    end

    if sum(selected) < need
        remain = find(~selected);
        [~,ord] = sort(APD(remain),'ascend');
        selected(remain(ord(1:need-sum(selected)))) = true;
    elseif sum(selected) > need
        chosen = find(selected);
        [~,ord] = sort(APD(chosen),'ascend');
        selected(:) = false;
        selected(chosen(ord(1:need))) = true;
    end

    Next(Last(selected)) = true;
    Ref = Population(Next);
end

function PopObjN = robustNormalize(PopObj)
    [N,M] = size(PopObj);
    z = min(PopObj,[],1);
    znad = max(PopObj,[],1);
    range0 = max(znad - z,1e-6);

    W = zeros(M) + 1e-6;
    W(logical(eye(M))) = 1;
    ASF = zeros(N,M);
    for i = 1 : M
        ASF(:,i) = max(abs((PopObj - repmat(z,N,1)) ./ repmat(range0,N,1)) ./ ...
                       repmat(W(i,:),N,1),[],2);
    end
    [~,extreme] = min(ASF,[],1);

    A = PopObj(extreme,:) - repmat(z,M,1);
    if rank(A) == M && rcond(A) > 1e-12
        hyperplane = A \ ones(M,1);
        a = (1 ./ hyperplane)' + z;
    else
        a = znad;
    end
    if any(isnan(a)) || any(isinf(a)) || any(a <= z)
        a = znad;
    end
    range = max(a - z,1e-6);
    PopObjN = (PopObj - repmat(z,N,1)) ./ repmat(range,N,1);
end
