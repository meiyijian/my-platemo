classdef REMO_new2_AdaMaO_HCV < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Harmonic complementary PBI supervision for the RSEA blind subspace
% gmax --- 3000 --- Maximum surrogate-assisted training generations
% pMix --- 0.50 --- Probability of using indicator-based selection
% rGood --- 0.25 --- Proportion of solutions assigned to the positive group
% qKeep --- 0.80 --- Proportion retained during exploratory selection
% lambda0 --- 0.35 --- Initial exploration strength
% nMin --- 4 --- Minimum number of candidate solutions
% nMax --- 6 --- Maximum number of candidate solutions
% nHarm --- 2 --- Number of blind harmonic orders used (0 disables complementary niching)
% wCon --- 0 --- Use rescaled RSEA convergence weight (0 legacy, 1 scaled)

%------------------------------- Reference --------------------------------
% Baseline: REMO_new2_AdaMaO_SDEOnly_UniformMix_Original. This variant only
% replaces the supervision layer (positive-group construction); the relation
% network, candidate routing, GA inner loop, and evaluation budget are
% unchanged.
%
% Motivation (see private/HarmonicComplementaryVectors.m and
% private/ComplementaryPBI_Classification.m for the full derivation):
%   RSEA's RadarGrid maps M objectives to 2 radar coordinates through the
%   first-order discrete Fourier harmonics, acting only on the weight profile
%   lambda = P/sum(P). Its kernel is span{harmonics h = 2..floor(M/2)}, of
%   dimension M-3, so RSEA cannot distinguish any pair of solutions differing
%   only inside that subspace. This variant supplies an analytic vector set
%   spanning that kernel and turns the positive-group rule into per-niche
%   selection so the vector set becomes a first-order factor.
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
            [gmax,pMix,rGood,qKeep,lambda0,nMin,nMax,nHarm,wConFlag] = ...
                Algorithm.ParameterSet(3000,0.50,0.25,0.80,0.35,4,6,2,0);
            validateHCVParameters( ...
                gmax,pMix,rGood,qKeep,lambda0,nMin,nMax,nHarm,wConFlag);

            if wConFlag == 1
                wCon = 'scaled';
            else
                wCon = 'legacy';
            end

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive = Population;

            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp = 1;

            while Algorithm.NotTerminated(Archive)
                u = rand(modeStream,1);
                ratio = Problem.FE / Problem.maxFE;
                k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                [~,~,Catalog,~,Ref] = ComplementaryPBI_Classification( ...
                    Population,ratio,'k',k_eff,'theta',5, ...
                    'rGood',rGood,'nHarm',nHarm);

                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N,wCon);
                    continue;
                end

                [net,TrainIn_struct,p_err] = ...
                    TrainOriginalRelationModel(XXs,YYs);

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

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = Next(1:min(nMin,size(Next,1)),:);
                end

                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                end
                Population = RefSelect(Archive,Problem.N,wCon);
            end
        end
    end
end

function validateHCVParameters(gmax,pMix,rGood,qKeep,lambda0,nMin,nMax, ...
        nHarm,wConFlag)
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
    if ~isnumeric(lambda0) || ~isscalar(lambda0) || ~isfinite(lambda0) || ...
            lambda0 < 0
        error('AdaMaO:InvalidParameter', ...
            'lambda0 must be nonnegative.');
    end
    if ~isnumeric(nMin) || ~isscalar(nMin) || ~isfinite(nMin) || ...
            nMin < 1 || nMin ~= floor(nMin)
        error('AdaMaO:InvalidParameter', ...
            'nMin must be a positive integer.');
    end
    if ~isnumeric(nMax) || ~isscalar(nMax) || ~isfinite(nMax) || ...
            nMax < 1 || nMax ~= floor(nMax)
        error('AdaMaO:InvalidParameter', ...
            'nMax must be a positive integer.');
    end
    if nMin > nMax
        error('AdaMaO:InvalidParameter', ...
            'nMin must not exceed nMax.');
    end
    if ~isnumeric(nHarm) || ~isscalar(nHarm) || ~isfinite(nHarm) || ...
            nHarm < 0 || nHarm ~= floor(nHarm)
        error('AdaMaO:InvalidParameter', ...
            'nHarm must be a nonnegative integer.');
    end
    if ~isnumeric(wConFlag) || ~isscalar(wConFlag) || ...
            ~isfinite(wConFlag) || ~ismember(wConFlag,[0 1])
        error('AdaMaO:InvalidParameter', ...
            'wCon must be 0 (legacy) or 1 (scaled).');
    end
end

function [net,TrainIn_struct,p_err] = TrainOriginalRelationModel(XXs,YYs)
    [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,TrainIn_nor',TrainOut_onehot');

    if isempty(TestIn)
        p_err = 1;
    else
        TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
        TestPre = onehotconv(net(TestIn_nor')',2);
        p_err = sum(TestPre ~= TestOut) / size(TestPre,1);
    end
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
end
