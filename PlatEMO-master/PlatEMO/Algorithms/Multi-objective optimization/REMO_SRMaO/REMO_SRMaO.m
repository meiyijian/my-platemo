classdef REMO_SRMaO < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% State-aware relation surrogate-assisted many-objective optimization.
%
% REMO_SRMaO is a clean experimental successor of REMO_new2_AdaMaO.  It
% keeps the relation-learning backbone, but uses APD/SDE state labels,
% binary pairwise preferences, a lightweight ensemble surrogate, continuous
% state-aware acquisition weights, and APD environmental selection.

    methods
        function main(Algorithm, Problem)
            %% Parameter setting
            % k        : number of reference solutions used by the inner GA
            % gmax     : maximum number of surrogate-screened candidates
            % K        : number of relation models in the ensemble
            % q_keep   : quantile threshold used by the final acquisition
            % n_min/max: number of expensive evaluations per generation
            % unc0/cov0/ind0: base weights for uncertainty, coverage, and
            %                 predicted indicator gain
            % debug    : print one-line runtime diagnostics
            [k,gmax,K,q_keep,n_min,n_max,unc0,cov0,ind0,debug] = ...
                Algorithm.ParameterSet(6,3000,5,0.80,5,8,0.35,0.30,0.20,0);

            %% Latin hypercube initialization
            if Problem.D <= 10
                N = 11 * Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive = Population;

            gen      = 0;
            prev_err = 1;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                gen   = gen + 1;
                ratio = min(1,Problem.FE/max(1,Problem.maxFE));
                k_eff = min(length(Population),max(k,ceil(1.5*Problem.M)));

                %% APD/SDE state labels and diagnostics
                [Catalog,Ref,ClassInfo] = SRMaO_APDClassification( ...
                    Population,ratio,N,k_eff);
                diagnostics = SRMaO_RuntimeDiagnostics(Population,N);

                %% Binary relation pairs with continuous confidence weights
                Input = Population.decs;
                [XXs,YYs,WWs] = SRMaO_BinaryRelationPairs( ...
                    Input,Catalog,ClassInfo.confidence);

                if isempty(XXs)
                    [Archive,nAdded] = fallbackEvaluate(Problem,Archive,Population,Ref,n_min);
                    Population = SRMaO_RefSelectAPD(Archive,Problem.N,ratio);
                    prev_err = 1;
                    if debug
                        fprintf('[SRMaO %3d | FE=%4d/%4d] fallback pairs=0 added=%d cov=%.3f deg=%.3f\n', ...
                            gen,Problem.FE,Problem.maxFE,nAdded,diagnostics.coverage,diagnostics.degeneracy);
                    end
                    continue;
                end

                %% Train/test split and normalization
                [TrainIn,TrainOut,TrainW,TestIn,TestOut] = SRMaO_DataProcess(XXs,YYs,WWs);
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = SRMaO_onehot2(TrainOut,1);
                xDim = size(TrainIn_nor,2);

                %% Lightweight ensemble relation surrogate
                nets = SRMaO_DropoutEnsemble(TrainIn_nor,TrainOut_onehot,xDim,K,TrainW);

                %% Validation error for continuous state weighting
                if isempty(TestIn)
                    p_err = prev_err;
                else
                    TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                    pre_avg = zeros(size(TestIn_nor,1),2);
                    for i = 1 : length(nets)
                        pre_avg = pre_avg + nets{i}(TestIn_nor')';
                    end
                    pre_avg = pre_avg ./ max(1,length(nets));
                    TestPre = SRMaO_onehot2(pre_avg,2);
                    p_err = sum(TestPre ~= TestOut) / max(1,size(TestOut,1));
                end
                if isnan(p_err) || isinf(p_err)
                    p_err = 1;
                end
                p_err = 0.7*p_err + 0.3*prev_err;

                %% Continuous state-aware acquisition weights
                stateWeights = stateAwareWeights(diagnostics,p_err,ratio,unc0,cov0,ind0);

                Smodel = struct();
                Smodel.X              = Input;
                Smodel.Y              = double(Catalog(:));
                Smodel.confidence     = ClassInfo.confidence(:);
                Smodel.popObj         = Population.objs;
                Smodel.refDirs        = ClassInfo.refDirs;
                Smodel.mp_struct      = TrainIn_struct;
                Smodel.nets           = nets;
                Smodel.p_err          = p_err;
                Smodel.ratio          = ratio;
                Smodel.diagnostics    = diagnostics;
                Smodel.stateWeights   = stateWeights;
                Smodel.classScore     = ClassInfo.score(:);

                %% Unified acquisition: relation + uncertainty + coverage + indicator
                Next = SRMaOSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel,q_keep,n_min,n_max);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs],{1,15,1,5});
                    Next = Next(1:min([n_min,size(Next,1),remain]),:);
                end

                NewSols = [];
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols];
                end

                if debug
                    fprintf(['[SRMaO %3d | FE=%4d/%4d] p_err=%.3f cov=%.3f deg=%.3f ', ...
                             'w=[%.2f %.2f %.2f %.2f] eval=%d\n'], ...
                        gen,Problem.FE,Problem.maxFE,p_err,diagnostics.coverage,diagnostics.degeneracy, ...
                        stateWeights.relation,stateWeights.uncertainty, ...
                        stateWeights.coverage,stateWeights.indicator,length(NewSols));
                end

                prev_err = p_err;
                Population = SRMaO_RefSelectAPD(Archive,Problem.N,ratio);
            end
        end
    end
end

function weights = stateAwareWeights(diagnostics,p_err,ratio,unc0,cov0,ind0)
% Convert runtime state into smooth acquisition weights.
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
    trust       = clamp01(1 - p_err/0.50);
    covDeficit  = clamp01(1 - diagnostics.coverage);
    degeneracy  = clamp01(diagnostics.degeneracy);

    raw = zeros(1,4);
    raw(1) = 0.45 + 0.35*trust;
    raw(2) = unc0 * (0.50 + covDeficit) * (1 - 0.40*ratio) * (0.50 + 0.50*trust);
    raw(3) = cov0 * (0.50 + covDeficit + 0.50*degeneracy);
    raw(4) = ind0 * (0.50 + 0.50*ratio) * (0.50 + 0.50*trust);
    raw    = max(raw,0.01);
    raw    = raw ./ sum(raw);

    weights = struct('relation',raw(1),'uncertainty',raw(2), ...
                     'coverage',raw(3),'indicator',raw(4), ...
                     'trust',trust,'coverageDeficit',covDeficit, ...
                     'degeneracy',degeneracy);
end

function [Archive,nAdded] = fallbackEvaluate(Problem,Archive,Population,Ref,nEval)
% Direct GA fallback used only when relation pairs cannot be formed.
    nAdded = 0;
    remain = Problem.maxFE - Problem.FE;
    if remain <= 0
        return;
    end
    Next = OperatorGA(Problem,[Population.decs;Ref.decs],{1,15,1,5});
    Next = Next(1:min([nEval,size(Next,1),remain]),:);
    if ~isempty(Next)
        Archive = [Archive,Problem.Evaluation(Next)];
        nAdded = size(Next,1);
    end
end

function y = clamp01(x)
    y = min(1,max(0,x));
end
