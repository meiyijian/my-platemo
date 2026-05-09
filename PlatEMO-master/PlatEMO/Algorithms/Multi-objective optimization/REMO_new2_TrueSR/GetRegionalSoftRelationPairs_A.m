function [XXs,Ps,Meta] = GetRegionalSoftRelationPairs_A(Input,Info,W,activeRegions,varargin)
% Route A samples: [x_i, x_j, w_r] -> P_r(x_i better than x_j).

    alpha      = get_option(varargin,'Alpha',6);
    maxPairs   = get_option(varargin,'MaxPairs',12000);
    neighborNum = get_option(varargin,'NeighborNum',2);
    minGap     = get_option(varargin,'MinGap',0);

    activeRegions = activeRegions(:)';
    if isempty(activeRegions)
        activeRegions = unique(Info.region(:))';
    end

    perRegionMax = inf;
    if isfinite(maxPairs)
        perRegionMax = max(20,ceil(maxPairs/numel(activeRegions)));
    end

    XXs = [];
    Ps  = [];
    RegionID = [];
    PairIndex = [];

    for r = activeRegions
        pool = ExpandRegionPool_RegionalSR(Info.region,W,r,neighborNum,2);
        [Xr,Pr,PairR] = GetRegionSoftPairs_RegionalSR(Input,Info.localScoreMatrix(:,r),pool,...
            'Alpha',alpha,'MaxPairs',perRegionMax,'MinGap',minGap,'Context',W(r,:));
        XXs = [XXs;Xr]; %#ok<AGROW>
        Ps  = [Ps;Pr]; %#ok<AGROW>
        RegionID  = [RegionID;repmat(r,size(Xr,1),1)]; %#ok<AGROW>
        PairIndex = [PairIndex;PairR]; %#ok<AGROW>
    end

    if isfinite(maxPairs) && size(XXs,1) > maxPairs
        keep = randperm(size(XXs,1),maxPairs);
        XXs = XXs(keep,:);
        Ps  = Ps(keep,:);
        RegionID  = RegionID(keep,:);
        PairIndex = PairIndex(keep,:);
    end

    order = randperm(size(XXs,1));
    XXs = XXs(order,:);
    Ps  = Ps(order,:);
    RegionID  = RegionID(order,:);
    PairIndex = PairIndex(order,:);

    Meta.RegionID  = RegionID;
    Meta.PairIndex = PairIndex;
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
