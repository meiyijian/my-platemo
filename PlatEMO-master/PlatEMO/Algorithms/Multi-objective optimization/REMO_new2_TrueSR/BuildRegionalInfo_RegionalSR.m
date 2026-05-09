function Info = BuildRegionalInfo_RegionalSR(PopObj,W,ratio)
% Associate evaluated solutions with reference-vector regions and calculate
% APD-based local quality scores for every solution under every region.

    [N,M] = size(PopObj);
    R     = size(W,1);

    Zmin  = min(PopObj,[],1);
    Zmax  = max(PopObj,[],1);
    range = Zmax - Zmin;
    range(range < 1e-12) = 1;
    PopObjN = (PopObj - Zmin) ./ range;
    PopObjN(PopObjN < 1e-12) = 1e-12;

    normP = vecnorm(PopObjN,2,2);
    normP(normP == 0) = eps;

    cosine = 1 - pdist2(PopObjN,W,'cosine');
    cosine = min(max(cosine,-1),1);
    angle  = real(acos(cosine));
    [~,region] = max(cosine,[],2);

    wCos = min(max(W*W',-1),1);
    wAng = real(acos(wCos));
    wAng(logical(eye(R))) = inf;
    gamma = min(wAng,[],2);
    gamma(~isfinite(gamma) | gamma < 1e-12) = 1;

    penalty = M .* ratio.^2;
    apdMatrix = zeros(N,R);
    for r = 1:R
        apdMatrix(:,r) = (1 + penalty .* angle(:,r) ./ gamma(r)) .* normP;
    end

    ownIndex = sub2ind([N,R],(1:N)',region);
    ownAPD   = apdMatrix(ownIndex);

    Info.PopObjN          = PopObjN;
    Info.region           = region;
    Info.angle            = angle;
    Info.cosine           = cosine;
    Info.gamma            = gamma;
    Info.apdMatrix        = apdMatrix;
    Info.localScoreMatrix = -apdMatrix;
    Info.ownScore         = -ownAPD;
end
