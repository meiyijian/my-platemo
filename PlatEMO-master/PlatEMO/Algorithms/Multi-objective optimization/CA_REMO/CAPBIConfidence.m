function [Catalog,Confidence,Margin,GValue] = CAPBIConfidence(PopObj,RefObj)
% Estimate REMO-style PBI labels and the confidence of each label.
% Catalog is true for the reference-side class and false otherwise.
% Confidence is based on the distance to the PBI decision boundary g=1.

    target = 0.5;
    lower  = -20;
    upper  = 20;

    for iter = 1 : 40
        delta = (lower + upper)/2;
        [Catalog,rate,GValue] = splitByPBI(PopObj,RefObj,delta);
        if abs(rate-target) <= 0.02 || abs(upper-lower) < 1e-3
            break;
        elseif rate > target
            lower = delta;
        else
            upper = delta;
        end
    end

    Margin = abs(1-GValue);
    sortedMargin = sort(Margin(:));
    scaleIndex   = max(1,ceil(0.75*numel(sortedMargin)));
    scale        = sortedMargin(scaleIndex);
    Confidence   = min(1,Margin./(scale+eps));
    Confidence   = max(Confidence,0.01);
end

function [Catalog,rate,GValue] = splitByPBI(PopObj,RefObj,delta)
    N       = size(PopObj,1);
    Catalog = true(N,1);
    GValue  = inf(N,1);

    [~,refIndex] = max(1-pdist2(PopObj,RefObj,'cosine'),[],2);
    Z = min(PopObj,[],1);

    for i = 1 : size(RefObj,1)
        subIndex = find(refIndex==i);
        if isempty(subIndex)
            continue;
        end

        subPop = PopObj(subIndex,:);
        bound  = RefObj(i,:);
        W      = bound - Z;
        normW  = sqrt(sum(W.^2,2)) + eps;
        W      = W./normW;

        shifted = subPop - repmat(Z,size(subPop,1),1);
        normP   = sqrt(sum(shifted.^2,2)) + eps;
        normR   = sqrt(sum((bound-Z).^2,2)) + eps;
        cosineP = sum(shifted.*repmat(W,size(subPop,1),1),2)./normP;
        cosineP = max(min(cosineP,1-1e-12),-1+1e-12);

        g = normP.*cosineP + delta.*normP.*sqrt(max(0,1-cosineP.^2));
        g = g./normR;

        GValue(subIndex) = g;
        Catalog(subIndex(g>1)) = false;
    end

    rate = sum(Catalog)./max(1,numel(Catalog));
end
