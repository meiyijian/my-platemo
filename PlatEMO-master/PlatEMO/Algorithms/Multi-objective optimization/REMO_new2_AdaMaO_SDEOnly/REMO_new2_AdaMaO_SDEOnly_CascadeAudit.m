classdef REMO_new2_AdaMaO_SDEOnly_CascadeAudit < ALGORITHM
%REMO_new2_AdaMaO_SDEOnly_CascadeAudit - Read-only counterfactual audit of UniformMix_Original.
%   <2026> <multi/many> <real> <expensive>
%
% 本算法是与 REMO_new2_AdaMaO_SDEOnly_UniformMix_Original 严格配对的
% 只读审计入口（P0 / Stage 0）。操作链（候选生成、关系模型、SDE 指标
% 模型、UniformMix 模式路由、AdaMaOSelection 选择、fallback、官方
% Evaluation、Archive 更新、RefSelect）与 RelationModeBase 保持一致，
% 关系对构造固定为原始 conservative 路径。审计层只读地暴露完整累积
% 候选池、关系得分、全池 SDE-SVR 预测、粗筛状态与选择状态，并对
% DTLZ/WFG 合成问题通过 CalDec/CalObj/CalCon 计算 shadow 目标，进而
% 计算候选边际 IGD+、greedy-batch 覆盖后悔和固定槽替换净增益。
%
% 不变量：
%   - 不修改任何冻结基线文件；
%   - shadow 值永不进入 Population/Archive/模型训练/候选选择；
%   - Problem.FE、全局 RNG 与 modeStream 轨迹与 Original 完全一致；
%   - 官方 Problem.Evaluation 恰好执行一次且仅在只读审计之后；
%   - 仅支持 DTLZ1-DTLZ7 与 WFG1-WFG9，要求 Problem.maxRuntime=inf。

    methods
        function main(Algorithm,Problem)
            %% 参数与 UniformMix 一致，仅在末尾追加审计参数
            [k,gmax,q_keep,lambda0,w_min,n_min,n_max,tau_err, ...
                use_indicator,debug,auditCheckpoints,referenceRequest, ...
                fullReferenceSensitivity] = Algorithm.ParameterSet( ...
                6,3000,0.80,0.35,0.30,4,6,0.35,1,0, ...
                [0.10 0.30 0.50 0.70 0.90],512,1); %#ok<ASGLU> tau_err is unused in the fixed conservative mode

            validateAuditSettings(auditCheckpoints,referenceRequest, ...
                fullReferenceSensitivity,Problem);

            %% 初始化（与 UniformMix 完全一致）
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            InitFE = Problem.FE;
            Archive = Population;

            policy = 'uniform_mix';
            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp         = 1;
            prev_p_err = 1;
            gen        = 0;

            %% 一次性生成并冻结审计参考前沿
            auditProbeRng = rng;
            auditReference = Problem.GetOptimum(referenceRequest);
            rng(auditProbeRng);

            %% 审计状态
            audit = CascadeAuditSchema();
            audit.referenceCount = size(auditReference,1);
            Algorithm.metric.cascadeAudit = audit;
            checkpointIdx   = 1;
            firstAuditDone  = false;
            cvSeed = mod(20260806 + Algorithm.run*1000003, ...
                double(intmax('uint32')));

            %% 主优化循环（与 UniformMix 配对）
            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                % 每代在固定位置消耗配对模式抽取
                if strcmp(policy,'uniform_mix') || ...
                        strcmp(policy,'linear_schedule')
                    u = rand(modeStream,1);
                else
                    u = 0;
                end

                ratio = Problem.FE / Problem.maxFE;
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                diagnostics = RuntimeDiagnostics(Population,N);
                mean_conf   = mean(confidence(:));

                %% 固定 conservative 关系对构造（原始路径）
                relation_mode = 'conservative';
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                WWs = [];

                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    prev_p_err = 1;
                    continue;
                end

                [net,TrainIn_struct,p_err] = TrainRelationModel( ...
                    XXs,YYs,WWs,w_min,false);

                %% SDE 指标模型（与 UniformMix 一致）
                IndicatorModel = [];
                Fitness = [];
                if use_indicator
                    try
                        [Fitness,Lp] = IndicatorSelectorSDEOnly( ...
                            Population,Lp);
                    catch
                        Fitness = [];
                    end
                    if ~isempty(Fitness)
                        try
                            IndicatorModel = fitrsvm( ...
                                Population.decs,Fitness, ...
                                'KernelFunction','rbf', ...
                                'KernelScale','auto', ...
                                'Standardize',true);
                        catch
                            IndicatorModel = [];
                        end
                    end
                end

                %% UniformMix 候选模式路由
                [candidate_mode,p_ind,modeProgress] = ...
                    ResolveSDECandidateMode( ...
                    policy,~isempty(IndicatorModel),Problem.FE,InitFE, ...
                    Problem.maxFE,u);

                %% 代理辅助候选选择（审计副本，返回只读 trace）
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

                [Next,trace] = AdaMaOSelectionCascadeAudit( ...
                    Problem,Ref,Population.decs,gmax,Smodel, ...
                    q_keep,n_min,n_max);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = Next(1:min(n_min,size(Next,1)),:);
                end

                NewSols = [];
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);

                    %% 按实际官方 Next 重算 SelectedMask，使 K 精确
                    if trace.Valid
                        trace.SelectedMask = mapNextToPool(Next, ...
                            trace.Candidates);
                    end

                    %% 只读级联审计（在官方 Evaluation 之前，不消耗 RNG）
                    progress = (Problem.FE-InitFE)/ ...
                        max(Problem.maxFE-InitFE,1);
                    progress = min(1,max(0,progress));
                    eligible = trace.Valid && ...
                        strcmp(candidate_mode,'indicator') && ...
                        trace.OperationalIndicatorUsed && ...
                        all(isfinite(trace.IndicatorScores)) && ...
                        any(trace.SelectedMask) && ...
                        checkpointIdx <= numel(auditCheckpoints) && ...
                        progress >= auditCheckpoints(checkpointIdx);
                    if eligible
                        auditTimer = tic;
                        shadow = EvaluateCascadeShadow(Problem, ...
                            trace.Candidates,Archive.objs,Archive.cons, ...
                            auditReference);
                        if ~isempty(Fitness) && ...
                                numel(Fitness) == size(Population.decs,1)
                            cvKendall = CrossValidateSDEIndicatorRanking( ...
                                Population.decs,Fitness,cvSeed);
                        else
                            cvKendall = NaN;
                        end
                        counterfactual = ...
                            ComputeCascadeBatchCounterfactual( ...
                            shadow.BaselineDistance, ...
                            shadow.CandidateDistance, ...
                            trace.SelectedMask,trace.CoarseMask, ...
                            trace.IndicatorScores);
                        traceRow = toAuditTrace(trace,Problem);
                        [candidateRows,generationRow,~] = ...
                            BuildCascadeAuditRows(Algorithm.run,gen, ...
                            Problem.FE,progress, ...
                            candidateModeCode(candidate_mode),traceRow, ...
                            shadow,counterfactual,cvKendall);

                        if fullReferenceSensitivity && ...
                                (~firstAuditDone || progress >= 0.90)
                            [rankCorr,topKOverlap] = ...
                                fullReferenceSensitivityMetrics( ...
                                Archive.objs,shadow,Problem.optimum, ...
                                counterfactual.BatchSize);
                            generationRow(column(audit, ...
                                'generationRows', ...
                                'FullReferenceRankCorrelation')) = rankCorr;
                            generationRow(column(audit, ...
                                'generationRows', ...
                                'FullReferenceTopKOverlap')) = topKOverlap;
                        end

                        auditSeconds = toc(auditTimer);
                        generationRow(column(audit, ...
                            'generationRows','AuditSeconds')) = auditSeconds;

                        audit.candidateRows = [audit.candidateRows; ...
                            candidateRows];
                        audit.generationRows = [audit.generationRows; ...
                            generationRow];
                        audit.totalShadowEvaluations = ...
                            audit.totalShadowEvaluations + ...
                            shadow.ShadowEvaluationCount;
                        audit.totalAuditSeconds = ...
                            audit.totalAuditSeconds + auditSeconds;
                        Algorithm.metric.cascadeAudit = audit;
                        firstAuditDone = true;
                        while checkpointIdx <= numel(auditCheckpoints) && ...
                                progress >= auditCheckpoints(checkpointIdx)
                            checkpointIdx = checkpointIdx + 1;
                        end
                    end

                    %% 官方真实评价（仅一次，在只读审计之后）
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                end

                if debug
                    fprintf(['[AdaMaO-%s Gen %3d | FE=%4d/%4d] ', ...
                             'rel=%s cand=%s progress=%.3f Pind=%.3f ', ...
                             'u=%.3f p_err=%.3f prev=%.3f cov=%.3f ', ...
                             'deg=%.3f conf=%.3f n=%d\n'], ...
                        policy,gen,Problem.FE,Problem.maxFE,relation_mode, ...
                        candidate_mode,modeProgress,p_ind,u,p_err,prev_p_err, ...
                        diagnostics.coverage,diagnostics.degeneracy, ...
                        mean_conf,length(NewSols));
                end

                prev_p_err = p_err;
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

