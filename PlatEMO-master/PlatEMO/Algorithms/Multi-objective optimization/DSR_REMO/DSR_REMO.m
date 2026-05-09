classdef DSR_REMO < ALGORITHM
% <2025> <multi/many> <real> <expensive>
% Dual-Space Regularized REMO: Expensive multiobjective optimization by 
% SDE-based screening and SDR-based relation learning
%
% Parameters:
%   gmax --- 3000 --- Number of solutions evaluated by surrogate model
%
% Algorithm Description:
%   DSR_REMO implements a novel dual-space regularization approach:
%   1. SDE (Shift-based Density Estimation) for sample screening:
%      - Select top 25% as Elite pool, bottom 25% as Poor pool
%      - Discard middle 50% to obtain purer training data
%   2. SDR (Strengthened Dominance Relation) for label generation:
%      - Generate ONLY EP/PE pairwise labels (no EE/PP pairs)
%      - Labels: +1 (x dominates y), -1 (y dominates x), 0 (non-dominated)
%   3. Train lightweight neural network for relation prediction
%   4. Dual-Space Regularization for candidate selection:
%      - Extract spatial prior from SDR non-dominated solutions
%      - Compute Mahalanobis distance and position weight W_pos
%      - Final score: S_final = S_model * W_pos
%
% Reference:
%   Based on REMO (Hao et al., IEEE TEVC 2022), PC-SAEA (Tian et al., 
%   Swarm and Evolutionary Computation 2023), and PIEA (Li et al., 
%   Information Sciences 2024).
%
% Copyright (c) 2025 BIMK Group.

    methods
        function main(Algorithm, Problem)
            %% Parameter setting
            gmax = Algorithm.ParameterSet(3000);

            %% Initialize the population by Latin hypercube sampling
            if Problem.D <= 10
                N = 11 * Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper - Problem.lower, N, 1) .* PopDec + repmat(Problem.lower, N, 1));
            Archive = Population;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                % Prepare training data using SDE screening and SDR labeling
                [TrainIn, TrainOut, Elite, ~] = PrepareTrainingData(Archive);
                
                % Skip if insufficient training data or Elite is empty
                if isempty(TrainIn) || size(TrainIn, 1) < 10 || isempty(Elite)
                    Population = EnvironmentalSelection(Archive, Problem.N);
                    continue;
                end
                
                % Data processing: split into train and test sets
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(TrainIn, TrainOut);
                
                if isempty(TrainIn) || size(TrainIn, 1) < 5
                    Population = EnvironmentalSelection(Archive, Problem.N);
                    continue;
                end
                
                xDim = size(TrainIn, 2);
                
                % Train relation model
                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut, 1);
                
                hidden1 = ceil(xDim * 1.5);
                hidden2 = xDim * 1;
                hidden3 = ceil(xDim / 2);
                net = patternnet([hidden1, hidden2, hidden3]);
                net.trainParam.showWindow = 0;
                net = train(net, TrainIn_nor', TrainOut_onehot');
                
                % Calculate prediction error on test set
                if ~isempty(TestIn)
                    TestIn_nor = mapminmax('apply', TestIn', TrainIn_struct)';
                    TestPre = onehotconv(net(TestIn_nor')', 2);
                    p_err = sum(TestPre ~= TestOut) / size(TestPre, 1);
                else
                    p_err = 1;
                end
                
                % Store model information
                Smodel.X = Archive.decs;
                Smodel.Y = zeros(size(Archive, 1), 1);
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;
                
                % Surrogate-assisted selection with dual-space regularization
                Next = SurrogateAssistedSelection(Problem, Archive, Population.decs, gmax, Smodel, Elite);
                
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end
                
                % Update population for next iteration using environmental selection
                Population = EnvironmentalSelection(Archive, Problem.N);
            end
        end
    end
end
