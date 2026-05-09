classdef REMO_global_SDE < ALGORITHM
% <2025> <multi/many> <real> <expensive>
% REMO_global_SDE: REMO with fused global reference vector and SDE scoring
% Ablation study: Combines score_v and SDE scores, no label_dyn

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [k,gmax] = Algorithm.ParameterSet(6,3000);

            %% Initialize population
            if Problem.D <= 10
                N = 11*Problem.D-1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec+repmat(Problem.lower,N,1));
            Archive    = Population;

            %% Optimization
            t = 1;
            while Algorithm.NotTerminated(Archive)
                ratio = Problem.FE / Problem.maxFE;
                
                % Fused classification: score_v + SDE
                [good_idx, bad_idx, Catalog, ~, Ref] = HybridPBI_Classification(...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);
                
                % Get training pairs
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input, Catalog);
                
                % Data split
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
                xDim = size(TrainIn,2);
                
                % Train neural network
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut,1);
                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
                net.trainParam.showWindow =0;
                net = train(net,TrainIn_nor',TrainOut_onehot');
                TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                TestPre = onehotconv(net(TestIn_nor')',2);
                p_err = sum(TestPre ~= TestOut)/size(TestPre,1);
                
                % Model struct
                Smodel.X   = Input;
                Smodel.Y   = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;
                
                % Surrogate-assisted selection
                Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel);
                
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end
                
                Population = RefSelect(Archive, Problem.N);
                t = t + 1;
            end
        end
    end
end