%% ============ 审计设置验证 ============
function validateAuditSettings(auditCheckpoints,referenceRequest, ...
    fullReferenceSensitivity,Problem)
    if ~isnumeric(auditCheckpoints) || ~isreal(auditCheckpoints) || ...
            isempty(auditCheckpoints) || ~isvector(auditCheckpoints) || ...
            any(~isfinite(auditCheckpoints)) || ...
            any(auditCheckpoints(:) < 0) || ...
            any(auditCheckpoints(:) > 1) || ...
            any(diff(auditCheckpoints(:)) <= 0)
        error('AdaMaO:InvalidCascadeAuditCheckpoints', ...
            'auditCheckpoints must be strictly increasing within [0,1].');
    end
    if ~isnumeric(referenceRequest) || ~isreal(referenceRequest) || ...
            ~isscalar(referenceRequest) || ~isfinite(referenceRequest) || ...
            referenceRequest < 1 || referenceRequest ~= fix(referenceRequest)
        error('AdaMaO:InvalidCascadeAuditReferenceRequest', ...
            'referenceRequest must be a positive integer scalar.');
    end
    if ~isscalar(fullReferenceSensitivity) || ...
            ~(islogical(fullReferenceSensitivity) || ...
              (isnumeric(fullReferenceSensitivity) && ...
               ismember(fullReferenceSensitivity,[0 1])))
        error('AdaMaO:InvalidCascadeAuditSensitivityFlag', ...
            'fullReferenceSensitivity must be a logical scalar.');
    end
    if ~(isnumeric(Problem.maxRuntime) && isreal(Problem.maxRuntime) && ...
            isscalar(Problem.maxRuntime) && Problem.maxRuntime == inf)
        error('AdaMaO:CascadeAuditRuntimeCap', ...
            'CascadeAudit requires Problem.maxRuntime to be inf.');
    end
    problemClass = class(Problem);
    if isempty(regexp(problemClass,'^(DTLZ[1-7]|WFG[1-9])$','once'))
        error('AdaMaO:CascadeAuditUnsupportedProblem', ...
            'CascadeAudit supports only DTLZ1-DTLZ7 and WFG1-WFG9.');
    end
