function [Population1,Population2] = Exchange(Population1,Population2,Index_size,MN,Type)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Wenxiang Wang (email: wwx_cmcc@qq.com)

    N = size(Population1,2);
    [FrontNo1,~] = NDSort(Population1.objs,Population1.cons,N);
    [FrontNo2,~] = NDSort(Population2.objs,Population2.cons,N);
    [~,Index1]   = sortrows(FrontNo1');
    [~,Index2]   = sortrows(FrontNo2');

    for i = 1 : Index_size
        k1 = find(Index2 == i);
        k2 = find(Index1 == N-i+1);
        k3 = find(Index2 == N-i+1);
        k4 = find(Index1 == i);
        
        Population2(k1) = Cal_MP(Population2(k1),MN,Type);
        Population1(k2) = Population2(k1);
        Population2(k3) = Population1(k4);
    end
end