classdef REMO_new2_AdaMaO_PIEAOnlySelection < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% PIEA-OnlySelection: 保留 PIEA 指标选择，去除 AdaMaO 自适应关系学习
%
% 本版本保留 PIEA-style indicator subsystem，但禁用 AdaMaO 的动态关系对训练：
%  - 始终使用 conservative relation pairs（GetRelationPairs）
%  - 不使用 curriculum 模式
%  - 不使用 weighted 模式（置信度加权）
%  - 训练始终使用 DataProcess（非 DataProcess_confidence）
%
% 保留模块：
%  - PIEA 指标轮盘选择（IndicatorSelector / Shape_Estimate）
%  - fitrsvm IndicatorModel
%  - UpdateInformation / NDSort_SDR 反馈
%  - RuntimeDiagnostics（用于日志和 explore 触发）
%
% 候选选择优先 indicator（只要模型可用）：
%   1. indicator（如果 IndicatorModel 可用且 p_err <= tau_err）
%   2. explore（覆盖率低时）
%   3. conservative
%
% 实验目的：判断性能主要来自于指标选择还是自适应关系学习。
%  - 若 PIEAOnlySelection 接近 FullPIEA → AdaMaO 关系学习创新性较弱
%  - 若 PIEAOnlySelection 远差于 FullPIEA → 自适应关系学习框架重要
%  - 若 PIEAOnlySelection 差于 Lite → 指标模块单独不够

    methods
        function main(Algorithm, Problem)
            %% ============ 参数设置 ============
            [k,gmax,q_keep,lambda0,w_min,n_min,n_max,tau_err,use_indicator,debug] = ...
                Algorithm.ParameterSet(6,3000,0.80,0.35,0.30,4,6,0.35,1,0);

            %% ============ 初始化种群 ============
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

            %% ============ 初始化指标轮盘选择系统 ============
            tau_indicator = 20;
            indicator(1) = struct('method','SDE',        'Choose_record',ones(1,tau_indicator), ...
                                  'Win_record',ones(1,tau_indicator),'Pw',1/3);
            indicator(2) = struct('method','I_epsilon+', 'Choose_record',ones(1,tau_indicator), ...
                                  'Win_record',ones(1,tau_indicator),'Pw',1/3);
            indicator(3) = struct('method','Minkowski',  'Choose_record',ones(1,tau_indicator), ...
                                  'Win_record',ones(1,tau_indicator),'Pw',1/3);

            Lp         = 1;
            prev_p_err = 1;
            gen        = 0;

            %% ============ 主优化循环 ============
            while Algorithm.NotTerminated(Archive)
                gen   = gen + 1;
                ratio = Problem.FE / Problem.maxFE;

                %% ---- 自适应参考解数量 ----
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));

                %% ---- 混合 PBI 分类 ----
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                %% ---- 运行时诊断（用于日志和 explore 触发）----
                diagnostics = RuntimeDiagnostics(Population,N);
                mean_conf   = mean(confidence(:));

                % ---- 始终使用 conservative 关系对 ----
                % 不使用 curriculum/weighted 模式
                % 不使用 DataProcess_confidence
                % 这是 PIEAOnlySelection 的核心修改
                relation_mode = 'conservative';

                %% ---- 生成关系对样本（始终 conservative）----
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                WWs = [];

                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    prev_p_err = 1;
                    continue;
                end

                %% ---- 训练关系预测模型 ----
                % 始终使用 DataProcess（非 DataProcess_confidence）
                [net,TrainIn_struct,p_err] = TrainRelationModel_Conservative(XXs,YYs);

                %% ---- 指标轮盘选择 ----
                indicator_flag = 1;
                IndicatorModel = [];
                Fitness = [];
                if use_indicator
                    try
                        [Fitness,indicator_flag,Lp] = IndicatorSelector(Population,indicator,Lp);
                    catch
                        Fitness = [];
                    end
                    if ~isempty(Fitness)
                        try
                            IndicatorModel = fitrsvm(Population.decs,Fitness, ...
                                'KernelFunction','rbf', ...
                                'KernelScale','auto', ...
                                'Standardize',true);
                        catch
                            IndicatorModel = [];
                        end
                    end
                end

                %% ---- 候选解选择：优先 indicator ----
                candidate_mode = 'conservative';
                if use_indicator && ~isempty(IndicatorModel) && p_err <= tau_err
                    candidate_mode = 'indicator';
                elseif p_err <= tau_err && diagnostics.coverage < 0.60
                    candidate_mode = 'explore';
                end

                % Strict PIEA-only candidate selection (disabled by default):
                % if use_indicator && ~isempty(IndicatorModel)
                %     candidate_mode = 'indicator';
                % else
                %     candidate_mode = 'conservative';
                % end

                %% ---- 防御：invalid indicator mode fallback ----
                if strcmp(candidate_mode,'indicator') && isempty(IndicatorModel)
                    if p_err <= tau_err && diagnostics.coverage < 0.60
                        candidate_mode = 'explore';
                    else
                        candidate_mode = 'conservative';
                    end
                end

                %% ---- 构建代理模型结构体 ----
                Smodel = struct();
                Smodel.X              = Input;
                Smodel.Y              = Catalog;
                Smodel.mp_struct      = TrainIn_struct;
                Smodel.net            = net;
                Smodel.p_err          = p_err;
                Smodel.lambda0        = lambda0;
                Smodel.ratio          = ratio;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode           = candidate_mode;
                Smodel.q_keep         = q_keep;
                Smodel.n_min          = n_min;
                Smodel.n_max          = n_max;

                %% ---- 代理模型辅助选择 ----
                Next = AdaMaOSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel,q_keep,n_min,n_max);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs],{1,15,1,5});
                    Next = Next(1:min(n_min,size(Next,1)),:);
                end

                %% ---- 真实评估候选解 ----
                NewSols = [];
                ArchiveSizeBefore = length(Archive);
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols];
                end

                %% ---- 指标反馈 ----
                if use_indicator && ~isempty(Fitness)
                    score = IndicatorFeedbackScore(Archive,NewSols,ArchiveSizeBefore);
                    indicator = UpdateInformation(indicator_flag,score,indicator);
                end

                %% ---- 调试输出 ----
                if debug
                    if use_indicator
                        indStr = 'on';
                    else
                        indStr = 'off';
                    end
                    if indicator_flag == 1
                        flagStr = 'SDE';
                    elseif indicator_flag == 2
                        flagStr = 'Eps+';
                    else
                        flagStr = 'MD';
                    end
                    fprintf(['[%s] gen=%d ratio=%.3f rel=%s cand=%s p_err=%.3f ', ...
                             'cov=%.3f deg=%.3f conf=%.3f ind=%s flag=%s Lp=%.3f nNext=%d\n'], ...
                        class(Algorithm), gen, ratio, relation_mode, candidate_mode, p_err, ...
                        diagnostics.coverage, diagnostics.degeneracy, mean_conf, ...
                        indStr, flagStr, Lp, length(NewSols));
                end

                %% ---- 更新状态 ----
                prev_p_err = p_err;
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

