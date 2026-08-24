classdef REMO_UniformMixCandidate < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Expensive multiobjective optimization: the original REMO relation-learning
% framework with the UniformMix candidate-selection module.
%
% The framework part (population initialization, reference-solution selection
% via RefSelect, PBI classification via GetOutput_PBI, relation-pair
% construction via GetRelationPairs, and relation-network training) is
% inherited UNCHANGED from the original REMO.
%
% The ONLY modification is the candidate-solution module: the original
% RSurrogateAssistedSelection is replaced by AdaMaOSelection, which routes
% candidate selection through the UniformMix modes ('conservative' /
% 'explore' / 'indicator') and uses the SDE-only indicator
% (IndicatorSelectorSDEOnly) for the indicator branch.
%
% Parameters:
% k       ---    6 --- Number of reference solutions
% gmax    --- 3000 --- Maximum surrogate-assisted training generations
% pMix    --- 0.50 --- Probability of indicator-based selection
% qKeep   --- 0.80 --- Quantile retained during exploratory selection
% lambda0 --- 0.35 --- Initial exploration strength
% nMin    ---    4 --- Minimum number of candidate solutions
% nMax    ---    6 --- Maximum number of candidate solutions

%------------------------------- Reference --------------------------------
% H. Hao, A. Zhou, H. Qian, and H. Zhang. Expensive multiobjective
% optimization by relation learning and prediction. IEEE Transactions on
% Evolutionary Computation, 2022, 26(5): 1157-1170.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [k,gmax,pMix,qKeep,lambda0,nMin,nMax] = ...
                Algorithm.ParameterSet(6,3000,0.50,0.80,0.35,4,6);
            validateUniformMixCandidateParameters( ...
                gmax,pMix,qKeep,lambda0,nMin,nMax);

            %% Initialize the population (unchanged from REMO)
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive    = Population;

            %% Candidate-module state
            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp = 1;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                % --- Relation-learning framework (unchanged from REMO) ---
                Ref       = RefSelect(Population,k);
                Input     = Population.decs;
                Catalog   = GetOutput_PBI(Population.objs,Ref.objs);
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
                xDim = size(TrainIn,2);

                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor     = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut,1);
                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
                net.trainParam.showWindow = 0;
                net = train(net,TrainIn_nor',TrainOut_onehot');
                TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                TestPre    = onehotconv(net(TestIn_nor')',2);
                p_err      = sum(TestPre ~= TestOut)/size(TestPre,1);

                % --- Candidate module (from UniformMix candidate selection) ---
                u     = rand(modeStream,1);
                ratio = Problem.FE / Problem.maxFE;

                IndicatorModel = [];
                try
                    [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp);
                catch
                    Fitness = [];
                end
                if ~isempty(Fitness)
                    try
                        IndicatorModel = fitrsvm(Population.decs,Fitness, ...
                            'KernelFunction','rbf', ...
                            'KernelScale','auto','Standardize',true);
                    catch
                        IndicatorModel = [];
                    end
                end

                candidate_mode = ResolveUniformMixMode( ...
                    ~isempty(IndicatorModel),u,pMix);

                Smodel = struct();
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;
                Smodel.lambda0 = lambda0;
                Smodel.ratio = ratio;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode = candidate_mode;
                Smodel.q_keep = qKeep;
                Smodel.n_min = nMin;
                Smodel.n_max = nMax;

                Next = AdaMaOSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel, ...
                    qKeep,nMin,nMax);

                % --- Evaluation & environment selection (unchanged from REMO) ---
                if ~isempty(Next)
                    Archive = [Archive,Problem.Evaluation(Next)]; %#ok<AGROW>
                end
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

function validateUniformMixCandidateParameters(gmax,pMix,qKeep,lambda0,nMin,nMax)
%validateUniformMixCandidateParameters Validate candidate-module parameters.
    if ~isnumeric(gmax) || ~isscalar(gmax) || ~isfinite(gmax) || ...
            gmax < 1 || gmax ~= floor(gmax)
        error('REMO_UniformMixCandidate:InvalidParameter', ...
            'gmax must be a positive integer.');
    end
    if ~isnumeric(pMix) || ~isscalar(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('REMO_UniformMixCandidate:InvalidParameter', ...
            'pMix must be in [0,1].');
    end
    if ~isnumeric(qKeep) || ~isscalar(qKeep) || ~isfinite(qKeep) || ...
            qKeep < 0 || qKeep > 1
        error('REMO_UniformMixCandidate:InvalidParameter', ...
            'qKeep must be in [0,1].');
    end
    if ~isnumeric(lambda0) || ~isscalar(lambda0) || ~isfinite(lambda0) || ...
            lambda0 < 0
        error('REMO_UniformMixCandidate:InvalidParameter', ...
            'lambda0 must be nonnegative.');
    end
    if ~isnumeric(nMin) || ~isscalar(nMin) || ~isfinite(nMin) || ...
            nMin < 1 || nMin ~= floor(nMin)
        error('REMO_UniformMixCandidate:InvalidParameter', ...
            'nMin must be a positive integer.');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('REMO_UniformMixCandidate:InvalidParameter', ...
            'nMax must be a positive integer.');
    end
    if nMin > nMax
        error('REMO_UniformMixCandidate:InvalidParameter', ...
            'nMin must not exceed nMax.');
    end
end
