classdef REMO_new2_AdaMaO_Stat < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% AdaMaO-Stat: 模式占比统计版（基于 REMO_new2_AdaMaO 完整版 Full）
%
% 本算法是 REMO_new2_AdaMaO 的"统计插桩版"，用于统计每次运行中
% 两类自适应模式被选中的次数及比例：
%   1. 关系对模式 relation_mode：conservative / curriculum / weighted
%   2. 候选解模式 candidate_mode：conservative / explore / indicator
%
% 与原版的唯一区别：在主循环中增加计数器，每代末尾把统计结果
% 保存到 .mat 文件（输出目录由环境变量 ADAMAO_STAT_DIR 指定）。
% 算法的优化逻辑与 REMO_new2_AdaMaO 完全一致，不影响搜索行为。
%
% 统计粒度说明（与用户确认的口径一致）：
%   - total_gen    : 主循环代数计数（每次进入循环体 +1）
%   - skip_gen     : 关系对为空(XXs为空)被 continue 跳过的代数
%                    —— 此类代 relation_mode 已计入，candidate_mode 未确定
%   - eval_gen     : 实际完成候选解模式选择的代数 = total_gen - skip_gen
%   - 关系对模式占比分母 = total_gen（每代都确定了 relation_mode）
%   - 候选解模式占比分母 = eval_gen（跳过轮未选 candidate_mode，不计入）
%
% 适用场景：与 REMO_new2_AdaMaO 相同（昂贵多目标/高维多目标）

    methods
        function main(Algorithm, Problem)
            %% ============ 参数设置 ============
            % 与原版完全一致的 10 个参数
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

            %%% [STAT] 初始化模式统计计数器 ============================
            stat = struct();
            stat.rel_count = struct('conservative',0,'curriculum',0,'weighted',0);
            stat.cand_count = struct('conservative',0,'explore',0,'indicator',0);
            stat.total_gen  = 0;   % 主循环代数（含跳过轮）
            stat.skip_gen   = 0;   % 关系对为空被跳过的代数
            % 每代模式轨迹（用于事后追溯，可选）
            stat.rel_trace  = {};  % 每代的 relation_mode
            stat.cand_trace = {};  % 每代的 candidate_mode（跳过轮记为 'skipped'）
            % 运行元信息
            stat.problem = class(Problem);
            stat.M       = Problem.M;
            stat.D       = Problem.D;
            stat.N       = N;
            stat.maxFE   = Problem.maxFE;
            if isempty(Algorithm.run)
                stat.runid = 0;
            else
                stat.runid = Algorithm.run;
            end
            %%% [STAT] 结束初始化 =====================================

            %% ============ 主优化循环 ============
            while Algorithm.NotTerminated(Archive)
                gen   = gen + 1;
                %%% [STAT] 代数计数 ------------------------------------
                stat.total_gen = stat.total_gen + 1;
                %--------------------------------------------------------
                ratio = Problem.FE / Problem.maxFE;

                %% ---- 自适应参考解数量 ----
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));

                %% ---- 混合 PBI 分类 ----
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                %% ---- 运行时诊断 ----
                diagnostics = RuntimeDiagnostics(Population,N);
                mean_conf   = mean(confidence(:));

                %% ---- 动态选择关系对训练模式 ----
                relation_mode = 'conservative';
                if prev_p_err > tau_err
                    relation_mode = 'curriculum';
                elseif prev_p_err <= tau_err && mean_conf >= 0.55 && diagnostics.coverage < 0.60
                    relation_mode = 'weighted';
                end

                %%% [STAT] 关系对模式计数 -------------------------------
                stat.rel_count.(relation_mode) = stat.rel_count.(relation_mode) + 1;
                stat.rel_trace{end+1} = relation_mode;
                %--------------------------------------------------------

                %% ---- 生成关系对样本 ----
                Input = Population.decs;
                switch relation_mode
                    case 'weighted'
                        [XXs,YYs,WWs] = GetRelationPairs_confidence(Input,Catalog,confidence);
                    case 'curriculum'
                        [XXs,YYs] = GetRelationPairs_curriculum(Input,Catalog,confidence,0.80);
                        WWs = [];
                    otherwise
                        [XXs,YYs] = GetRelationPairs(Input,Catalog);
                        WWs = [];
                end

                % 如果关系对为空（极端情况），跳过本轮
                if isempty(XXs)
                    %%% [STAT] 跳过轮计数 + 记录轨迹 --------------------
                    stat.skip_gen = stat.skip_gen + 1;
                    stat.cand_trace{end+1} = 'skipped';
                    % 跳过轮也要保存统计（保证最后一次保存是完整的）
                    save_mode_stat(stat);
                    %----------------------------------------------------
                    Population = RefSelect(Archive,Problem.N);
                    prev_p_err = 1;
                    continue;
                end

                %% ---- 训练关系预测模型 ----
                [net,TrainIn_struct,p_err] = TrainRelationModel( ...
                    XXs,YYs,WWs,w_min,strcmp(relation_mode,'weighted'));

                %% ---- 指标轮盘选择（可选） ----
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

                %% ---- 动态选择候选解选择模式 ----
                candidate_mode = 'conservative';
                if use_indicator && p_err <= tau_err && diagnostics.degeneracy >= 0.45
                    candidate_mode = 'indicator';
                elseif p_err <= tau_err && diagnostics.coverage < 0.60
                    candidate_mode = 'explore';
                end

                %%% [STAT] 候选解模式计数 ------------------------------
                stat.cand_count.(candidate_mode) = stat.cand_count.(candidate_mode) + 1;
                stat.cand_trace{end+1} = candidate_mode;
                %--------------------------------------------------------

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

                %% ---- 指标反馈（可选） ----
                if use_indicator && ~isempty(Fitness)
                    score = IndicatorFeedbackScore(Archive,NewSols,ArchiveSizeBefore);
                    indicator = UpdateInformation(indicator_flag,score,indicator);
                end

                %% ---- 调试输出（可选） ----
                if debug
                    fprintf(['[AdaMaO-Stat Gen %3d | FE=%4d/%4d] rel=%s cand=%s ', ...
                             'p_err=%.3f prev=%.3f cov=%.3f deg=%.3f conf=%.3f n=%d\n'], ...
                        gen,Problem.FE,Problem.maxFE,relation_mode,candidate_mode, ...
                        p_err,prev_p_err,diagnostics.coverage,diagnostics.degeneracy, ...
                        mean_conf,length(NewSols));
                end

                %% ---- 更新状态 ----
                prev_p_err = p_err;
                Population = RefSelect(Archive,Problem.N);

                %%% [STAT] 每代末尾保存统计（覆盖写）-------------------
                stat.final_FE = Problem.FE;
                save_mode_stat(stat);
                %--------------------------------------------------------
            end
        end
    end
