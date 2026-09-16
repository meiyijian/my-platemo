classdef RMEO_k_CDIS < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% The original REMO relation-learning framework with the CDIS candidate
% selection module of REMO_UniformMix_Pruned_Weighted_Lambdat030, and with
% k = min(N,max(6,ceil(1.5*M))) reference solutions instead of the fixed
% k = 6 of the REMO paper (M=10 -> 15, M=20 -> 30).
%
% The framework part is inherited unchanged from the original REMO:
% population initialization, reference-solution selection (RefSelect), PBI
% classification of the population against the reference solutions
% (GetOutput_PBI), relation-pair construction (GetRelationPairs),
% relation-network training and environment selection over the archive.
%
% The ONLY modification is the candidate-solution module: the original
% RSurrogateAssistedSelection is replaced by the CDIS module, that is
% ResolveUniformMixMode selecting one complete criterion per round plus
% DiversifiedInfillSelection. The exploration criterion uses
% Lambdat030WeightedBatchSelection (relation-score quantile filter plus a
% fixed 0.30 ambiguity reward, then a 0.75/0.25 score/distance greedy batch);
% the indicator criterion uses PrunedIndicatorSelection driven by the
% SDE-only indicator model trained with IndicatorSelectorSDEOnly.
%
% PAQC is NOT used: the positive group comes from the reference-solution PBI
% classification of REMO, so its size is not forced to a 25 percent quota.
%
% gmax  --- 3000 --- Cumulative candidate-generation threshold
% pMix  --- 0.50 --- Indicator-selection probability when available
% qKeep --- 0.70 --- Quantile threshold for exploration relation scores
% nMax  ---    6 --- Maximum evaluation batch size

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
            [gmax,pMix,qKeep,nMax] = Algorithm.ParameterSet(3000,0.50,0.70,6);
            validateCdisParameters(gmax,pMix,qKeep,nMax);

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

            %% CDIS state
            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp         = 1;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                % --- Relation-learning framework (unchanged from REMO) ---
                % The only deviation is the number of reference solutions:
                % k scales with the number of objectives instead of being 6.
                k         = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                Ref       = RefSelect(Population,k);
                Input     = Population.decs;
                Catalog   = GetOutput_PBI(Population.objs,Ref.objs);
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    warning('RMEO_k_CDIS:NoRelationPairs', ...
                        'No relation training pairs are available; stopping.');
                    break;
                end
                [TrainIn,TrainOut] = DataProcess(XXs,YYs);
                xDim = size(TrainIn,2);

                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor     = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut,1);
                net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
                net.trainParam.showWindow = 0;
                net = train(net,TrainIn_nor',TrainOut_onehot');

                % --- CDIS candidate-selection module ---
                % One complete criterion per round; exploration is used while
                % the indicator model is unavailable.
                u = rand(modeStream,1);

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
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode = candidate_mode;

                Next = DiversifiedInfillSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel,qKeep,nMax);

                % --- Batch completion, evaluation and environment selection ---
                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = unique(Next,'rows','stable');
                    Next = Next(1:min(nMax,size(Next,1)),:);
                end
                if isempty(Next) && remain > 0
                    warning('RMEO_k_CDIS:NoNewCandidates', ...
                        'No candidate is available; stopping.');
                    break;
                end
                if ~isempty(Next) && remain > 0
                    Next    = Next(1:min(size(Next,1),remain),:);
                    Archive = [Archive,Problem.Evaluation(Next)]; %#ok<AGROW>
                end
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

function validateCdisParameters(gmax,pMix,qKeep,nMax)
%validateCdisParameters Check the CDIS module parameters.
    if ~isnumeric(gmax) || ~isscalar(gmax) || ~isfinite(gmax) || ...
            gmax < 1 || gmax ~= floor(gmax)
        error('RMEO_k_CDIS:InvalidParameter', ...
            'gmax must be a positive integer.');
    end
    if ~isnumeric(pMix) || ~isscalar(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('RMEO_k_CDIS:InvalidParameter', ...
            'pMix must be in [0,1].');
    end
    if ~isnumeric(qKeep) || ~isscalar(qKeep) || ~isfinite(qKeep) || ...
            qKeep < 0 || qKeep > 1
        error('RMEO_k_CDIS:InvalidParameter', ...
            'qKeep must be in [0,1].');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('RMEO_k_CDIS:InvalidParameter', ...
            'nMax must be a positive integer.');
    end
end
