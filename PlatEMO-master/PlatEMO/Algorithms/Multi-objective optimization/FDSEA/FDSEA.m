classdef FDSEA < ALGORITHM
% <2026> <multi> <real/integer> <large/none>
% Frequency domain search-based evolutionary algorithm
% K        --- 5 --- The number of frequency-domain series retention levels        
% operator --- 1 --- The evolution operator: GA 1 and DE 2

%------------------------------- Reference --------------------------------
% W. Wang, Z. Tan, Y. Wang, and W. Zhang. Enhancing the scalability of
% large-scale multi-objective evolutionary algorithm through frequency
% domain search. Swarm and Evolutionary Computation, 2026, 106: 102423.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Wenxiang Wang (email: wwx_cmcc@qq.com)

    methods
        function main(Algorithm,Problem)
            %% Parameter settings
            D             = Problem.D;
            [Z,Problem.N] = UniformPoint(Problem.N,Problem.M);
            N             = Problem.N;
            lower         = Problem.lower;
            upper         = Problem.upper;
            [K,operator]  = Algorithm.ParameterSet(5, 1);
            gama          = 0.5;
       
            %% Initialization
            ModelParemeters = unifrnd(0,1,N,2*K+2);
            Dec             = Cal_Dec(ModelParemeters,N,D);
            Population1Dec  = (upper - lower).* Dec + lower;
            Population1     = Problem.Evaluation(Population1Dec, ModelParemeters);
            Zmin1           = min(Population1(all(Population1.cons<=0,2)).objs,[],1);
            Population2     = Problem.Initialization();
            Zmin2           = min(Population1(all(Population2.cons<=0,2)).objs,[],1);
            Zmin            = min(Zmin1,Zmin2);
            Population      = EnvironmentalSelection([Population1, Population2],Problem.N,Z,Zmin);
            
            %% Optimization
            while Algorithm.NotTerminated(Population)
                if operator == 1
                    MatingPool      = TournamentSelection(2,N,sum(max(0,Population1.cons),2));
                    ModelParemeters = FRGA(Population1(MatingPool));
                elseif operator == 2
                    MatingPool1     = TournamentSelection(2,N,sum(max(0,Population1.cons),2));
                    MatingPool2     = TournamentSelection(2,N,sum(max(0,Population1.cons),2));
                    MatingPool3     = TournamentSelection(2,N,sum(max(0,Population1.cons),2));
                    ModelParemeters = FRDE(Problem,Population1(MatingPool1),Population1(MatingPool2),Population1(MatingPool3));
                end
                [N_off, ~] = size(ModelParemeters);

                Dec           = Cal_Dec(ModelParemeters,N_off,D);
                OffspringDec  = (upper - lower).* Dec + lower;
                NewIndividual = Problem.Evaluation(OffspringDec, ModelParemeters);

                Population1 = EnvironmentalSelection([Population1, NewIndividual],Problem.N,Z,Zmin1);
                Zmin1       = min(Population1(all(Population1.cons<=0,2)).objs,[],1);

                [Population2,Offspring2] = OperatorHybrid(Problem,Population2,gama);
                Population2 = EnvironmentalSelection([Population2, Offspring2],Problem.N,Z,Zmin2);
                Zmin2       = min(Population2(all(Population2.cons<=0,2)).objs,[],1);
                gama        = AutoUpdate(gama,Population2);

                Index_size = 10;
                Index      = randi([1,N],1,Index_size);
                for i = 1 : Index_size
                    k              = Index(i);
                    Population2(k) = Cal_MP(Population2(k),K);
                    PX             = Population1(k);
                    Population1(k) = Population2(k);
                    Population2(k) = PX;
                end
                
                Zmin       = min(Zmin1,Zmin2);
                Population = EnvironmentalSelection([Population1, Population2],Problem.N,Z,Zmin);
            end
        end
    end
end