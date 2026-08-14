function loo = ComputeLeaveOneOutIGDPlus(PopObj, R, EvalID)
%ComputeLeaveOneOutIGDPlus Leave-one-out IGD+ marginal utility (§5.2).
%   loo = ComputeLeaveOneOutIGDPlus(PopObj, R, EvalID)
%   PopObj: N x M, R: nR x M (normalized space), EvalID: N x 1.
%
%   UtilityLOO(i) = IGDplus(P_without_i, R) - IGDplus(P, R).
%   Larger value = solution i contributes more to the overall approximation.
%   Returns a struct:
%     loo.UtilityLOO : N x 1
%     loo.IGDplusAll : scalar IGD+ of the full population
%     loo.EvalID     : N x 1 copied identity

    N = size(PopObj,1);
    nR = size(R,1);
    EvalID = EvalID(:);
    if N < 2
        loo = struct('UtilityLOO',zeros(N,1),'IGDplusAll', ...
            LVIGDPlus(PopObj,R),'EvalID',EvalID);
        return;
    end

    % dplus matrix nR x N
    D = zeros(nR,N);
    for i = 1:N
        d = sqrt(sum(max(PopObj(i,:) - R, 0).^2, 2));
        D(:,i) = d;
    end

    % IGD+ of the full population
    minAll = min(D,[],2);
    igdAll = mean(minAll);

    UtilityLOO = zeros(N,1);
    for i = 1:N
        idxKeep = true(1,N);
        idxKeep(i) = false;
        minWout = min(D(:,idxKeep),[],2);
        UtilityLOO(i) = mean(minWout) - igdAll;
    end

    loo = struct('UtilityLOO',UtilityLOO,'IGDplusAll',igdAll,'EvalID',EvalID);
end
