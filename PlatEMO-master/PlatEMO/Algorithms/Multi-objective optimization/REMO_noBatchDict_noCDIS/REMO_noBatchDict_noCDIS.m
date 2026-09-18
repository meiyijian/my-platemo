classdef REMO_noBatchDict_noCDIS < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Ablation variant of REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist:
% the CDIS candidate-selection module is removed. Concretely, the SDE
% indicator model (IndicatorSelectorSDEOnly + fitrsvm), the explore/indicator
% mode switch (ResolveUniformMixMode) and the indicator branch
% (PrunedIndicatorSelection) are deleted, so every round selects candidates by
% the exploration criterion alone:
%   A_t(x) = R~(x) + 0.30*U~(x),
% the relation-score quantile filter plus the constant ambiguity reward.
% The in-batch distance term is already absent (NoBatchDist), so the batch is
% the descending-A_t order of the retained set.
% PAQC is unchanged: the positive group is still built by
% PBIQualityClassification with a forced rGood quota, and the reference
% solutions are reused as the mating pool.
% gmax   --- 3000 --- Cumulative candidate-generation threshold
% rGood  --- 0.25 --- Proportion of solutions assigned to the positive group
% qKeep  --- 0.70 --- Quantile threshold for exploration relation scores
% nMax   ---    6 --- Maximum evaluation batch size

    methods
        function main(Algorithm,Problem)
            [gmax,rGood,qKeep,nMax] = ...
                Algorithm.ParameterSet(3000,0.25,0.70,6);
            validateNoCdisParameters(gmax,rGood,qKeep,nMax);

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

            while Algorithm.NotTerminated(Archive)
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
                    warning('REMO_noBatchDict_noCDIS:NoRelationPairs', ...
                        'No relation training pairs are available; stopping.');
                    break;
                end

                [net,TrainIn_struct] = ...
                    TrainOriginalRelationModel(XXs,YYs);

                % Exploration-only candidate selection (CDIS removed): no
                % indicator model, no mode switch; mode is fixed to explore.
                Smodel = struct();
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.mode = 'explore';

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
                    warning('REMO_noBatchDict_noCDIS:NoNewCandidates', ...
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

function validateNoCdisParameters(gmax,rGood,qKeep,nMax)
%validateNoCdisParameters Check the classification and batch parameters.
    if ~isnumeric(gmax) || ~isscalar(gmax) || ~isfinite(gmax) || ...
            gmax < 1 || gmax ~= floor(gmax)
        error('REMO_noBatchDict_noCDIS:InvalidParameter', ...
            'gmax must be a positive integer.');
    end
    if ~isnumeric(rGood) || ~isscalar(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('REMO_noBatchDict_noCDIS:InvalidParameter', ...
            'rGood must be in (0,0.5].');
    end
    if ~isnumeric(qKeep) || ~isscalar(qKeep) || ~isfinite(qKeep) || ...
            qKeep < 0 || qKeep > 1
        error('REMO_noBatchDict_noCDIS:InvalidParameter', ...
            'qKeep must be in [0,1].');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('REMO_noBatchDict_noCDIS:InvalidParameter', ...
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
