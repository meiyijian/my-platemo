function [Models,pErr] = TrainRegionalSoftModels_B(Input,Info,W,varargin)
% Route B training: train one local model for each selected active region.

    alpha       = get_option(varargin,'Alpha',6);
    maxPairs    = get_option(varargin,'MaxPairs',12000);
    anchorNum   = get_option(varargin,'AnchorNum',12);
    neighborNum = get_option(varargin,'NeighborNum',2);
    maxModels   = get_option(varargin,'MaxModels',20);

    activeRegions = SelectActiveRegions_RegionalSR(Info.region,maxModels);
    perModelPairs = inf;
    if isfinite(maxPairs) && ~isempty(activeRegions)
        perModelPairs = max(30,ceil(maxPairs/numel(activeRegions)));
    end

    Models = struct('region',{},'net',{},'mp_struct',{},'anchorIndex',{},'anchorNum',{});
    errList = [];

    for r = activeRegions
        pool = ExpandRegionPool_RegionalSR(Info.region,W,r,neighborNum,2);
        [XXs,Ps] = GetRegionSoftPairs_RegionalSR(Input,Info.localScoreMatrix(:,r),pool,...
            'Alpha',alpha,'MaxPairs',perModelPairs);
        if size(XXs,1) < 2
            continue;
        end

        [TrainIn,TrainOut,TestIn,TestOut] = DataProcessSoft(XXs,Ps,0.75);
        [net,mpStruct] = TrainSoftProbabilityNet_RegionalSR(TrainIn,TrainOut);

        if isempty(TestIn)
            errList(end+1) = NaN; %#ok<AGROW>
        else
            TestInNor = mapminmax('apply',TestIn',mpStruct)';
            TestPred  = net(TestInNor')';
            errList(end+1) = mean((TestPred - TestOut).^2); %#ok<AGROW>
        end

        anchorIndex = SelectAnchorsForRegion_RegionalSR(Info.localScoreMatrix(:,r),pool,anchorNum);
        Models(end+1).region      = r; %#ok<AGROW>
        Models(end).net           = net;
        Models(end).mp_struct     = mpStruct;
        Models(end).anchorIndex   = anchorIndex;
        Models(end).anchorNum     = numel(anchorIndex);
    end

    if isempty(Models)
        % Fallback: train one local model on the region with most samples.
        fallbackRegion = SelectActiveRegions_RegionalSR(Info.region,1);
        pool = (1:size(Input,1))';
        [XXs,Ps] = GetRegionSoftPairs_RegionalSR(Input,Info.localScoreMatrix(:,fallbackRegion),pool,...
            'Alpha',alpha,'MaxPairs',maxPairs);
        [TrainIn,TrainOut,TestIn,TestOut] = DataProcessSoft(XXs,Ps,0.75);
        [net,mpStruct] = TrainSoftProbabilityNet_RegionalSR(TrainIn,TrainOut);
        anchorIndex = SelectAnchorsForRegion_RegionalSR(Info.localScoreMatrix(:,fallbackRegion),pool,anchorNum);
        Models(1).region      = fallbackRegion;
        Models(1).net         = net;
        Models(1).mp_struct   = mpStruct;
        Models(1).anchorIndex = anchorIndex;
        Models(1).anchorNum   = numel(anchorIndex);
        if isempty(TestIn)
            errList = NaN;
        else
            TestInNor = mapminmax('apply',TestIn',mpStruct)';
            TestPred  = net(TestInNor')';
            errList = mean((TestPred - TestOut).^2);
        end
    end

    pErr = mean(errList,'omitnan');
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
