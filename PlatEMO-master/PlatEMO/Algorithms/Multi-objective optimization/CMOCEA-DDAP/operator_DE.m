function [Population,a_total,b_total,a_scuss,b_scuss] = operator_DE(Problem,Population,EP,rd)
% The search algorithm for main population

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiqiang Zeng (email: zhiqiang.zeng@outlook.com)

    pop_num       = length(Population);
    a_total       = 0;
    b_total       = 0;
    selet_flag    = zeros(1,pop_num);
    Total_pop     = [Population,EP];
    pop_num_total = length(Total_pop);
    FrontNo       = NDSort(Total_pop.objs,0,1);
    [N,D]         = size(Population(1).decs);
    trial         = zeros(1*pop_num,D);
    
    for i = 1 : pop_num
        % Randomly select one individual from ranking level 1 as the best
        index_No1  = find(FrontNo==1);
        r          = floor(rand*length(index_No1))+1;
        best_index = index_No1(r);
    
        % Randomly select three individuals who are not equal to each other
        indexset     = 1 : pop_num_total;
        indexset(i)  = [];
        r1           = floor(rand*(pop_num_total-1))+1;
        xr1          = indexset(r1);
        indexset(r1) = [];
        r2           = floor(rand*(pop_num_total-2))+1;
        xr2          = indexset(r2);
        indexset(r2) = [];
        r3           = floor(rand*(pop_num_total-3))+1;
        xr3          = indexset(r3);
    
        F_pool = [0.1,0.8,1.0];
        F      = F_pool(randi(3));
        CR     = 0.05;
    
        if rand <= rd
            if rand < 0.5
                v = Total_pop(xr1).decs+F*(Total_pop(best_index).decs-Total_pop(xr1).decs)+F*(Total_pop(xr2).decs-Total_pop(xr3).decs);%Mutation operation 1
            else
                v = Total_pop(xr1).decs+F*(Population(i).decs-Total_pop(xr1).decs)+F*(Total_pop(xr2).decs-Total_pop(xr3).decs);%Mutation operation 2
            end
    
            % Boundary Repair
            Lower = repmat(Problem.lower,N,1);
            Upper = repmat(Problem.upper,N,1);
            v     = min(max(v,Lower),Upper);
    
            % Crossover operation
            Site   = rand(N,D) < CR;
            j_rand = floor(rand * D) + 1;
            Site(1, j_rand) = 1;
            Site_  = 1-Site;
            trial(i, :)   = Site.*v+Site_.*Population(i).decs;    
            a_total       = a_total+1;
            selet_flag(i) = 1;
        else
            if rand < 0.5
                v = Population(i).decs+F*(Total_pop(xr1).decs-Population(i).decs)+F*(Total_pop(xr2).decs-Total_pop(xr3).decs);%Mutation operation 3
            else
                v = Population(i).decs+F*(Total_pop(best_index).decs-Population(i).decs)+F*(Total_pop(xr1).decs-Total_pop(xr2).decs);%Mutation operation 4
            end

            % Boundary Repair
            Lower = repmat(Problem.lower,N,1);
            Upper = repmat(Problem.upper,N,1);
    
            trial(i, :)   = min(max(v,Lower),Upper);
            b_total       = b_total+1;
            selet_flag(i) = 2;
        end
        % The perturbation strategy
        for k = 1 : D
            if rand<0.01 && rand>=Problem.FE/Problem.maxFE
                trial(i, k) = Lower(k)+(Upper(k)-Lower(k))*rand;
            end
        end
    
    end
    Offspring = trial;
    Offspring = Problem.Evaluation(Offspring);
        
    Total_pop1 = [Offspring,Total_pop];
    [N1,~]     = size(Total_pop1.objs);
    
    
    [FrontNo1,~] = NDSort(Total_pop1.objs,Total_pop1.cons,inf);
    CrowdDis1    = CrowdingDistance(Total_pop1.objs,FrontNo1);
    [~,r1]       = sortrows([FrontNo1',-CrowdDis1']);
    Rc(r1)       = 1 : N1;   % Ranking based on CDP
    
    [FrontNo2,~] = NDSort(Total_pop1.objs,0,inf);
    CrowdDis2    = CrowdingDistance(Total_pop1.objs,FrontNo2);
    [~,r2]       = sortrows([FrontNo2',-CrowdDis2']);
    Rp(r2)       = 1 : N1;   % Ranking based on non dominated sorting
    
    a     = 1-Problem.FE/Problem.maxFE;
    pro_l = 1-length(find(sum(max(0,Population.cons),2)>0))/pop_num; % Calculate feasibility rate
    b     = 1.0/((Problem.FE/Problem.maxFE)^2+1)-0.5;
    
    r        = a*(1-b)+pro_l*b;
    R_sum    = (1-r)*Rc+r*Rp; % To fuse two rankings.
    [~,Rank] = sort(R_sum);
    
    if length(find(FrontNo1==1)) > pop_num
        nondom_pop     = Total_pop1(FrontNo1==1);
        [Population,~] = EnvironmentalSelection_CDP(nondom_pop,pop_num);%Execute Strategy I
    else
        Population = Total_pop1(Rank(1:pop_num)); % Execute Strategy II
    end
    
    diff_rank = R_sum(1:pop_num)-R_sum(pop_num+1:pop_num+pop_num);
    temp1     = selet_flag(diff_rank<0);
    a_scuss   = length(find(temp1==1));
    b_scuss   = length(find(temp1==2));
end