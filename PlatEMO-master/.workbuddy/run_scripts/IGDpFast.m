function score = IGDpFast(Population, optimum, blockSize)
%IGDpFast Block-wise IGD+ that is mathematically identical to the PlatEMO metric.
%   The stock IGDp.m loops over every reference point and allocates an N-by-M
%   temporary each time. For DTLZ7 at M=20 the reference set holds 524288
%   points, so that loop allocates half a million temporaries per evaluation,
%   which is both slow and enough to destabilise several concurrent workers.
%   Here the reference points are processed in blocks, so the memory footprint
%   stays bounded while the arithmetic is exactly the same:
%       delta(i) = min_j sqrt( sum_k max(PopObj(j,k) - optimum(i,k), 0)^2 )
%       score    = mean(delta)
%   The caller compares the result against the stock metric before trusting it.

    if nargin < 3 || isempty(blockSize), blockSize = 20000; end

    PopObj = Population.best.objs;
    if size(PopObj, 2) ~= size(optimum, 2)
        score = nan;
        return;
    end
    PopObj = double(PopObj);
    optimum = double(optimum);          % every part of the table can be relaxed above

    Nr = size(optimum, 1);
    N  = size(PopObj, 1);
    M  = size(PopObj, 2);
    delta = zeros(Nr, 1);
    Pt = PopObj.';                      % M-by-N, reused for every block
    for s0 = 1:blockSize:Nr
        idx = s0:min(s0 + blockSize - 1, Nr);
        acc = zeros(numel(idx), N);
        for j = 1:M
            acc = acc + max(bsxfun(@minus, Pt(j, :), optimum(idx, j)), 0).^2;
        end
        delta(idx) = min(sqrt(acc), [], 2);
    end
    score = mean(delta);
end
