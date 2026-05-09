function SDE = CalSDE(PopObj)
% CalSDE - Calculate Shift-based Density Estimation (SDE) for each solution
% SDE measures both convergence and diversity of solutions.
% Smaller SDE value indicates better solution quality (more elite).
%
% Input:
%   PopObj - N x M matrix, objective values of population
%
% Output:
%   SDE - N x 1 vector, SDE score for each solution (smaller is better)
%
% Reference:
%   M. Li, S. Yang, and X. Liu, "Shift-based density estimation for 
%   Pareto-based algorithms in many-objective optimization," IEEE TEVC, 2014.
%
% Copyright (c) 2025 BIMK Group.

    N = size(PopObj, 1);
    if N <= 1
        SDE = zeros(N, 1);
        return;
    end
    
    Zmin = min(PopObj, [], 1);
    Zmax = max(PopObj, [], 1);
    range = Zmax - Zmin;
    range(range == 0) = 1;
    PopObj = (PopObj - repmat(Zmin, N, 1)) ./ repmat(range, N, 1);
    
    SDE = zeros(N, 1);
    k = floor(sqrt(N)) + 1;
    if k > N
        k = N;
    end
    
    for i = 1 : N
        SPopuObj = PopObj;
        Temp = repmat(PopObj(i, :), N, 1);
        Shifted = PopObj < Temp;
        SPopuObj(Shifted) = Temp(Shifted);
        Distance = pdist2(real(PopObj(i, :)), real(SPopuObj));
        [~, index] = sort(Distance, 2);
        Dk = Distance(index(k));
        SDE(i) = 2 ./ (Dk + 2);
    end
end
