function W = CreateReferenceVectors_RegionalSR(Nref,M)
% Create unit reference vectors for regional many-objective ranking.

    W = UniformPoint(Nref,M,'ILD');
    normW = vecnorm(W,2,2);
    normW(normW == 0) = 1;
    W = W ./ normW;
end
