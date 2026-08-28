function reference = CVPOracleReference(Problem, referenceSize, runId)
%CVPORACLEREFERENCE Deterministic reference subsample for the oracle.
%   REFERENCE = CVPORACLEREFERENCE(PROBLEM, REFERENCESIZE, RUNID) subsamples
%   PROBLEM.optimum down to REFERENCESIZE rows so each greedy oracle step
%   costs a bounded distance computation.
%
%   PlatEMO builds optimum with GetOptimum(10000). The realised row count is
%   problem dependent: DTLZ2 at M=10 returns however many weights
%   UniformPoint produces, WFG3 returns exactly 10000 points along a line.
%   Subsampling with a fixed stride keeps the reference set spread over the
%   whole front instead of clustering it.
%
%   The subsample depends only on (problem, referenceSize) and NOT on the
%   arm, so all five arms of a paired job score against an identical
%   reference set. RUNID is accepted for signature stability and
%   deliberately unused, which keeps the reference set constant across runs
%   of the same problem.

    reference = Problem.optimum;
    if isempty(reference)
        return;
    end
    if size(reference, 2) ~= Problem.M
        reference = zeros(0, Problem.M);
        return;
    end

    total = size(reference, 1);
    if total <= referenceSize
        return;
    end

    stride = total / referenceSize;
    index = unique(round((0.5:referenceSize-0.5) * stride) + 1);
    index = index(index >= 1 & index <= total);
    reference = reference(index, :);
end