%% ============ 辅助函数：保守模式关系模型训练（无权重）============
function [net,TrainIn_struct,p_err] = TrainRelationModel_Conservative(XXs,YYs)
% TrainRelationModel_Conservative - 仅使用 DataProcess 训练关系神经网络
%
% 本函数是 TrainRelationModel 的简化版，只支持无权重模式
% 用于 PIEAOnlySelection 版本

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

%% ============ 辅助函数：运行时诊断 ============
function diagnostics = RuntimeDiagnostics(Population,Nref)
    PopObj = Population.objs;
    PopObj = NormalizeObjectives(PopObj);
    [N,M] = size(PopObj);

    if N == 0 || M == 0
        diagnostics.coverage   = 0;
        diagnostics.degeneracy = 0;
        return;
    end

    V = UniformPoint(Nref,M,'ILD');
    V = V ./ max(vecnorm(V,2,2),eps);

    Direction = PopObj;
    rowNorm = vecnorm(Direction,2,2);
    zeroRows = rowNorm < 1e-12;
    Direction(zeroRows,:) = 1 ./ max(M,1);
    rowNorm(zeroRows) = vecnorm(Direction(zeroRows,:),2,2);
    Direction = Direction ./ max(rowNorm,eps);

    cosine = 1 - pdist2(Direction,V,'cosine');
    [~,assigned] = max(cosine,[],2);
    diagnostics.coverage = numel(unique(assigned)) / size(V,1);

    Centered = PopObj - mean(PopObj,1);
    if size(Centered,1) < 2 || all(abs(Centered(:)) < 1e-12)
        diagnostics.degeneracy = 0;
        return;
    end
    s = svd(Centered,'econ');
    energy = s.^2;
    total = sum(energy);
    if total < 1e-12
        rank90 = M;
    else
        rank90 = find(cumsum(energy)./total >= 0.90,1,'first');
    end
    diagnostics.degeneracy = max(0,min(1,1 - rank90/max(M,1)));
end

%% ============ 辅助函数：目标值归一化 ============
function PopObj = NormalizeObjectives(PopObj)
    zmin = min(PopObj,[],1);
    zmax = max(PopObj,[],1);
    span = zmax - zmin;
    span(span < 1e-12) = 1;
    PopObj = (PopObj - zmin) ./ span;
    PopObj(isnan(PopObj) | isinf(PopObj)) = 0;
end

%% ============ 辅助函数：指标反馈分数计算 ============
function score = IndicatorFeedbackScore(Archive,NewSols,ArchiveSizeBefore)
    score = 0;
    if isempty(NewSols)
        return;
    end

    try
        [FrontNo_all,~] = NDSort(Archive.objs,1);
        new_idx = ArchiveSizeBefore + (1:length(NewSols));
        new_idx = new_idx(new_idx <= length(FrontNo_all));
        if isempty(new_idx) || ~any(FrontNo_all(new_idx) == 1)
            return;
        end

        score = 1;
        F1_subset = Archive(FrontNo_all == 1);
        [FrontNo_SDR,~] = NDSort_SDR(F1_subset,1);
        new_in_F1_subset_idx = ismember(F1_subset.decs,NewSols.decs,'rows');
        if any(FrontNo_SDR(new_in_F1_subset_idx) == 1)
            score = 2;
        end
    catch
        score = min(score,1);
    end
end
