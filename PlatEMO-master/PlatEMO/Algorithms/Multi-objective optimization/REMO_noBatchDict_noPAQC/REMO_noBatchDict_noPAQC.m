classdef REMO_noBatchDict_noPAQC < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Ablation variant of REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist:
% the PAQC classification module is removed and replaced by the original
% REMO PBI classification GetOutput_PBI. The positive group is no longer
% forced to a fixed rGood quota; it is the set of solutions whose normalized
% PBI value against a selected reference solution does not exceed 1.
% Everything else stays identical to NoBatchDist: the full CDIS candidate
% selection (SDE indicator model, explore/indicator mode switch and
% DiversifiedInfillSelection), the exploration criterion with the constant
% 0.30 ambiguity reward, and the absent in-batch distance term.
% The reference-solution count stays k = min(N,max(6,ceil(1.5*M))).
% gmax   --- 3000 --- Cumulative candidate-generation threshold
% pMix   --- 0.50 --- Indicator-selection probability when available
% qKeep  --- 0.70 --- Quantile threshold for exploration relation scores
% nMax   ---    6 --- Maximum evaluation batch size

    methods
        function main(Algorithm,Problem)
            global ADAMAO_NOBATCHDIST_DIAG
            if numel(Algorithm.parameter) > 4
                error('REMO_noBatchDict_noPAQC:InvalidParameterCount', ...
                    'Expected at most four parameters: gmax,pMix,qKeep,nMax.');
            end
            [gmax,pMix,qKeep,nMax] = ...
                Algorithm.ParameterSet(3000,0.50,0.70,6);
            validateNoPaqcCdisParameters(gmax,pMix,qKeep,nMax);

            % Diagnostics are collected in-process and never touch the RNG
            % stream, so enabling them cannot change the optimization path.
            ADAMAO_NOBATCHDIST_DIAG = struct('enabled',true,'lambdaT',0.30, ...
                'distWeight',0.00,'records',{{}},'iterations',0,'rounds',0);

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            N = min(N,max(0,floor(Problem.maxFE - Problem.FE)));
            % Initial design: Latin hypercube sampling with real evaluations.
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive = Population;

            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp = 1;

            while Algorithm.NotTerminated(Archive)
                ADAMAO_NOBATCHDIST_DIAG.rounds = ADAMAO_NOBATCHDIST_DIAG.rounds + 1;
                u = rand(modeStream,1);
                % Original REMO classification (PAQC removed): select the
                % reference solutions and classify against them with PBI.
                k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                Ref = RefSelect(Population,k_eff);
                Catalog = GetOutput_PBI(Population.objs,Ref.objs);

                % Relation learning: ordered pairs from the two groups train
                % the three-class relation model.
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    warning('REMO_noBatchDict_noPAQC:NoRelationPairs', ...
                        'No relation training pairs are available; stopping.');
                    break;
                end

                [net,TrainIn_struct] = ...
                    TrainOriginalRelationModel(XXs,YYs);

                % Indicator learning: RBF-SVR on the evaluated SDE metrics.
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

                % CDIS: one complete criterion per round; exploration when
                % the indicator model is unavailable.
                candidate_mode = ResolveUniformMixMode( ...
                    ~isempty(IndicatorModel),u,pMix);

                Smodel = struct();
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode = candidate_mode;

                % Accumulate candidates and return the ordered batch to
                % evaluate (exploration quantile filter + reward, or the
                % indicator branch).
                Next = DiversifiedInfillSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel, ...
                    qKeep,nMax);

                % Truncate the batch by the remaining budget; if the pool is
                % empty, add candidates by genetic variation.
                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = unique(Next,'rows','stable');
                    Next = Next(1:min(nMax,size(Next,1)),:);
                end

                if isempty(Next) && remain > 0
                    warning('REMO_noBatchDict_noPAQC:NoNewCandidates', ...
                        'No candidate is available; stopping.');
                    break;
                end
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                end
                % Environment selection over the cumulative archive.
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

function validateNoPaqcCdisParameters(gmax,pMix,qKeep,nMax)
%validateNoPaqcCdisParameters Check the classification and batch parameters.
    if ~isnumeric(gmax) || ~isscalar(gmax) || ~isfinite(gmax) || ...
            gmax < 1 || gmax ~= floor(gmax)
        error('REMO_noBatchDict_noPAQC:InvalidParameter', ...
            'gmax must be a positive integer.');
    end
    if ~isnumeric(pMix) || ~isscalar(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('REMO_noBatchDict_noPAQC:InvalidParameter', ...
            'pMix must be in [0,1].');
    end
    if ~isnumeric(qKeep) || ~isscalar(qKeep) || ~isfinite(qKeep) || ...
            qKeep < 0 || qKeep > 1
        error('REMO_noBatchDict_noPAQC:InvalidParameter', ...
            'qKeep must be in [0,1].');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('REMO_noBatchDict_noPAQC:InvalidParameter', ...
            'nMax must be a positive integer.');
    end
end

function [net,TrainIn_struct] = TrainOriginalRelationModel(XXs,YYs)
%TrainOriginalRelationModel Keep the original split and network topology.
    [TrainIn,TrainOut] = DataProcess(XXs,YYs);
    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,TrainIn_nor',TrainOut_onehot');

end
