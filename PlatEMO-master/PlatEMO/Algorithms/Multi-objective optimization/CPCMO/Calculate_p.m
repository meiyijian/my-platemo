function con = Calculate_p(Cons_num,P,Problem)
% Roulette selection method

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    count = zeros(1,Cons_num);
    for i = 2 : Cons_num
        P(i) = P(i) + P(i-1);
    end
    for i = 1 : Problem.N
        r = rand();
        j = 1;
        while r > P(j)
            j = j + 1;                      
        end
        count(j) = count(j) + 1;
    end
    [~,rank] = sort(count,'descend');
    con     = rank(1);
end