end

%% ============ 审计 trace 组装 ============
function traceRow = toAuditTrace(trace,Problem)
    traceRow.CandidateDecisions = trace.Candidates;
    traceRow.Lower = Problem.lower;
    traceRow.Upper = Problem.upper;
    traceRow.RelationScore = trace.RelationScores;
    traceRow.IndicatorScore = trace.IndicatorScores;
    traceRow.CoarseKept = trace.CoarseMask;
    traceRow.SelectedMask = trace.SelectedMask;
    traceRow.OperationalIndicatorUsed = trace.OperationalIndicatorUsed;
end

function selectedMask = mapNextToPool(Next,candidates)
    count = size(candidates,1);
    selectedMask = false(count,1);
    if isempty(Next)
        return;
    end
    [~,row] = ismember(Next,candidates,'rows');
    row(row < 1) = [];
    if ~isempty(row)
        selectedMask(row) = true;
    end
end

function code = candidateModeCode(mode)
    switch mode
        case 'indicator'
            code = 2;
        case 'explore'
            code = 1;
        otherwise
            code = 0;
    end
end

function index = column(audit,tableName,columnName)
    index = find(strcmp(audit.columns.(tableName),columnName),1);
end

%% ============ 完整参考前沿灵敏度 ============
function [rankCorr,topKOverlap] = fullReferenceSensitivityMetrics( ...
    archiveObj,shadow,optimum,batchSize)
    [fullUtility,~,~,~,~] = ComputeMarginalIGDp(archiveObj, ...
        shadow.CandidateObjectives,optimum);
    if ~isempty(fullUtility) && ~isempty(shadow.MarginalIGDp) && ...
            numel(fullUtility) == numel(shadow.MarginalIGDp)
        try
            rankCorr = corr(shadow.MarginalIGDp,fullUtility, ...
                'Type','Spearman');
        catch
            rankCorr = NaN;
        end
        if ~isscalar(rankCorr) || ~isreal(rankCorr) || ~isfinite(rankCorr)
            rankCorr = NaN;
        end
        sparseTopK = topKMask(shadow.MarginalIGDp,batchSize);
        fullTopK = topKMask(fullUtility,batchSize);
        k = min(batchSize,numel(shadow.MarginalIGDp));
        if k > 0
            topKOverlap = nnz(sparseTopK & fullTopK)/k;
        else
            topKOverlap = NaN;
        end
    else
        rankCorr = NaN;
        topKOverlap = NaN;
    end
