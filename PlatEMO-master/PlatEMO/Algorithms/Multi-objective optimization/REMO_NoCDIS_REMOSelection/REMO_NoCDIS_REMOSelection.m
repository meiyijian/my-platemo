classdef REMO_NoCDIS_REMOSelection < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% PAQC with the original local REMO candidate module in place of full CDIS.
% Both CDIS criteria and their mode switch are absent. The private copy of
% REMO/RSurrogateAssistedSelection.m is byte-identical to its source snapshot.
% PAQC, relation training, initialization and archive/environmental selection
% come from REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist.
% The host keeps nMax and remaining-FE truncation. If REMO returns more than
% nMax rows, their original order is preserved when taking the first nMax.
% gmax  --- 3000 --- REMO inner generation counter threshold
% rGood --- 0.25 --- Proportion assigned to the PAQC positive group
% nMax  ---    6 --- Maximum real-evaluation batch size

    methods
        function main(Algorithm,Problem)
            if numel(Algorithm.parameter) > 3
                error('REMO_NoCDIS_REMOSelection:InvalidParameterCount', ...
                    'Expected at most three parameters: gmax,rGood,nMax.');
            end
            [gmax,rGood,nMax] = Algorithm.ParameterSet(3000,0.25,6);
            validateParameters(gmax,rGood,nMax);

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            N = min(N,max(0,floor(Problem.maxFE - Problem.FE)));
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive = Population;

            while Algorithm.NotTerminated(Archive)
                ratio = Problem.FE / Problem.maxFE;
                k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                [~,~,Catalog,~,Ref] = PBIQualityClassification( ...
                    Population,ratio,'Nref',N,'k',k_eff, ...
                    'theta',5,'rGood',rGood);

                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    warning('REMO_NoCDIS_REMOSelection:NoRelationPairs', ...
                        'No relation training pairs are available; stopping.');
                    break;
                end
                [net,TrainIn_struct] = TrainOriginalRelationModel(XXs,YYs);

                Smodel = struct();
                Smodel.X = Input;
                Smodel.Y = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;

                % Full CDIS is replaced by the original REMO module:
                % no accumulated pool, confidence weighting, ambiguity
                % reward, quantile screen, indicator model or mode switch.
                Next = RSurrogateAssistedSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = unique(Next,'rows','stable');
                    Next = Next(1:min(nMax,size(Next,1)),:);
                end
                if isempty(Next) && remain > 0
                    warning('REMO_NoCDIS_REMOSelection:NoNewCandidates', ...
                        'No candidate is available; stopping.');
                    break;
                end
                if ~isempty(Next) && remain > 0
                    % Original REMO can return a variable-size batch. Apply
                    % the Full host's cap here without modifying its selector.
                    Next = Next(1:min([nMax,size(Next,1),remain]),:);
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                end
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

function validateParameters(gmax,rGood,nMax)
%validateParameters Check the retained Full parameters.
    if ~isnumeric(gmax) || ~isscalar(gmax) || ~isfinite(gmax) || ...
            gmax < 1 || gmax ~= floor(gmax)
        error('REMO_NoCDIS_REMOSelection:InvalidParameter', ...
            'gmax must be a positive integer.');
    end
    if ~isnumeric(rGood) || ~isscalar(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('REMO_NoCDIS_REMOSelection:InvalidParameter', ...
            'rGood must be in (0,0.5].');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('REMO_NoCDIS_REMOSelection:InvalidParameter', ...
            'nMax must be a positive integer.');
    end
end

function [net,TrainIn_struct] = TrainOriginalRelationModel(XXs,YYs)
%TrainOriginalRelationModel Keep Full's data split and network topology.
    [TrainIn,TrainOut] = DataProcess(XXs,YYs);
    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);
    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,TrainIn_nor',TrainOut_onehot');
end
