function [score, V, nDir] = ComputeUniformDirectionScore(PopObj, theta, Nref, V)
%ComputeUniformDirectionScore L7: uniform-direction PBI score.
%   [score, V, nDir] = ComputeUniformDirectionScore(PopObj, theta, Nref)
%   reproduces the frozen score_v computation of HybridPBI_Classification
%   but with a uniform ILD direction set:
%       V  = UniformPoint(Nref,M,'ILD');  V = V./vecnorm(V,2,2);
%       cosine = 1 - pdist2(PopObj,V,'cosine');
%       [~,ref_idx] = max(cosine,[],2);
%       d1(i) = (PopObj(i,:)-Zmin)*w' / norm(w);
%       proj  = Zmin + d1(i)*w;
%       d2(i) = norm(PopObj(i,:)-proj);
%       PBI_v = d1 + theta*d2;
%       score = 1./(1+PBI_v);
%   Must record the ACTUAL number of directions size(V,1), which is not
%   guaranteed to equal Nref for the 'ILD' method.
%
%   Inputs:
%     PopObj - N x M objective matrix
%     theta  - scalar PBI penalty (frozen: 5)
%     Nref   - requested number of reference directions (frozen: 100)
%     V      - OPTIONAL explicit direction matrix (for unit tests only;
%              the production call omits it and uses UniformPoint).
%   Outputs:
%     score - N x 1 score vector (higher = closer to a direction)
%     V     - nDir x M direction matrix (unit length rows)
%     nDir  - scalar, size(V,1) actual direction count

    N  = size(PopObj,1);
    M  = size(PopObj,2);

    % ---- uniform direction field (exact frozen statements) ----
    if nargin < 4 || isempty(V)
        V = UniformPoint(Nref, M, 'ILD');
    end
    V = V ./ vecnorm(V, 2, 2);
    nDir = size(V,1);

    % ---- frozen score_v statements ----
    Zmin  = min(PopObj, [], 1);
    cosine = 1 - pdist2(PopObj, V, 'cosine');
    [~, ref_idx] = max(cosine, [], 2);

    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        vi = ref_idx(i);
        w  = V(vi,:);
        d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);
        proj  = Zmin + d1(i) * w;
        d2(i) = norm(PopObj(i,:) - proj);
    end

    PBI_v = d1 + theta * d2;
    score = 1 ./ (1 + PBI_v);
end