end

function mask = topKMask(values,k)
    count = numel(values);
    if count < 1
        mask = false(0,1);
        return;
    end
    keys = [-values(:),(1:count)'];
    [~,order] = sortrows(keys,[1 2]);
    mask = false(count,1);
    mask(order(1:min(k,count))) = true;
end

%% ============ 运行时诊断（与 RelationModeBase 完全一致） ============
function diagnostics = RuntimeDiagnostics(Population,Nref)
    PopObj = NormalizeObjectives(Population.objs);
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

function PopObj = NormalizeObjectives(PopObj)
    zmin = min(PopObj,[],1);
    zmax = max(PopObj,[],1);
    span = zmax - zmin;
    span(span < 1e-12) = 1;
    PopObj = (PopObj - zmin) ./ span;
    PopObj(isnan(PopObj) | isinf(PopObj)) = 0;
end

%% ============ 关系模型训练（与 RelationModeBase 完全一致） ============
function [net,TrainIn_struct,p_err] = TrainRelationModel( ...
    XXs,YYs,WWs,w_min,use_weights)
    if use_weights
        [TrainIn,TrainOut,TrainW,TestIn,TestOut,~] = ...
            DataProcess_confidence(XXs,YYs,WWs);
    else
        [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
        TrainW = [];
    end

    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;

    if use_weights && ~isempty(TrainW)
        EW = TrainW(:)';
        if mean(EW) > 1e-12
            EW = EW ./ mean(EW);
        else
            EW = ones(size(EW));
        end
        EW = max(EW,w_min);
        net = train(net,TrainIn_nor',TrainOut_onehot',[],[],EW);
    else
        net = train(net,TrainIn_nor',TrainOut_onehot');
    end

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
