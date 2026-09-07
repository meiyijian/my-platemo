classdef REMO_new2_AdaMaO_SDEOnly_UniformMix_Original < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% PACDIS: PBI-Assisted Quality Classification (PAQC) and
% Criterion-Diversified Infill Selection (CDIS).
% 关系模型学习 PAQC 分组产生的有序解对，CDIS 选择真实评价批次。
% gmax --- 3000 --- Cumulative candidate-generation threshold
% pMix --- 0.50 --- Indicator-selection probability when available
% rGood --- 0.25 --- Proportion of solutions assigned to the positive group
% qKeep --- 0.80 --- Quantile threshold for exploration scores
% lambda0 --- 0.35 --- Base weight of prediction ambiguity
% nMin --- 4 --- Batch completion target when candidates permit
% nMax --- 6 --- Maximum evaluation batch size

    methods
        function main(Algorithm,Problem)
            [gmax,pMix,rGood,qKeep,lambda0,nMin,nMax] = ...
                Algorithm.ParameterSet(3000,0.50,0.25,0.80,0.35,4,6);
            validateUniformMixParameters( ...
                gmax,pMix,rGood,qKeep,lambda0,nMin,nMax);

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            % 初始设计：拉丁超立方采样并执行真实评价。
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
                % PAQC：构造正组、非正组及后续交配池使用的参考解。
                k_eff = min(Problem.N,max(6,ceil(1.5*Problem.M)));
                [~,~,Catalog,~,Ref] = PBIQualityClassification( ...
                    Population,ratio,'Nref',N,'k',k_eff, ...
                    'theta',5,'rGood',rGood);

                % 关系学习：根据分组生成有序解对，训练三类关系模型。
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    continue;
                end

                [net,TrainIn_struct,p_err] = ...
                    TrainOriginalRelationModel(XXs,YYs);

                % 指标学习：以已评价解的 SDE 指标训练 RBF-SVR。
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

                % CDIS：每轮选择一种完整准则，指标模型不可用时使用探索。
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

                % 累积候选池，并根据本轮准则返回有序待评价批次。
                Next = DiversifiedInfillSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel, ...
                    qKeep,nMin,nMax);

                % 按剩余预算截断批次；候选池为空时由遗传变异补充候选。
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
                % 从累计已评价档案中执行环境选择，得到下一代种群。
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

function validateUniformMixParameters(gmax,pMix,rGood,qKeep,lambda0,nMin,nMax)
%validateUniformMixParameters 检查分类比例、选择准则和批次控制参数。
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
end

function [net,TrainIn_struct,p_err] = TrainOriginalRelationModel(XXs,YYs)
%TrainOriginalRelationModel 训练三类关系模型，并计算关系对留出误差 e_r。
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
