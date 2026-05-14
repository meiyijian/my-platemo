function SDE = SRMaO_CalSDE(PopObj)
% Shift-based density estimation. Larger values are better.

    N = size(PopObj,1);
    if N <= 1
        SDE = zeros(N,1);
        return;
    end

    zmin  = min(PopObj,[],1);
    zmax  = max(PopObj,[],1);
    range = zmax - zmin;
    range(range < 1e-12) = 1;
    PopObj = (PopObj - repmat(zmin,N,1)) ./ repmat(range,N,1);

    k = min(N,floor(sqrt(N)) + 1);
    SDE = zeros(N,1);
    for i = 1 : N
        Shifted = PopObj;
        base = repmat(PopObj(i,:),N,1);
        worse = Shifted < base;
        Shifted(worse) = base(worse);
        dist = pdist2(real(PopObj(i,:)),real(Shifted));
        dist = sort(dist,2);
        SDE(i) = -2 ./ (dist(k) + 2);
    end
end
