classdef REMO_new2_AdaMaO_Simple < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% AdaMaO-Simple: 超参数削减版（基于完整版 REMO_new2_AdaMaO）
%
% 与完整版相比，本版本在保持核心框架
%   （混合 PBI 关系标注 + 置信度加权关系学习
%    + 验证误差感知的代理筛选 + 覆盖感知评估分配 + PIEA 指标辅助选择）
% 不变的前提下，大幅削减可调超参数：
%   - 外部参数从 10 个降至 2 个：[use_indicator, debug]
%   - 删除 k / gmax / q_keep / lambda0 / w_min / n_min / n_max / tau_err 共 8 个外部参数，
%     其值全部由 Problem.N / M / maxFE、覆盖率、验证误差、候选池规模自动决定
%   - 删除所有硬编码模式切换阈值（mean_conf>=0.55、coverage<0.60、p_err/0.45）
%   - 关系对训练始终使用软置信权重（W = 0.5 + 0.5*sqrt(conf_i*conf_j)）
%   - 探索强度由 model_gain（多数类基线相对增益）× coverage_gap（1-覆盖率）连续控制
%
% 保留项（按用户决定不削减）：
%   - 指标子系统 use_indicator（默认开启；degeneracy>=0.45 触发）
%   - degeneracy>=0.45 触发阈值、theta=5、GetOutput_PBI 区间、N/4、K-means 等隐藏常数原样不动

    methods
        function main(Algorithm, Problem)
            %% ============ 参数设置 ============
            % 仅保留 2 个参数：use_indicator（是否启用指标辅助选择，默认 1）、debug
            % 其余 8 个外部超参已全部内生化（见下方各模块），不再作为可调位置暴露
            [use_indicator,debug] = Algorithm.ParameterSet(1,0);

            %% ============ 初始化种群 ============
            % 注：沿用完整版的 N 设置（与已跑实验保持一致，便于公平对比）
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            % 拉丁超立方采样生成初始解（保证空间均匀覆盖）
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            % 将 [0,1] 映射到实际决策空间，然后真实评估
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            % Archive 累积所有真实评估过的解（最终输出）
            Archive    = Population;

            %% ============ 初始化指标轮盘选择系统 ============
            tau_indicator = 20;   % 滑动窗口大小（记录最近 20 代的选择结果）
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
                % 进化比例 = 已评估次数 / 总预算（0~1），用于 HPC 中自适应权重 alpha
                ratio = Problem.FE / Problem.maxFE;

                %% ---- 自适应参考解数量（k 已内生化）----
                % 原 k=6 只是下限，真正起作用的是 1.5*M；直接由目标维度决定
                k_eff = min(Problem.N, ceil(1.5*Problem.M));

                %% ---- 混合 PBI 分类 ----
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                %% ---- 运行时诊断 ----
                diagnostics = RuntimeDiagnostics(Population,N);
                mean_conf   = mean(confidence(:));

                %% ---- 关系对训练：始终软置信权重（删除 curriculum/weighted/conservative 切换）----
                % 对应削减文档第5章第1行：始终用软置信权重
                % 仅当置信度加权返回空集时（防御），退回无权重版本
                Input = Population.decs;
                [XXs,YYs,WWs] = GetRelationPairs_confidence(Input,Catalog,confidence);
                if isempty(XXs)
                    [XXs,YYs] = GetRelationPairs(Input,Catalog);
                    WWs = [];
                end

                % 如果关系对仍为空（极端情况），跳过本轮
                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    prev_p_err = 1;
                    continue;
                end

                %% ---- 训练关系预测模型（始终加权；返回 model_gain）----
                [net,TrainIn_struct,p_err,model_gain] = TrainRelationModel(XXs,YYs,WWs);

                %% ---- 指标轮盘选择（可选，use_indicator 控制）----
                indicator_flag = 1;
                IndicatorModel = [];
                Fitness = [];
                if use_indicator
                    try
                        [Fitness,indicator_flag,Lp] = IndicatorSelector(Population,indicator,Lp);
                    catch
                        Fitness = [];
                    end
                    % 若成功计算了 Fitness，训练一个 SVR 模型来预测它
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

                %% ---- 候选解选择模式（model_reliable 替代 tau_err；coverage_gap 连续控制）----
                % model_reliable = model_gain>0，即关系模型优于多数类基线（替代 tau_err）
                % 指标模式：model_reliable 且 degeneracy>=0.45（0.45 阈值保持，不在削减范围内）
                % explore 模式：model_reliable 即触发，探索强度由 coverage_gap 连续调节
                model_reliable = model_gain > 0;
                candidate_mode = 'conservative';
                if use_indicator && model_reliable && diagnostics.degeneracy >= 0.45
                    candidate_mode = 'indicator';
                elseif model_reliable
                    candidate_mode = 'explore';
                end

                %% ---- 覆盖感知的评估批量大小（替代 n_min/n_max，削减文档第4.6）----
                % 覆盖好时少评估，覆盖差时多评估；随种群规模自然变化
                n_base  = max(1, ceil(Problem.N/25));
                n_extra = ceil((1 - diagnostics.coverage) * Problem.N/50);
                n_eval  = n_base + n_extra;

                %% ---- 构建代理模型结构体 ----
                Smodel = struct();
                Smodel.X              = Input;
                Smodel.Y              = Catalog;
                Smodel.mp_struct      = TrainIn_struct;
                Smodel.net            = net;
                Smodel.p_err          = p_err;
                Smodel.model_gain     = model_gain;      % 替代 lambda0 / p_err/0.45
                Smodel.ratio          = ratio;
                Smodel.coverage_gap   = 1 - diagnostics.coverage;  % 连续控制探索强度，替代 coverage<0.60
                Smodel.coverage       = diagnostics.coverage;
                Smodel.n_eval         = n_eval;          % 替代 n_min/n_max
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.mode           = candidate_mode;

                %% ---- 代理模型辅助选择（gmax 已内生化为 wmax）----
                % wmax 随种群规模增长、不随问题手调（替代 gmax=3000，削减文档第4.2）
                wmax = Problem.N * ceil(log2(Problem.N + 1));
                Next = AdaMaOSelection(Problem,Ref,Population.decs,wmax,Smodel);

                % 如果代理选择失败（Next 为空），用 GA 生成备选候选
                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs],{1,15,1,5});
                    Next = Next(1:min(n_eval,size(Next,1)),:);
                end

                %% ---- 真实评估候选解 ----
                NewSols = [];
                ArchiveSizeBefore = length(Archive);
                if ~isempty(Next) && remain > 0
                    % 截断到剩余预算内
                    Next = Next(1:min(size(Next,1),remain),:);
                    % 真实评估并加入 Archive
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols];
                end

                %% ---- 指标反馈（可选）----
                if use_indicator && ~isempty(Fitness)
                    score = IndicatorFeedbackScore(Archive,NewSols,ArchiveSizeBefore);
                    indicator = UpdateInformation(indicator_flag,score,indicator);
                end

                %% ---- 调试输出（可选）----
                if debug
                    fprintf(['[AdaMaO-Simple Gen %3d | FE=%4d/%4d] rel=conf-weighted cand=%s ', ...
                             'p_err=%.3f mgain=%.3f cov=%.3f deg=%.3f cgap=%.3f conf=%.3f n=%d\n'], ...
                        gen,Problem.FE,Problem.maxFE,candidate_mode, ...
                        p_err,model_gain,diagnostics.coverage,diagnostics.degeneracy, ...
                        1-diagnostics.coverage,mean_conf,length(NewSols));
                end

                %% ---- 更新状态 ----
                prev_p_err = p_err;
                % 从 Archive 中选择 N 个解作为下一代种群（RSEA 雷达网格策略）
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

