function[dominate, NormP, Theta] = CalSDR(PopObj)
% CalSDR - Calculate Strengthened Dominance Relation (SDR)
% Copyright (c) 2025 BIMK Group.

    N = size(PopObj, 1);
    if N <= 1
        dominate = false(N);
        NormP = sum(PopObj, 2);
        Theta = ones(N);
        return;
    end
    
    zmax = max(PopObj, [], 1);
    zmin = min(PopObj,[], 1);
    range = zmax - zmin;
    range(range == 0) = 1;
    PopObj = (PopObj - repmat(zmin, N, 1)) ./ repmat(range, N, 1);
    
    % [核心修复]: 防止出现全0向量导致 pdist2 计算 cosine 产生 NaN
    PopObj = max(PopObj, 1e-6); 
    
    NormP = sum(PopObj, 2);
    
    cosine = 1 - pdist2(PopObj, PopObj, 'cosine');
    cosine(cosine > 1) = 1;
    cosine(cosine < -1) = -1;
    cosine(logical(eye(length(cosine)))) = 0;
    Angle = acos(cosine);
    
    temp = sort(unique(min(Angle,[], 2)));
    if length(temp) >= ceil(N/2)
        minA = temp(ceil(N/2));
    else
        minA = temp(end);
    end
    if minA == 0
        minA = 1e-6;
    end
    
    Theta = max(1, (Angle ./ minA));
    
    dominate = false(N);
    for i = 1 : N-1
        for j = i+1 : N
            if NormP(i) * Theta(i, j) < NormP(j) - 1e-10
                dominate(i, j) = true;
            elseif NormP(j) * Theta(j, i) < NormP(i) - 1e-10
                dominate(j, i) = true;
            end
        end
    end
end