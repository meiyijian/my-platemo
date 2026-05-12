function [XXs,Ps,PairIndex] = GetRegionSoftPairs_RegionalSR(Input,Score,pool,varargin)
% Build ordered soft-ranking pairs inside a region or its neighborhood.

    alpha    = get_option(varargin,'Alpha',6);
    maxPairs = get_option(varargin,'MaxPairs',inf);
    minGap   = get_option(varargin,'MinGap',0);
    context  = get_option(varargin,'Context',[]);

    pool = pool(:);
    if numel(pool) < 2
        XXs = [];
        Ps = [];
        PairIndex = [];
        return;
    end

    s = Score(pool);
    sMin = min(s);
    sMax = max(s);
    if sMax > sMin
        s = (s - sMin) ./ (sMax - sMin);
    else
        s = 0.5 .* ones(size(s));
    end

    n = numel(pool);
    [I,J] = find(~eye(n));
    gap = abs(s(I)-s(J));
    keep = gap >= minGap;
    I = I(keep);
    J = J(keep);

    pairNum = numel(I);
    if isfinite(maxPairs) && pairNum > maxPairs
        choose = randperm(pairNum,maxPairs);
        I = I(choose);
        J = J(choose);
    end

    idxI = pool(I);
    idxJ = pool(J);
    delta = s(I) - s(J);
    Ps = 1 ./ (1 + exp(-alpha .* delta));
    XXs = [Input(idxI,:),Input(idxJ,:)];

    if ~isempty(context)
        XXs = [XXs,repmat(context,size(XXs,1),1)];
    end

    PairIndex = [idxI,idxJ];
end

function val = get_option(args,name,default)
    val = default;
    for i = 1:2:length(args)
        if strcmpi(args{i},name)
            val = args{i+1};
            return;
        end
    end
end