%% ============ 辅助函数：运行时诊断 ============
function diagnostics = RuntimeDiagnostics(Population,Nref)
% RuntimeDiagnostics - 计算种群的运行时诊断指标
%
% 输出：
%   diagnostics.coverage   : 参考向量覆盖率（0~1，越高表示种群分布越广）
%   diagnostics.degeneracy : 种群退化度（0~1，越高表示种群越集中在某些区域）
%   （degeneracy 仍用于指标模式触发，阈值 0.45 不在削减范围内）

    PopObj = Population.objs;
    % 归一化目标值到 [0,1]
    PopObj = NormalizeObjectives(PopObj);
    [N,M] = size(PopObj);

    if N == 0 || M == 0
        diagnostics.coverage   = 0;
        diagnostics.degeneracy = 0;
        return;
    end

    % 生成均匀分布的参考向量
    V = UniformPoint(Nref,M,'ILD');
    V = V ./ max(vecnorm(V,2,2),eps);

    % 计算每个解的方向（归一化到单位向量）
    Direction = PopObj;
    rowNorm = vecnorm(Direction,2,2);
    zeroRows = rowNorm < 1e-12;
    Direction(zeroRows,:) = 1 ./ max(M,1);
    rowNorm(zeroRows) = vecnorm(Direction(zeroRows,:),2,2);
    Direction = Direction ./ max(rowNorm,eps);

    % 计算覆盖率：有多少参考向量被种群中的解"覆盖"
    cosine = 1 - pdist2(Direction,V,'cosine');
    [~,assigned] = max(cosine,[],2);
    diagnostics.coverage = numel(unique(assigned)) / size(V,1);

    % 计算退化度：使用 SVD 分析种群的分布
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
        % 找到解释 90% 能量所需的秩
        rank90 = find(cumsum(energy)./total >= 0.90,1,'first');
    end
    % 退化度 = 1 - (所需秩 / 目标维度)
    diagnostics.degeneracy = max(0,min(1,1 - rank90/max(M,1)));
end

