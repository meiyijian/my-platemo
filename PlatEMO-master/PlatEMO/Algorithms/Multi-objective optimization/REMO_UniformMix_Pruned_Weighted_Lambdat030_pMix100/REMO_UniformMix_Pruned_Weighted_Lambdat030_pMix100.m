classdef REMO_UniformMix_Pruned_Weighted_Lambdat030_pMix100 < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Pruned quality filter plus a constant ambiguity reward (lambda_t = 0.30).
% The exploration branch keeps the relation-score quantile filter unchanged,
% then inside the retained set adds a reward on the predicted ambiguity:
%   A_t(x) = R~(x) + 0.30*U~(x)
% with U(x) = 1-mean(max(class probability)) exactly as in Original.
% The p_err gate, the minimum batch completion nMin and the second indicator
% filter are NOT restored. PAQC, candidate generation, nMax and every other
% setting stay identical to the pruned baseline.
%
% Copy of REMO_UniformMix_Pruned_Weighted_Lambdat030 with a single change: pMix is pinned
% to 1.00 as a fixed property of THIS algorithm instead of being
% exposed as a tunable parameter, so the parameter list is
% {gmax, rGood, qKeep, nMax}. Everything else - PAQC, the relation model,
% candidate generation, the indicator branch, lambda_t = 0.30, rGood,
% qKeep, nMax, RefSelect and the remaining-FE truncation - is untouched.
% gmax    --- 3000 --- Cumulative candidate-generation threshold
% pMix    --- 1.00 --- Indicator-selection probability (PINNED, not a parameter)
% rGood   --- 0.25 --- Proportion of solutions assigned to the positive group
% qKeep   --- 0.70 --- Quantile threshold for exploration relation scores
% nMax    --- 6    --- Maximum evaluation batch size

    methods
        function main(Algorithm,Problem)
            global ADAMAO_LAMBDAT030_DIAG
            if numel(Algorithm.parameter) > 4
                error('AdaMaO:InvalidParameterCount', ...
                    'Expected at most four parameters: gmax,rGood,qKeep,nMax.');
            end
            [gmax,rGood,qKeep,nMax] = ...
                Algorithm.ParameterSet(3000,0.25,0.70,6);
            % pMix is a fixed property of this variant, not a tunable knob.
            pMix = 1;
            validateUniformMixParameters( ...
                gmax,pMix,rGood,qKeep,nMax);

            % Diagnostics are collected in-process and never touch the RNG
            % stream, so enabling them cannot change the optimization path.
            ADAMAO_LAMBDAT030_DIAG = struct('enabled',true,'lambdaT',0.30, ...
                'records',{{}},'iterations',0,'rounds',0);

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
                ADAMAO_LAMBDAT030_DIAG.rounds = ADAMAO_LAMBDAT030_DIAG.rounds + 1;
                u = rand(modeStream,1);
                ratio = Problem.FE / Problem.maxFE;
                % PAQC: build the positive group, the non-positive group and
                % the reference solutions reused by the mating pool.
                k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                [~,~,Catalog,~,Ref] = PBIQualityClassification( ...
                    Population,ratio,'Nref',N,'k',k_eff, ...
                    'theta',5,'rGood',rGood);

                % Relation learning: ordered pairs from the two groups train
                % the three-class relation model.
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    warning('AdaMaO:NoRelationPairs', ...
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

                % CDIS: one complete criterion per round; exploration when the
                % indicator model is unavailable.
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
                % evaluate, using the quantile filter plus the reward.
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
                    warning('AdaMaO:NoNewCandidates', ...
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

function validateUniformMixParameters(gmax,pMix,rGood,qKeep,nMax)
%validateUniformMixParameters Check classification and batch parameters.
    if ~isnumeric(gmax) || ~isscalar(gmax) || ~isfinite(gmax) || ...
            gmax < 1 || gmax ~= floor(gmax)
        error('AdaMaO:InvalidParameter', ...
            'gmax must be a positive integer.');
    end
    if ~isnumeric(pMix) || ~isscalar(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('AdaMaO:InvalidParameter', ...
            'pMix must be in [0,1].');
    end
    if ~isnumeric(rGood) || ~isscalar(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('AdaMaO:InvalidParameter', ...
            'rGood must be in (0,0.5].');
    end
    if ~isnumeric(qKeep) || ~isscalar(qKeep) || ~isfinite(qKeep) || ...
            qKeep < 0 || qKeep > 1
        error('AdaMaO:InvalidParameter', ...
            'qKeep must be in [0,1].');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('AdaMaO:InvalidParameter', ...
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
