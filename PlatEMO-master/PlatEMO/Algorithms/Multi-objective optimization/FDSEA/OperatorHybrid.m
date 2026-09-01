function [Population,Offspring] = OperatorHybrid(Problem,Population,gama)
% The hybrid operator combining GA and DE

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Wenxiang Wang (email: wwx_cmcc@qq.com)

    N      = Problem.N;
    RandNo = randperm(N);
    N1     = round(N*gama);
    if mod(N1,2) ~= 0
        N1 = N1 - 1;
    end
    if N1 < 0
        N1 = 0;
    elseif N1 >= N - 1
        N1 = N;
    end
    
    if N1>=2 && N1 <= N-2
        N2         = N - N1;
        Pop1       = Population(RandNo(1:N1));
        MatingPool = TournamentSelection(2,N1,sum(max(0,Pop1.cons),2));
        Offspring1 = OperatorGA(Problem,Pop1(MatingPool),{1,20,1,20});
        Pop2       = Population(RandNo(N1+1:end));
        for i = 1 : N1
            Pop1(i).add       = 0;
            Offspring1(i).add = 1;
        end
        Offspring2 = OperatorDE(Problem,Pop2,Pop2(randi(N2,1,N2)),Pop2(randi(N2,1,N2)));
        for i = 1 : N2
            Pop2(i).add       = 0;
            Offspring2(i).add = -1;
        end
        Offspring  = [Offspring1,Offspring2];
        Population = [Pop1,Pop2];
    elseif N1 == N
        MatingPool = TournamentSelection(2,N,sum(max(0,Population.cons),2));
        Offspring  = OperatorGA(Problem,Population(MatingPool),{1,20,1,20});
        for i = 1 : N
            Population(i).add = 0;
            Offspring(i).add  = 1;
        end
    else
        Offspring = OperatorDE(Problem,Problem,Population(randi(N,1,N)),Population(randi(N,1,N)));
        for i = 1 : N
            Population(i).add = 0;
            Offspring(i).add  = -1;
        end
    end
end