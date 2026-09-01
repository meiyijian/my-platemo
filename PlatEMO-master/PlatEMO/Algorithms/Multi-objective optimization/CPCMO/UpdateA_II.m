function [A,Fitnessa] = UpdateA_II(Population,A,Problem,type,b,First_FE)
% Update the archive

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    N = Problem.N;
    if type == 0
        CV         = sum(max(0,Population.cons),2);
        Population = Population(CV==0);
        A          = [setdiff(Population,A),A];
        if sum(length(A)) > N
            Fitness  = CalFitness(A.objs,A.cons);
            [~,rank] = sort(Fitness);
            A        = A(rank(1:N));
        end
    elseif type == 1
        if length(A) < N  
                B = Population;
            while length(A)<N && Problem.FE<First_FE
                Fitnessb  = CalFitness(B.objs,B.cons);
                Mating    = TournamentSelection(2,Problem.N,Fitnessb);
                Offspring = OperatorGA(Problem,B(Mating));
                B         = EnvironmentalSelection([B,Offspring],Problem.N);
                A         = UpdateA_II(B,A,Problem,0,b);
            end
        else
            A_C        = Cauchy(A,0,b,Problem); 
            Population = [A,A_C];
            A          = EnvironmentalSelection_cd(Population,Problem.N);
        end
    else
        Population   = [A,Population];
        [A,Fitnessa] = EnvironmentalSelection_cd(Population,Problem.N);
    end
end