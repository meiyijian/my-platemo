classdef CA_REMO < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Confidence-aware relation learning for expensive many-objective optimization
% k         ---    6 --- Number of reference solutions
% gmax      --- 3000 --- Number of candidate solutions evaluated by the surrogate
% confRatio --- 0.35 --- Ratio of high-confidence samples kept in each class
% delta     --- 0.65 --- Reliability threshold for using the relation model
% divWeight --- 0.05 --- Diversity bonus weight in surrogate-assisted selection
%
% This algorithm keeps the main REMO framework and adds three mechanisms:
% 1) PBI-margin confidence for each class label.
% 2) Confidence-balanced relation pair generation and sample weighting.
% 3) Reliability-aware model management before surrogate-assisted selection.

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [k,gmax,confRatio,delta,divWeight] = Algorithm.ParameterSet(6,3000,0.35,0.65,0.05);

            %% Initialize the population by Latin hypercube sampling
            if Problem.D <= 10
                N = max(11*Problem.D-1,Problem.N);
            else
                N = max(100,Problem.N);
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec + repmat(Problem.lower,N,1));
            Archive    = Population;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                % Select representative reference solutions as REMO does.
                Ref   = CARefSelect(Population,k);
                Input = Population.decs;

                % Partition the population and estimate the confidence of labels.
                [Catalog,Confidence,Margin] = CAPBIConfidence(Population.objs,Ref.objs);

                % Build confidence-filtered relation pairs.
                [XXs,YYs,WWs,PairInfo] = CARelationPairs(Input,Catalog,Confidence,confRatio);

                % Split relation pairs into training and validation subsets.
                [TrainIn,TrainOut,TrainW,ValidIn,ValidOut,ValidW] = CADataProcess(XXs,YYs,WWs);
                xDim = size(TrainIn,2);

                % Train a three-class relation model.
                [TrainInNor,TrainStruct] = mapminmax(TrainIn');
                TrainInNor = TrainInNor';
                TrainOutOnehot = CAOneHot(TrainOut,1);

                % High-confidence pairs should be easier to separate, so a
                % compact network is preferred for expensive optimization.
                net = patternnet([max(4,ceil(xDim/2)),max(3,ceil(xDim/4))]);
                net.divideFcn = 'dividetrain';
                net.trainParam.showWindow = 0;
                net.trainParam.epochs     = 50;
                net.trainParam.max_fail   = 6;
                net.trainParam.min_grad   = 1e-5;

                % MATLAB neural networks accept error weights with the same
                % output-by-sample layout as the target matrix.
                EW = TrainW(:)';
                if mean(EW) > 1e-12
                    EW = EW./mean(EW);
                else
                    EW = ones(size(EW));
                end
                EW  = repmat(max(EW,0.05),size(TrainOutOnehot,2),1);
                net = train(net,TrainInNor',TrainOutOnehot',[],[],EW);

                % Validate the model. A stable reversed model still contains
                % useful order information, while an unreliable model is gated.
                ValidInNor = mapminmax('apply',ValidIn',TrainStruct)';
                ValidProb  = net(ValidInNor')';
                ValidPre   = CAOneHot(ValidProb,2);
                [mode,reliability,validAcc,reverseAcc] = CAReliability(ValidPre,ValidOut,ValidW,delta);

                % Pack the surrogate model and high-confidence anchors.
                Smodel.X            = Input;
                Smodel.Y            = Catalog;
                Smodel.confidence   = Confidence;
                Smodel.margin       = Margin;
                Smodel.anchorGood   = Input(PairInfo.goodIndex,:);
                Smodel.anchorBad    = Input(PairInfo.badIndex,:);
                Smodel.mp_struct    = TrainStruct;
                Smodel.net          = net;
                Smodel.mode         = mode;
                Smodel.reliability  = reliability;
                Smodel.validAcc     = validAcc;
                Smodel.reverseAcc   = reverseAcc;

                % Search and screen promising candidates by confidence-aware RS.
                Next = CASurrogateSelection(Problem,Ref,Input,gmax,Smodel,divWeight);
                if ~isempty(Next)
                    Archive = [Archive,Problem.Evaluation(Next)]; %#ok<AGROW>
                end

                % Update the population from all real-evaluated solutions.
                Population = CARefSelect(Archive,Problem.N);
            end
        end
    end
end
