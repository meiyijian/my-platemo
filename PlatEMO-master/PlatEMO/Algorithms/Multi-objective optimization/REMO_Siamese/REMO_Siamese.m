classdef REMO_Siamese < ALGORITHM
% <2022> <multi/many> <real> <expensive>
% Expensive multiobjective optimization by Siamese relation learning
% k    ---    6 --- Number of reference solutions
% gmax --- 3000 --- Number of solutions evaluated by surrogate model

%------------------------------- Reference --------------------------------
% H. Hao, A. Zhou, H. Qian, and H. Zhang. Expensive multiobjective
% optimization by relation learning and prediction. IEEE Transactions on
% Evolutionary Computation, 2022, 26(5): 1157-1170.
% Modified: Using Siamese Network for relation learning
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. All rights reserved.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [k,gmax] = Algorithm.ParameterSet(6,3000);

            %% Initialize the population by Latin hypercube sampling
            if Problem.D <= 10
                N = 11*Problem.D-1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec+repmat(Problem.lower,N,1));
            Archive    = Population;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                % Step 1: Select reference solutions
                Ref       = RefSelect(Population,k);
                Input     = Population.decs;
                % Step 2: Classify solutions using PBI method
                Catalog   = GetOutput_PBI(Population.objs,Ref.objs);
                % Step 3: Build relation pairs for Siamese network
                [Input1,Input2,Labels] = SiameseRelationPairs(Input,Catalog);
                % Step 4: Split data into training and test sets
                [TrainIn1,TrainIn2,TrainOut,TestIn1,TestIn2,TestOut] = SiameseDataProcess(Input1,Input2,Labels);
                xDim = size(TrainIn1,2);

                % Step 5: Train Siamese network
                [net,trainInfo] = SiameseModelTrain(TrainIn1,TrainIn2,TrainOut,xDim);

                % Step 6: Evaluate on test set
                TestPre = SiameseModelPredict(net,TestIn1,TestIn2);
                p_err   = sum(TestPre ~= TestOut)/size(TestPre,1);

                % Step 7: Pack model
                Smodel.X       = Input;
                Smodel.Y       = Catalog;
                Smodel.net     = net;
                Smodel.p_err   = p_err;
                Smodel.xDim    = xDim;

                % Step 8: Generate new solutions using surrogate-assisted selection
                Next = SiameseAssistedSelection(Problem,Ref,Population.decs,gmax,Smodel);
                if ~isempty(Next)
                    Archive = [Archive,Problem.Evaluation(Next)];
                end
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end
