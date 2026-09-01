function Population = operator_GA(Population,Problem,N,EP)
% The search algorithm for auxiliary population

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiqiang Zeng (email: zhiqiang.zeng@outlook.com)

    total_pop   = [Population,EP];
    [FrontNo,~] = NDSort(total_pop.objs,0,inf);
    CrowdDis    = CrowdingDistance(total_pop.objs,FrontNo);
    [~,r]       = sortrows([FrontNo',-CrowdDis']);
    Rp(r)       = 1 : length(total_pop);
    MatingPool  = TournamentSelection(2,N,Rp);
    
    
    Offspring    = OperatorGAhalf(Problem,total_pop(MatingPool));
    total_pop1   = [total_pop,Offspring];
    [FrontNo1,~] = NDSort(total_pop1.objs,0,inf);
    CrowdDis1    = CrowdingDistance(total_pop1.objs,FrontNo1);
    [~,r1]       = sortrows([FrontNo1',-CrowdDis1']);

    N1 = ceil(Problem.FE/Problem.maxFE*N);
    if N1 < ceil(0.5*N)
        N1 = ceil(0.5*N);
    end
    
    if N1 < N
        Population_1   = total_pop1(r1(1:N1));
        Population_t_1 = total_pop1(r1(N1+1:end));
        Population_2   = Population_t_1(randperm(length(total_pop1)-N1,N-N1));
        Population     = [Population_1,Population_2];
    else
        Population = total_pop1(r1(1:N));
    end
end