end

%% ============ [STAT] 统计保存函数 ============
function save_mode_stat(stat)
% save_mode_stat - 把模式统计结果保存到 .mat 文件
%
% 输出目录由环境变量 ADAMAO_STAT_DIR 指定。
% 文件名格式：<Problem>_M<M>_D<D>_run<runid>.mat
% 每代覆盖写，最后一次保存即为完整结果。
%
% 若环境变量未设置，则不保存（静默跳过，不影响算法运行）。

    outdir = getenv('ADAMAO_STAT_DIR');
    if isempty(outdir)
        return;
    end
    if ~exist(outdir,'dir')
        try
            mkdir(outdir);
        catch
            return;
        end
    end
    fname = fullfile(outdir, sprintf('%s_M%d_D%d_run%d.mat', ...
        stat.problem, stat.M, stat.D, stat.runid));
    try
        save(fname,'stat');
    catch
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

%% ============ 辅助函数：课程学习模式的关系对生成 ============
function [XXs,YYs] = GetRelationPairs_curriculum(Input,Catalog,confidence,q_keep)
    Catalog = Catalog(:);
    confidence = confidence(:);

    good_idx = find(Catalog == 1);
    rest_idx = find(Catalog ~= 1);

    good_idx = KeepMostConfident(good_idx,confidence,q_keep);
    rest_idx = KeepMostConfident(rest_idx,confidence,q_keep);

    keep_idx = [good_idx;rest_idx];

    if numel(good_idx) < 1 || numel(rest_idx) < 1 || numel(keep_idx) < 2
        XXs = zeros(0,2*size(Input,2));
        YYs = zeros(0,1);
        return;
    end

    Catalog2 = false(numel(keep_idx),1);
    Catalog2(1:numel(good_idx)) = true;

    [XXs,YYs] = GetRelationPairs(Input(keep_idx,:),Catalog2);
end

%% ============ 辅助函数：保留最置信的样本 ============
function idx = KeepMostConfident(idx,confidence,q_keep)
    idx = idx(:);
    if isempty(idx)
        return;
    end
    [~,order] = sort(confidence(idx),'descend');
    n_keep = max(1,ceil(q_keep*numel(idx)));
    idx = idx(order(1:n_keep));
end

%% ============ 辅助函数：训练关系预测模型 ============
function [net,TrainIn_struct,p_err] = TrainRelationModel(XXs,YYs,WWs,w_min,use_weights)
    if use_weights
        [TrainIn,TrainOut,TrainW,TestIn,TestOut,~] = DataProcess_confidence(XXs,YYs,WWs);
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
