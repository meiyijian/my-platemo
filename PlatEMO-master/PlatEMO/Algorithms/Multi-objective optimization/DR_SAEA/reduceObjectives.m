function varargout = reduceObjectives(PopObj, K, Strategy, Seed, varargin)
% <DR_SAEA helper> Objective dimension reduction for surrogate modeling.
%
%   This module provides two strategies for mapping the original M objective
%   dimensions to K reduced dimensions, used only as an intermediate
%   representation for the surrogate model and the infill criterion. The
%   original M-dimensional objectives are preserved in Archive.objs and are
%   always used for true evaluation, output, and metric calculation.
%
%   Call:
%       [GroupMap, Fmin, Fmax] = reduceObjectives(PopObj, K, Strategy, Seed)
%       Z                       = reduceObjectives(PopObj, K, Strategy, Seed, ...
%                                                GroupMap, Fmin, Fmax)
%
%   Input:
%       PopObj     - N x M matrix, rows are samples, columns are objectives
%       K          - target number of reduced objectives (K < M)
%       Strategy   - 'random' or 'correlation'
%       Seed       - random seed for the 'random' strategy (ignored otherwise)
%       (optional) GroupMap, Fmin, Fmax - if supplied, this call returns
%                                        the reduced objective Z directly.
%
%   Output:
%       GroupMap   - 1 x M integer vector (planning mode)
%       Fmin/Fmax  - 1 x M vectors (planning mode)
%       Z          - N x K reduced objectives (apply mode)
%
%   This function is part of the DR_SAEA algorithm.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026. You are free to use DR_SAEA for research purposes.
%--------------------------------------------------------------------------

    if nargin >= 6 && ~isempty(varargin{1})
        % Apply mode: reduce PopObj using an existing plan
        GroupMap = varargin{1};
        Fmin     = varargin{2};
        Fmax     = varargin{3};
        varargout{1} = applyReduction(PopObj, GroupMap, Fmin, Fmax);
        return;
    end

    [N, M] = size(PopObj);
    if K >= M
        K = max(1, M - 1);
    end
    if K < 1
        K = 1;
    end

    % Normalization baseline (used for the lifetime of the algorithm)
    Fmin = min(PopObj, [], 1);
    Fmax = max(PopObj, [], 1);
    span = Fmax - Fmin;
    span(span == 0) = 1;   % avoid division by zero for constant objectives

    switch lower(Strategy)
        case 'random'
            rng(Seed, 'twister');
            order = randperm(M);
            shuffled = zeros(1, M);
            for g = 1 : K
                idx = (g:K:M);
                shuffled(idx) = order(idx);
            end
            GroupMap = zeros(1, M);
            for j = 1 : M
                GroupMap(shuffled(j)) = ceil(j / ceil(M / K));
                if GroupMap(shuffled(j)) > K
                    GroupMap(shuffled(j)) = K;
                end
            end
        otherwise  % 'correlation' or anything else -> correlation
            GroupMap = correlationGrouping(PopObj, K);
    end

    varargout{1} = GroupMap;
    varargout{2} = Fmin;
    varargout{3} = Fmax;
end

function Z = applyReduction(PopObj, GroupMap, Fmin, Fmax)
%applyReduction - Reduce a new sample matrix using an existing grouping plan.
%
%   Z = applyReduction(PopObj, GroupMap, Fmin, Fmax) returns an N x K
%   reduced objective matrix by min-max normalizing the original objectives
%   and taking an equal-weight linear sum inside each group.
%
%   Input:
%       PopObj   - N x M matrix
%       GroupMap - 1 x M integer vector, same convention as above
%       Fmin/Fmax - 1 x M normalization baseline
%
%   Output:
%       Z - N x K reduced objective matrix

    [N, M]  = size(PopObj);
    K       = max(GroupMap);
    span    = Fmax - Fmin;
    span(span == 0) = 1;
    Norm    = (PopObj - repmat(Fmin, N, 1)) ./ repmat(span, N, 1);
    Norm    = max(min(Norm, 1), 0);          % clip to [0,1]
    Z       = zeros(N, K);
    for g = 1 : K
        members = (GroupMap == g);
        if any(members)
            Z(:, g) = mean(Norm(:, members), 2);
        end
    end
end

function GroupMap = correlationGrouping(PopObj, K)
%correlationGrouping - Build groups by hierarchical clustering of
%   Pearson-correlated objectives.
%
%   Uses a self-implemented average-linkage agglomerative clustering to
%   avoid requiring the Statistics Toolbox. Distance is 1 - |r|, which
%   keeps strongly correlated objectives in the same group.

    [N, M] = size(PopObj);
    if N < 3 || M <= K
        % Fallback to a balanced round-robin grouping
        GroupMap = zeros(1, M);
        for g = 1 : K
            GroupMap((g:K:M)) = g;
        end
        return;
    end

    R = corrcoef(PopObj);
    R(isnan(R)) = 0;
    D = 1 - abs(R);
    D(eye(M) == 1) = 0;
    D = max(D, 0);

    % Self-implemented agglomerative average-linkage clustering
    clusters   = num2cell(1:M);
    clusterD   = D;
    active     = true(1, M);
    for it = 1 : (M - K)
        bestMerge = [];
        bestVal   = inf;
        ids = find(active);
        for a = 1 : length(ids)
            for b = a+1 : length(ids)
                i = ids(a); j = ids(b);
                if isempty(clusters{i}) || isempty(clusters{j})
                    continue;
                end
                if isinf(clusterD(i, j))
                    continue;
                end
                if clusterD(i, j) < bestVal
                    bestVal   = clusterD(i, j);
                    bestMerge = [i, j];
                end
            end
        end
        if isempty(bestMerge)
            break;
        end
        i = bestMerge(1); j = bestMerge(2);
        clusters{i} = [clusters{i}, clusters{j}];
        clusters{j} = [];
        active(j)   = false;
        % Update distance row/col i to be the average distance
        for kk = find(active)
            if kk == i
                continue;
            end
            ni = length(clusters{i});
            nj = length(clusters{kk});
            if isempty(clusters{kk})
                clusterD(i, kk) = inf;
                clusterD(kk, i) = inf;
                continue;
            end
            d_ij = clusterD(i, kk);
            d_jj = clusterD(j, kk);
            if isinf(d_ij) || isinf(d_jj)
                clusterD(i, kk) = inf;
                clusterD(kk, i) = inf;
            else
                % Average-linkage update: weighted by cluster sizes
                clusterD(i, kk) = (ni * d_ij + nj * d_jj) / (ni + nj);
                clusterD(kk, i) = clusterD(i, kk);
            end
        end
        clusterD(i, j) = inf;
        clusterD(j, i) = inf;
    end

    ids = find(active);
    GroupMap = zeros(1, M);
    for g = 1 : length(ids)
        GroupMap(clusters{ids(g)}) = g;
    end
end
