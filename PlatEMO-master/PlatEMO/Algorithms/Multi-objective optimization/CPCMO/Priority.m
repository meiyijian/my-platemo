function [priority,rank] = Priority(Fit,FCV,Cons_num)
% Determine the constraint priority

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    u1       = unique(Fit,'stable');    
    u2       = unique(FCV,'stable');
    rank_fit = zeros(1,Cons_num);
    rank_cv  = zeros(1,Cons_num);
    priority = zeros(1,Cons_num);
    for i = 1 : size(u1,2)
       combine_fit{i} = find(Fit==u1(i));
    end
    for i = 1 : size(u2,2)
        combine_cv{i} = find(FCV==u2(i));
    end
    [~,weizi] = sort(u1);
    [~,rank1] = sort(weizi);
    for i = 1 : length(u1)
        rank_fit(combine_fit{i}) = rank1(i);
    end
    [~,weizi] = sort(u2);
    [~,rank2] = sort(weizi);
    for i = 1 : length(u2)
        rank_cv(combine_cv{i}) = rank2(i);
    end
    rank = rank_fit.*rank_cv;
    u3   = unique(rank,'stable');
    for i = 1 : size(u3,2)
       combine_priority{i} = find(rank==u3(i));
    end
    [~,rank] = sort(weizi);
    for i = 1 : length(u3)
        priority(combine_priority{i}) = rank(i);
    end
end