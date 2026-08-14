function out = ComputeGreedyIGDPlusOracle(PopObj, R, EvalID)
%ComputeGreedyIGDPlusOracle Greedy IGD+ Top-25 oracle (Stage-3 §5.1).
%   out = ComputeGreedyIGDPlusOracle(PopObj, R, EvalID)
%   PopObj: N x M objective matrix of the current population.
%   R:      nR x M reference set (normalized space).
%   EvalID: N x 1 integer identity of each row (tie-break key).
%
%   Iteratively selects 25 solutions so that IGD+ over the growing set is
%   minimized at each step; ties are broken by the smaller PopulationEvalID.
%   Returns:
%     out.OracleGreedyTop25 : 25 x 1 EvalID (selection order)
%     out.GreedyGain        : 25 x 1 IGD+ value after each step
%     out.FinalIGDPlus      : scalar IGD+ of the 25 selected solutions

    N = size(PopObj,1);
    nR = size(R,1);
    if N < 1
        error('ComputeGreedyIGDPlusOracle:Empty','PopObj empty.');
    end
    if size(R,2) ~= size(PopObj,2)
        error('ComputeGreedyIGDPlusOracle:DimMismatch', ...
            'R cols %d ~= PopObj cols %d',size(R,2),size(PopObj,2));
    end
    EvalID = EvalID(:);

    % ---- full dplus distance matrix (nR x N) ----
    D = zeros(nR,N);
    for i = 1:N
        d = sqrt(sum(max(PopObj(i,:) - R, 0).^2, 2));
        D(:,i) = d;
    end

    K = min(25,N);
    curMin = Inf(nR,1);
    selected = false(1,N);
    top25 = zeros(K,1);
    gains = zeros(K,1);

    for k = 1:K
        bestVal = Inf;
        bestIdx = -1;
        for i = 1:N
            if selected(i)
                continue;
            end
            cand = mean(min(curMin, D(:,i)));
            if cand < bestVal - 1e-15 || ...
                    (abs(cand - bestVal) <= 1e-15 && ...
                     (bestIdx < 0 || EvalID(i) < EvalID(bestIdx)))
                bestVal = cand;
                bestIdx = i;
            end
        end
        if bestIdx < 0
            break;
        end
        selected(bestIdx) = true;
        curMin = min(curMin, D(:,bestIdx));
        top25(k) = EvalID(bestIdx);
        gains(k) = bestVal;
    end

    out = struct();
    out.OracleGreedyTop25 = top25(1:k);
    out.GreedyGain        = gains(1:k);
    out.FinalIGDPlus      = mean(curMin);
end
