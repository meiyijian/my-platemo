classdef CPCMO < ALGORITHM
% <2026> <multi> <real/integer/label/binary/permutation> <constrained>
% Constraint, multiobjective, multi-stage, multi-constraint evolutionary algorithm
% type --- 1 --- Type of operator (1. GA 2. DE)

%------------------------------- Reference --------------------------------
% X. Zhou, Y. Zhu, Y. Wang, R. Sun, and J. Zou. Constrained multi-objective
% optimization with constraint priority. IEEE Transactions on Emerging
% Topics in Computational Intelligence, 2025.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------
    
    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            strategy  = Algorithm.ParameterSet(1);      
            stage     = 1;
            tao       = 0.05;                    
            b         = 0.1;                                    
            cp        = 2;                       
            alpha     = 0.95;                    
            Tc        = Problem.maxFE*0.6;
            epsilon_k = 0;                       
            exchange  = 1;
            A_change  = 0;                              
            gen       = 2;
            change_threshold = 1e-3;                    
            Population       = Problem.Initialization();
            Objvalues(1)     = sum(sum(Population.objs,1));
            Cons_num         = size(Population.cons,2);
            epsilon_0        = zeros(1,Cons_num);       
            for i = 1 : Cons_num
                Pop{i}     = Population;
                Pop_con{i} = Pop{i}.cons;
                Fitness{i} = CalFitness(Pop{i}.objs,Pop_con{i});
            end
            CV       = sum(max(0,Population.cons),2);
            A        = Population(CV==0);                                             
            Fitness  = CalFitness(Population.objs);
            First_FE = Problem.maxFE*0.3;

            %% Optimization
            while Algorithm.NotTerminated(Population)
                if exchange == 1   
                    if strategy ==1
                        Mating    = TournamentSelection(2,Problem.N,Fitness);
                        Offspring = OperatorGA(Problem,Population(Mating));
                    else
                        MatingPool = TournamentSelection(2,2*Problem.N,Fitness);
                        Offspring  = OperatorDE(Problem,Population,Population(MatingPool(1:end/2)),Population(MatingPool(end/2+1:end)));
                    end
                    [Population,Fitness] = EnvironmentalSelection_cov([Population,Offspring],Problem.N);
                    for i = 1 : Cons_num
                        Pop{i} = EnvironmentalSelection_alone([Pop{i},Offspring],Problem.N,i);
                    end
                    Objvalues(gen) = sum(sum(abs(Population.objs),1));
                    change         = is_stable(Objvalues,gen,Population,Problem.N,change_threshold,Problem.M);
                    if change == 1
                        exchange = 0;   
                    else
                        AllPop = [];
                        for i = 1 : Cons_num
                            AllPop = [AllPop,Pop{i}];
                        end
                        A = UpdateA_II([Population,Offspring,AllPop],A,Problem,0,b,First_FE);   
                    end            
                else 
                    if stage == 1                       
                        Fit = zeros(1,Cons_num);        
                        FCV = zeros(Cons_num,Cons_num); 
                        for i = 1 : Cons_num
                            Fit(i)   = Calculate_fit(Pop{i});
                            CV       = Pop{i}.cons;
                            num      = sum(CV>0);
                            FCV(i,:) = num/Problem.N;
                        end
                        FCV       = sum(FCV);                       
                        priority  = Priority(Fit,FCV,Cons_num);
                        p         = priority/sum(priority);           
                        con       = Calculate_p(Cons_num,p,Problem);
                        CV        = Population.cons;
                        epsilon_0 = max(epsilon_0,max(CV,[],1));
                        epsilon_k = epsilon_0(con);
                        A         = EnvironmentalSelection_cd( AllPop,Problem.N);
                        Fitness   = CalFitness_epsilon(Population.objs,Population.cons,epsilon_k,con);
                        stage     = 0;
                        tempFE    = Problem.FE;
                    else
                        CV = Population.cons;
                        CV = sum(max(0,CV(:,con)),2);
                        rf = sum(CV <= 1e-6) / Problem.N;
                        epsilon_0(con)  = max(epsilon_0(con),max(CV,[],1));
                        [epsilon_k,con] = update_epsilon(tao,epsilon_k,epsilon_0,rf,alpha,Problem.FE,Tc,cp,p,con,Cons_num,Problem,tempFE);
                    end
                    if epsilon_k ~= 0   
                            Offspring1 = Cauchy_II3(A,0,b,Problem);
                            if strategy ==1
                                Mating     = TournamentSelection(2,Problem.N,Fitness);
                                Offspring2 = OperatorGA(Problem,Population(Mating));
                            else
                                MatingPool = TournamentSelection(2,2*Problem.N,Fitness);
                                Offspring2 = OperatorDE(Problem,Population,Population(MatingPool(1:end/2)),Population(MatingPool(end/2+1:end)));
                            end
                            [Population,Fitness] = EnvironmentalSelection_epsilon([Population,Offspring2,Offspring1],Problem.N,epsilon_k,con);
                            A = EnvironmentalSelection([A,Offspring1,Offspring2],Problem.N);
                    else
                        if A_change == 0
                            [Population,Fitness] = EnvironmentalSelection_epsilon([Population,A],Problem.N,epsilon_k,con);
                            A_change = 1;
                        else
                            if strategy ==1
                                Mating     = TournamentSelection(2,Problem.N,Fitness);
                                Offspring2 = OperatorGA(Problem,Population(Mating));
                            else
                                MatingPool = TournamentSelection(2,2*Problem.N,Fitness);
                                Offspring2 = OperatorDE(Problem,Population,Population(MatingPool(1:end/2)),Population(MatingPool(end/2+1:end)));
                            end
                            [Population,Fitness] = EnvironmentalSelection_epsilon([Population,Offspring2],Problem.N,epsilon_k,con);
                        end
                    end
                end
                gen = gen + 1;
            end
        end
    end
end

function [result,con_num] = update_epsilon(tao,epsilon_k,epsilon_0,rf,alpha,FE,Tc,cp,p,con,Cons_num,Problem,tempFE)
    if rf < alpha && FE < Tc
        result  = (1-tao)*epsilon_k;
        con_num = con;
    elseif rf >= alpha && FE < Tc
        con_num = Calculate_p(Cons_num,p,Problem);
        result  = epsilon_0(con_num) * ((1 + ((FE-tempFE+1)/ Tc))) ^ cp;
    else
        result  = 0;
        con_num = con;
    end
end

function result = is_stable(Objvalues,gen,Population,N,change_threshold,M)
    result      = 0;
    [FrontNo,~] = NDSort(Population.objs,size(Population.objs,1));
    NC          = size(find(FrontNo==1),2);
    max_change  = abs(Objvalues(gen)-Objvalues(gen-1));
    if NC == N
        change_threshold = change_threshold * abs(((Objvalues(gen) / N))/(M))*10^(M-2);
        if max_change <= change_threshold
            result = 1;
        end
    end
end