%% ============ 辅助函数：目标值归一化 ============
function PopObj = NormalizeObjectives(PopObj)
% NormalizeObjectives - 将目标值归一化到 [0,1]
    zmin = min(PopObj,[],1);
    zmax = max(PopObj,[],1);
    span = zmax - zmin;
    span(span < 1e-12) = 1;
    PopObj = (PopObj - zmin) ./ span;
    PopObj(isnan(PopObj) | isinf(PopObj)) = 0;
end

%% ============ 辅助函数：训练关系预测模型 ============
function [net,TrainIn_struct,p_err,model_gain] = TrainRelationModel(XXs,YYs,WWs)
% TrainRelationModel - 训练关系预测神经网络（超参数削减版）
%
% 改动（相对完整版）：
%   1. 始终使用置信度加权（若提供了 WWs），不再有 w_min 下限截断
%      （权重已由 GetRelationPairs_confidence 输出为 W=0.5+0.5*sqrt(conf_i*conf_j)，天然落在 [0.5,1]）
%   2. 计算 model_gain（多数类基线相对增益）替代 tau_err / p_err/0.45 硬阈值
%      model_gain = max(0, (p_base - p_err)/p_base)
%      - 模型只是比多数类猜测还差时 model_gain=0（不信任）
%      - 模型明显优于基线时 model_gain>0（允许探索）
%      - 早期探索更强、后期自然收缩（由 (1-ratio) 在候选选择处进一步调节）

    % 根据是否有权重，选择不同的数据处理方式
    use_weights = ~isempty(WWs);
    if use_weights
        [TrainIn,TrainOut,TrainW,TestIn,TestOut,~] = DataProcess_confidence(XXs,YYs,WWs);
    else
        [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
        TrainW = [];
    end

    % 输入维度 = 2D（两个解的决策变量拼接）
    xDim = size(TrainIn,2);

    % 归一化输入到 [-1,1]
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';

    % 将标签 {-1,0,1} 转为 one-hot 编码
    TrainOut_onehot = onehotconv(TrainOut,1);

    % 三层前馈网络，节点数依次为 1.5*xDim, xDim, 0.5*xDim
    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;  % 不弹出训练窗口

    % 加权训练（已无 w_min 下限截断，仅做均值归一化）
    if use_weights && ~isempty(TrainW)
        EW = TrainW(:)';
        if mean(EW) > 1e-12
            EW = EW ./ mean(EW);  % 归一化使均值为 1
        else
            EW = ones(size(EW));  % 防御：权重全为 0 时退化为等权
        end
        net = train(net,TrainIn_nor',TrainOut_onehot',[],[],EW);
    else
        net = train(net,TrainIn_nor',TrainOut_onehot');
    end

    % 测试集评估
    if isempty(TestIn)
        p_err = 1;  % 无测试集时假设误差最大
    else
        TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
        TestPre = onehotconv(net(TestIn_nor')',2);
        p_err = sum(TestPre ~= TestOut) / size(TestPre,1);
    end
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end

    % 多数类基线误差与 model_gain（替代 tau_err / p_err/0.45）
    cls = TestOut(:);
    if isempty(cls)
        model_gain = 0;
    else
        % 统计 -1/0/+1 三类样本数
        counts = histcounts(cls, [-1.5,-0.5,0.5,1.5]);
        p_base = 1 - max(counts)/sum(counts);   % 多数类基线的错误率
        model_gain = max(0, (p_base - p_err) / max(p_base, eps));
    end
end

%% ============ 辅助函数：指标反馈分数计算 ============
function score = IndicatorFeedbackScore(Archive,NewSols,ArchiveSizeBefore)
% IndicatorFeedbackScore - 计算新解的指标反馈分数
%
%   0 = 新解被原始 NDSort 支配（不好）
%   1 = 新解在 NDSort 第一层但被 NDSort_SDR 第一层排除（一般）
%   2 = 新解同时在 NDSort 和 NDSort_SDR 第一层（很好）

    score = 0;
    if isempty(NewSols)
        return;
    end

    try
        % 标准非支配排序
        [FrontNo_all,~] = NDSort(Archive.objs,1);
        % 找到新解在 Archive 中的索引
        new_idx = ArchiveSizeBefore + (1:length(NewSols));
        new_idx = new_idx(new_idx <= length(FrontNo_all));
        if isempty(new_idx) || ~any(FrontNo_all(new_idx) == 1)
            return;
        end

        % 新解在 NDSort 第一层，基础分数为 1
        score = 1;
        % 提取 NDSort 第一层的子集
        F1_subset = Archive(FrontNo_all == 1);
        % 对子集使用 NDSort_SDR（强支配关系排序）
        [FrontNo_SDR,~] = NDSort_SDR(F1_subset,1);
        % 检查新解是否也在 SDR 第一层
        new_in_F1_subset_idx = ismember(F1_subset.decs,NewSols.decs,'rows');
        if any(FrontNo_SDR(new_in_F1_subset_idx) == 1)
            score = 2;
        end
    catch
        score = min(score,1);
    end
end
