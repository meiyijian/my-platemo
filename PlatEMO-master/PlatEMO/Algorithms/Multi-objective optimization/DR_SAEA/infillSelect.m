function [Selected, Info] = infillSelect(CandDec, Mu, Sigma, Zref, ArchDec, ...
    K, Strategy, BatchSize, Phase, D)
% <DR_SAEA helper> Infill point selection for DR_SAEA.
%
%   [Selected, Info] = infillSelect(CandDec, Mu, Sigma, Zref, ArchDec, K, ...
%       Strategy, BatchSize, Phase, D)
%
%   Selects BatchSize candidate solutions from CandDec for true evaluation
%   using one of three acquisition strategies. All decisions are made in
%   the K-dimensional reduced objective space; the original M-dimensional
%   objectives are not consulted here.
%
%   Input:
%       CandDec   - Nq x D candidate decision matrix (rows are candidates)
%       Mu        - Nq x K surrogate predicted means
%       Sigma     - Nq x K surrogate predicted uncertainties (sqrt of MSE)
%       Zref      - Nf x K reduced objectives of the current non-dominated
%                   Archive front; used for HV reference construction
%       ArchDec   - Na x D decision variables of the current Archive
%       K         - reduced objective dimension
%       Strategy  - 'balanced' | 'exploitation' | 'exploration'
%       BatchSize - number of points to select
%       Phase     - Problem.FE / Problem.maxFE, in [0, 1]
%       D         - decision variable dimension (for distance threshold)
%
%   Output:
%       Selected  - BatchSize x D decision variables to be truly evaluated
%       Info      - struct with diagnostic fields (selected indices, scores)
%
%   This function is part of the DR_SAEA algorithm.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026. You are free to use DR_SAEA for research purposes.
%--------------------------------------------------------------------------

    [Nq, ~] = size(CandDec);
    BatchSize = min(BatchSize, Nq);
    if BatchSize <= 0
        Selected = zeros(0, size(CandDec, 2));
        Info = struct();
        return;
    end

    % --- 1) Deduplicate against the Archive ---------------------------------
    if ~isempty(ArchDec)
        D2   = pdist2(CandDec, ArchDec);
        minD = min(D2, [], 2);
    else
        minD = inf(Nq, 1);
    end
    % Normalize the distance by decision-space diagonal for fair threshold
    if ~isempty(ArchDec)
        diagLen = norm(max(ArchDec, [], 1) - min(ArchDec, [], 1)) + eps;
    else
        diagLen = 1;
    end
    dupTol   = 1e-6 * diagLen;
    keepMask = minD > dupTol;
    if ~any(keepMask)
        % All duplicates: relax tolerance and keep the farthest ones
        [~, ord] = sort(minD, 'ascend');
        keepMask(ord(1:min(BatchSize, Nq))) = true;
    end
    CandDec = CandDec(keepMask, :);
    Mu      = Mu(keepMask, :);
    Sigma   = Sigma(keepMask, :);
    if size(ArchDec, 1) > 0
        minD = minD(keepMask);
    else
        minD = inf(sum(keepMask), 1);
    end
    Nq = size(CandDec, 1);
    if Nq == 0
        Selected = zeros(0, size(CandDec, 2));
        Info = struct('message', 'no candidate after dedup');
        return;
    end

    % --- 2) Compute per-candidate acquisition score -------------------------
    % Normalize the predicted mean to [0, 1] along each reduced objective
    muMin = min(Mu, [], 1);
    muMax = max(Mu, [], 1);
    muSpan = muMax - muMin;
    muSpan(muSpan == 0) = 1;
    MuN = (Mu - repmat(muMin, Nq, 1)) ./ repmat(muSpan, Nq, 1);
    MuN = max(min(MuN, 1), 0);

    % Hypervolume reference for the reduced space
    if isempty(Zref)
        refZ = max(Mu, [], 1) * 1.1 + 0.1;
    else
        refZ = max(Zref, [], 1) * 1.1 + 0.1;
    end

    % Scalar convergence score (sum of normalized objectives; minimization)
    convScore = sum(MuN, 2);    % smaller is better

    % Scalar uncertainty score (mean of normalized sigma)
    sigMin = min(Sigma, [], 1);
    sigMax = max(Sigma, [], 1);
    sigSpan = sigMax - sigMin;
    sigSpan(sigSpan == 0) = 1;
    SigmaN = (Sigma - repmat(sigMin, Nq, 1)) ./ repmat(sigSpan, Nq, 1);
    SigmaN = max(min(SigmaN, 1), 0);
    uncScore = mean(SigmaN, 2);

    % 2D EHVI when K == 2
    ehvi = zeros(Nq, 1);
    if K == 2
        if isempty(Zref)
            refFront = zeros(0, 2);
        else
            [FrontNo, ~] = NDSort(Zref, 1);
            refFront = Zref(FrontNo == 1, :);
        end
        ehvi = computeEHVI(Mu, refFront, refZ);
        % Normalize to [0, 1]
        eMax = max(ehvi);
        if eMax > 0
            ehviN = ehvi / eMax;
        else
            ehviN = zeros(Nq, 1);
        end
    else
        % Higher dimensional: substitute a crowding-distance-like indicator
        ehviN = 1 - convScore / max(convScore + eps);
    end

    % --- 3) Build the scalar acquisition score per strategy ----------------
    switch lower(Strategy)
        case 'exploitation'
            score = convScore;
            lowerBetter = true;
        case 'exploration'
            score = -uncScore;   % larger uncertainty is better
            lowerBetter = false;
        otherwise   % 'balanced' or unknown
            % Phase < 0.3 -> lean toward exploration; otherwise convergence
            if Phase < 0.3
                wU = 0.7; wC = 0.3;
            else
                wU = 0.3; wC = 0.7;
            end
            score = wU * uncScore - wC * ehviN;
            lowerBetter = true;
    end

    % --- 4) Greedy batch selection with diversity penalty ------------------
    if size(ArchDec, 1) == 0
        ArchDec = zeros(0, size(CandDec, 2));
    end
    minDistThr = 0.05 * diagLen;     % batch diversity threshold
    chosen     = false(Nq, 1);
    pickedIdx  = zeros(BatchSize, 1);

    avail = ~chosen;
    for b = 1 : BatchSize
        s = score;
        s(~avail) = inf;     % exclude already chosen
        if lowerBetter
            [~, idx] = min(s);
        else
            [~, idx] = max(s);
        end
        if ~isfinite(s(idx))
            % No more candidates
            break;
        end
        chosen(idx)  = true;
        avail(idx)   = false;
        pickedIdx(b) = idx;

        % Diversity penalty: reduce the score of nearby candidates
        if b < BatchSize
            dToNew = pdist2(CandDec, CandDec(idx, :));
            close  = dToNew < minDistThr;
            if lowerBetter
                score(close) = score(close) + 1.0;     % push them down
            else
                score(close) = score(close) - 1.0;
            end
        end
    end
    pickedIdx = pickedIdx(pickedIdx > 0);
    Selected  = CandDec(pickedIdx, :);
    Info      = struct('indices', pickedIdx, 'score', score(pickedIdx), ...
        'ehvi', ehvi(pickedIdx), 'conv', convScore(pickedIdx), ...
        'unc', uncScore(pickedIdx));
end
