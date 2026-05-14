function diagnostics = SRMaO_RuntimeDiagnostics(Population, Nref)
% Runtime population state used by continuous acquisition weights.

    PopObj = Population.objs;
    [N,M]  = size(PopObj);
    diagnostics = struct('coverage',0,'degeneracy',0);
    if N == 0 || M == 0
        return;
    end

    PopObj = normalizeObjectives(PopObj);
    [V,~] = UniformPoint(Nref,M,'ILD');
    V = V ./ max(vecnorm(V,2,2),eps);

    dir = PopObj;
    bad = vecnorm(dir,2,2) < 1e-12;
    dir(bad,:) = 1 ./ max(1,M);
    dir = dir ./ max(vecnorm(dir,2,2),eps);

    cosine = 1 - pdist2(dir,V,'cosine');
    [~,assigned] = max(cosine,[],2);
    diagnostics.coverage = numel(unique(assigned)) / size(V,1);

    centered = PopObj - mean(PopObj,1);
    if size(centered,1) < 2 || all(abs(centered(:)) < 1e-12)
        diagnostics.degeneracy = 0;
        return;
    end
    s = svd(centered,'econ');
    energy = s.^2;
    total = sum(energy);
    if total < 1e-12
        rank90 = M;
    else
        rank90 = find(cumsum(energy)./total >= 0.90,1,'first');
    end
    diagnostics.degeneracy = max(0,min(1,1 - rank90/max(1,M)));
end

function PopObj = normalizeObjectives(PopObj)
    zmin = min(PopObj,[],1);
    zmax = max(PopObj,[],1);
    span = zmax - zmin;
    span(span < 1e-12) = 1;
    PopObj = (PopObj - repmat(zmin,size(PopObj,1),1)) ./ repmat(span,size(PopObj,1),1);
    PopObj(isnan(PopObj) | isinf(PopObj)) = 0;
end
