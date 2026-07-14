classdef REMO_new2_AdaMaO < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% AdaMaO: 自适应多目标优化算法（Adaptive Many-objective Algorithm）
% k: 参考解数量基数（HPC 内部 RefSelect 选解数）
% gmax: 代理辅助 GA 内循环的累计样本上限
% q_keep: 候选解筛选的分位数阈值（保留得分前 q_keep 比例的候选）
% lambda0: 不确定性权重的基础系数
% w_min: 样本权重的下限（防止权重过小导致训练不稳定）
% n_min: 每轮真实评估的最少候选解数量
% n_max: 每轮真实评估的最多候选解数量
% tau_err: 模型误差阈值（用于决定关系对模式）
% use_indicator: 是否启用指标轮盘选择（1=启用，0=禁用）
% debug: 是否打印调试信息（1=打印，0=不打印）

% 本算法是 REMO_new2_WFG10 的自适应版本，核心改进：
% 1. 根据运行时诊断结果，动态切换关系对训练模式
% 2. 根据模型精度和种群状态，动态切换候选解选择模式
% 3. 引入 PIEA 的指标轮盘选择机制，增强多样性
%
% 算法保留了 WFG10 版本的置信度加权和不确定性感知工具，
% 但只在运行时诊断表明它们有用时才启用这些功能。
%
% 适用场景：
%   - 决策变量维度 D：任意
%   - 目标维度 M：多目标/高维多目标（many-objective）
%   - 评估代价：昂贵（expensive），真实评估次数受预算限制

    methods
        function main(Algorithm, Problem)
            %% ============ 参数设置 ============
            % k: 参考解数量基数（HPC 内部 RefSelect 选解数）
            % gmax: 代理辅助 GA 内循环的累计样本上限
            % q_keep: 候选解筛选的分位数阈值（保留得分前 q_keep 比例的候选）
            % lambda0: 不确定性权重的基础系数
            % w_min: 样本权重的下限（防止权重过小导致训练不稳定）
            % n_min: 每轮真实评估的最少候选解数量
            % n_max: 每轮真实评估的最多候选解数量
            % tau_err: 模型误差阈值（用于决定关系对模式）
            % use_indicator: 是否启用指标轮盘选择（1=启用，0=禁用）
            % debug: 是否打印调试信息（1=打印，0=不打印）
            [k,gmax,q_keep,lambda0,w_min,n_min,n_max,tau_err,use_indicator,debug] = ...
                Algorithm.ParameterSet(6,3000,0.80,0.35,0.30,4,6,0.35,1,0);

            %% ============ 初始化种群 ============
            % 根据决策变量维度 D 确定种群规模 N
            % D <= 10 时用 11D-1（经验公式），否则固定为 100
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
            % tau_indicator: 滑动窗口大小（记录最近 20 代的选择结果）
            tau_indicator = 20;

            % 三种性能指标，每个指标记录：
            %   method: 指标名称
            %   Choose_record: 被选中的次数记录（滑动窗口）
            %   Win_record: 选中后的成功次数记录（滑动窗口）
            %   Pw: 当前被选中的概率（轮盘赌权重）
            % 初始时三个指标等概率（各 1/3）
            indicator(1) = struct('method','SDE',        'Choose_record',ones(1,tau_indicator), ...
                                  'Win_record',ones(1,tau_indicator),'Pw',1/3);
            indicator(2) = struct('method','I_epsilon+', 'Choose_record',ones(1,tau_indicator), ...
                                  'Win_record',ones(1,tau_indicator),'Pw',1/3);
            indicator(3) = struct('method','Minkowski',  'Choose_record',ones(1,tau_indicator), ...
                                  'Win_record',ones(1,tau_indicator),'Pw',1/3);

            % Lp: Minkowski 距离的形状参数（由 Shape_Estimate 估计）
            % prev_p_err: 上一代的模型测试误差（用于决定关系对模式）
            % gen: 代数计数器
            Lp         = 1;
            prev_p_err = 1;
            gen        = 0;

            %% ============ 主优化循环 ============
            while Algorithm.NotTerminated(Archive)
                gen   = gen + 1;
                % 进化比例 = 已评估次数 / 总预算（0~1）
                % 用于 HPC 中自适应权重 alpha 的计算
                ratio = Problem.FE / Problem.maxFE;

                %% ---- 自适应参考解数量 ----
                % 取 k 和 1.5*M 中的较大者，但不超过种群规模
                % 高维目标需要更多参考解来覆盖 Pareto 前沿
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));

                %% ---- 混合 PBI 分类 ----
                % 对种群中的解进行好坏分类，同时输出置信度和参考解
                % 'Nref': 参考向量数量, 'k': 参考解数量, 'theta': PBI 惩罚系数
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                %% ---- 运行时诊断 ----
                % 计算种群的覆盖率和退化度，用于决定后续策略
                % coverage: 参考向量的覆盖率（越高表示种群分布越广）
                % degeneracy: 种群退化度（越高表示种群越集中在某些区域）
                diagnostics = RuntimeDiagnostics(Population,N);
                mean_conf   = mean(confidence(:));

                %% ---- 动态选择关系对训练模式 ----
                % 根据模型精度和种群状态，选择不同的关系对生成策略
                %
                % 'conservative'（保守模式）：使用原始 GetRelationPairs，无权重
                %   - 适用条件：默认模式
                %   - 特点：简单稳定，适合早期探索
                %
                % 'curriculum'（课程学习模式）：只保留高置信度样本
                %   - 适用条件：上一代模型误差大（prev_p_err > tau_err）
                %   - 特点：过滤掉低置信度样本，减少噪声干扰
                %
                % 'weighted'（加权模式）：使用置信度加权的关系对
                %   - 适用条件：模型精度好 且 置信度高 且 覆盖率低
                %   - 特点：让高置信度样本对模型影响更大
                relation_mode = 'conservative';
                if prev_p_err > tau_err
                    relation_mode = 'curriculum';
                elseif prev_p_err <= tau_err && mean_conf >= 0.55 && diagnostics.coverage < 0.60
                    relation_mode = 'weighted';
                end

                %% ---- 生成关系对样本 ----
                % 获取决策变量
                Input = Population.decs;
                % 根据选择的模式生成关系对
                switch relation_mode
                    case 'weighted'
                        % 加权模式：返回关系对 XXs, YYs 和权重 WWs
                        [XXs,YYs,WWs] = GetRelationPairs_confidence(Input,Catalog,confidence);
                    case 'curriculum'
                        % 课程学习模式：只保留高置信度样本（前 80%）
                        [XXs,YYs] = GetRelationPairs_curriculum(Input,Catalog,confidence,0.80);
                        WWs = [];
                    otherwise
                        % 保守模式：使用原始方法，无权重
                        [XXs,YYs] = GetRelationPairs(Input,Catalog);
                        WWs = [];
                end

                % 如果关系对为空（极端情况），跳过本轮
                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    prev_p_err = 1;
                    continue;
                end

                %% ---- 训练关系预测模型 ----
                % 根据是否有权重，选择不同的数据处理和训练方式
                [net,TrainIn_struct,p_err] = TrainRelationModel( ...
                    XXs,YYs,WWs,w_min,strcmp(relation_mode,'weighted'));

                %% ---- 指标轮盘选择（可选） ----
                % 如果启用指标选择，使用 PIEA 的三种指标之一来评估种群
                % 这三种指标各有特点：
                %   SDE: 移位密度估计，适合分布均匀的前沿
                %   I_epsilon+: 加性 epsilon 指标，适合收敛性评估
                %   Minkowski: Minkowski 距离，适合特定形状的前沿
                indicator_flag = 1;
                IndicatorModel = [];
                Fitness = [];
                if use_indicator
                    try
                        % IndicatorSelector 返回：
                        %   Fitness: 当代的性能指标值
                        %   indicator_flag: 选中的指标编号（1/2/3）
                        %   Lp: 估计的 PF 形状参数
                        [Fitness,indicator_flag,Lp] = IndicatorSelector(Population,indicator,Lp);
                    catch
                        Fitness = [];
                    end
                    % 如果成功计算了 Fitness，训练一个 SVR 模型来预测它
                    % 这个模型用于在候选解选择阶段快速评估候选解的指标值
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
                % 根据模型精度、种群状态和指标模型可用性，选择不同的候选解选择策略
                %
                % 'conservative'（保守模式）：仅使用关系得分，选择 n_min 个候选
                %   - 适用条件：默认模式
                %   - 特点：简单稳定，适合模型精度不高时
                %
                % 'explore'（探索模式）：关系得分 + 不确定性 + 决策空间多样性
                %   - 适用条件：模型精度好 且 覆盖率低
                %   - 特点：鼓励探索不确定性高的区域，同时保持多样性
                %
                % 'indicator'（指标模式）：关系得分粗筛 + SVR 指标重排序
                %   - 适用条件：有指标模型 且 模型精度好 且 种群退化度高
                %   - 特点：使用 PIEA 的指标思想，优先选择指标值好的候选
                candidate_mode = 'conservative';
                if use_indicator && p_err <= tau_err && diagnostics.degeneracy >= 0.45
                    candidate_mode = 'indicator';
                elseif p_err <= tau_err && diagnostics.coverage < 0.60
                    candidate_mode = 'explore';
                end

                %% ---- 构建代理模型结构体 ----
                % 传递给 AdaMaOSelection 使用
                Smodel = struct();
                Smodel.X              = Input;           % 训练数据的决策变量
                Smodel.Y              = Catalog;         % 好/坏标签
                Smodel.mp_struct      = TrainIn_struct;  % 归一化参数（预测时复用）
                Smodel.net            = net;             % 训练好的神经网络
                Smodel.p_err          = p_err;           % 测试集分类错误率
                Smodel.lambda0        = lambda0;         % 不确定性权重基础系数
                Smodel.ratio          = ratio;           % 当前进化比例
                Smodel.IndicatorModel = IndicatorModel;  % SVR 指标模型（可能为空）
                Smodel.mode           = candidate_mode;  % 候选解选择模式
                Smodel.q_keep         = q_keep;          % 分位数阈值
                Smodel.n_min          = n_min;           % 每轮最少评估数
                Smodel.n_max          = n_max;           % 每轮最多评估数

                %% ---- 代理模型辅助选择 ----
                % 在代理模型指导下，通过 GA 内循环筛选候选解
                % AdaMaOSelection 会根据 Smodel.mode 选择不同的筛选策略
                Next = AdaMaOSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel,q_keep,n_min,n_max);

                % 如果代理选择失败（Next 为空），用 GA 生成备选候选
                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs],{1,15,1,5});
                    Next = Next(1:min(n_min,size(Next,1)),:);
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

                %% ---- 指标反馈（可选） ----
                % 如果启用了指标选择，计算新解的反馈分数，更新指标轮盘
                % 反馈分数：
                %   0 = 新解被原始 NDSort 支配
                %   1 = 新解在 NDSort 第一层但被 NDSort_SDR 第一层排除
                %   2 = 新解同时在 NDSort 和 NDSort_SDR 第一层
                if use_indicator && ~isempty(Fitness)
                    score = IndicatorFeedbackScore(Archive,NewSols,ArchiveSizeBefore);
                    indicator = UpdateInformation(indicator_flag,score,indicator);
                end

                %% ---- 调试输出（可选） ----
                if debug
                    fprintf(['[AdaMaO Gen %3d | FE=%4d/%4d] rel=%s cand=%s ', ...
                             'p_err=%.3f prev=%.3f cov=%.3f deg=%.3f conf=%.3f n=%d\n'], ...
                        gen,Problem.FE,Problem.maxFE,relation_mode,candidate_mode, ...
                        p_err,prev_p_err,diagnostics.coverage,diagnostics.degeneracy, ...
                        mean_conf,length(NewSols));
                end

                %% ---- 更新状态 ----
                prev_p_err = p_err;
                % 从 Archive 中选择 N 个解作为下一代种群
                % 使用 RSEA 的雷达网格策略
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

%% ============ 辅助函数：运行时诊断 ============
function diagnostics = RuntimeDiagnostics(Population,Nref)
% RuntimeDiagnostics - 计算种群的运行时诊断指标
%
% 输入：
%   Population : 当前种群
%   Nref       : 参考向量数量（用于计算覆盖率）
%
% 输出：
%   diagnostics.coverage   : 参考向量覆盖率（0~1，越高表示种群分布越广）
%   diagnostics.degeneracy : 种群退化度（0~1，越高表示种群越集中在某些区域）
%
% 设计动机：
%   - coverage 低表示种群没有覆盖所有参考方向，需要鼓励探索
%   - degeneracy 高表示种群在某些区域过度集中，需要使用指标选择来增强多样性

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
    % 覆盖标准：解的方向与参考向量的余弦相似度最大
    cosine = 1 - pdist2(Direction,V,'cosine');
    [~,assigned] = max(cosine,[],2);
    diagnostics.coverage = numel(unique(assigned)) / size(V,1);

    % 计算退化度：使用 SVD 分析种群的分布
    % 如果种群集中在某些维度，SVD 的前几个奇异值会占主导
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
    % 退化度越高，表示种群越集中在低维子空间
    diagnostics.degeneracy = max(0,min(1,1 - rank90/max(M,1)));
end

%% ============ 辅助函数：目标值归一化 ============
function PopObj = NormalizeObjectives(PopObj)
% NormalizeObjectives - 将目标值归一化到 [0,1]
%
% 输入：
%   PopObj : N x M 原始目标值矩阵
%
% 输出：
%   PopObj : N x M 归一化后的目标值矩阵

    zmin = min(PopObj,[],1);
    zmax = max(PopObj,[],1);
    span = zmax - zmin;
    span(span < 1e-12) = 1;
    PopObj = (PopObj - zmin) ./ span;
    PopObj(isnan(PopObj) | isinf(PopObj)) = 0;
end

%% ============ 辅助函数：课程学习模式的关系对生成 ============
function [XXs,YYs] = GetRelationPairs_curriculum(Input,Catalog,confidence,q_keep)
% GetRelationPairs_curriculum - 课程学习模式的关系对生成
%
% 课程学习（Curriculum Learning）思想：
%   先用"简单"（高置信度）的样本训练，再逐步引入"难"（低置信度）的样本
%   本函数只保留置信度最高的 q_keep 比例的样本，过滤掉低置信度样本
%
% 输入：
%   Input      : N x D 决策变量矩阵
%   Catalog    : N x 1 logical，好类(true) / 坏类(false)
%   confidence : N x 1 置信度
%   q_keep     : 保留比例（默认 0.80，即保留前 80%）
%
% 输出：
%   XXs : n_pair x 2D 关系对样本
%   YYs : n_pair x 1 关系标签 {-1, 0, +1}

    Catalog = Catalog(:);
    confidence = confidence(:);

    % 分离好类和坏类
    good_idx = find(Catalog == 1);
    rest_idx = find(Catalog ~= 1);

    % 对每类只保留置信度最高的 q_keep 比例
    good_idx = KeepMostConfident(good_idx,confidence,q_keep);
    rest_idx = KeepMostConfident(rest_idx,confidence,q_keep);

    % 合并保留的索引
    keep_idx = [good_idx;rest_idx];

    % 防御：如果某一类为空或样本太少，返回空集
    if numel(good_idx) < 1 || numel(rest_idx) < 1 || numel(keep_idx) < 2
        XXs = zeros(0,2*size(Input,2));
        YYs = zeros(0,1);
        return;
    end

    % 重建 Catalog（只包含保留的样本）
    Catalog2 = false(numel(keep_idx),1);
    Catalog2(1:numel(good_idx)) = true;

    % 使用原始 GetRelationPairs 生成关系对
    [XXs,YYs] = GetRelationPairs(Input(keep_idx,:),Catalog2);
end

%% ============ 辅助函数：保留最置信的样本 ============
function idx = KeepMostConfident(idx,confidence,q_keep)
% KeepMostConfident - 从索引集合中保留置信度最高的 q_keep 比例
%
% 输入：
%   idx        : 原始索引向量
%   confidence : 置信度向量
%   q_keep     : 保留比例
%
% 输出：
%   idx : 保留的索引向量

    idx = idx(:);
    if isempty(idx)
        return;
    end
    % 按置信度降序排序
    [~,order] = sort(confidence(idx),'descend');
    % 保留前 q_keep 比例（至少保留 1 个）
    n_keep = max(1,ceil(q_keep*numel(idx)));
    idx = idx(order(1:n_keep));
end

%% ============ 辅助函数：训练关系预测模型 ============
function [net,TrainIn_struct,p_err] = TrainRelationModel(XXs,YYs,WWs,w_min,use_weights)
% TrainRelationModel - 训练关系预测神经网络
%
% 输入：
%   XXs         : n_pair x 2D 关系对样本
%   YYs         : n_pair x 1 关系标签 {-1, 0, +1}
%   WWs         : n_pair x 1 样本权重（可能为空）
%   w_min       : 样本权重的下限
%   use_weights : 是否使用权重训练
%
% 输出：
%   net            : 训练好的神经网络
%   TrainIn_struct : 归一化参数（预测时复用）
%   p_err          : 测试集分类错误率

    % 根据是否有权重，选择不同的数据处理方式
    if use_weights
        [TrainIn,TrainOut,TrainW,TestIn,TestOut,~] = DataProcess_confidence(XXs,YYs,WWs);
    else
        [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
        TrainW = [];
    end

    % 输入维度 = 2D（两个解的决策变量拼接）
    xDim = size(TrainIn,2);

    % 归一化输入到 [-1,1]（mapminmax 按行处理，所以先转置）
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';

    % 将标签 {-1,0,1} 转为 one-hot 编码 [0,0,1]/[0,1,0]/[1,0,0]
    TrainOut_onehot = onehotconv(TrainOut,1);

    % 三层前馈网络，节点数依次为 1.5*xDim, xDim, 0.5*xDim
    % patternnet 带 softmax 输出，适合多分类
    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;  % 不弹出训练窗口

    % 根据是否有权重，选择不同的训练方式
    if use_weights && ~isempty(TrainW)
        % 计算样本权重 EW（归一化后下限截断）
        EW = TrainW(:)';
        if mean(EW) > 1e-12
            EW = EW ./ mean(EW);  % 归一化使均值为 1
        else
            EW = ones(size(EW));  % 防御：权重全为 0 时退化为等权
        end
        EW = max(EW,w_min);  % 下限截断，防止极小权重导致训练不稳定
        % train 函数的第 6 个参数是样本权重
        net = train(net,TrainIn_nor',TrainOut_onehot',[],[],EW);
    else
        % 无权重训练
        net = train(net,TrainIn_nor',TrainOut_onehot');
    end

    % 测试集评估
    if isempty(TestIn)
        p_err = 1;  % 无测试集时假设误差最大
    else
        % 用训练集的归一化参数变换测试集
        TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
        % 网络预测，onehotconv 模式 2 将概率转回标签
        TestPre = onehotconv(net(TestIn_nor')',2);
        % 分类错误率
        p_err = sum(TestPre ~= TestOut) / size(TestPre,1);
    end
    % 防御：NaN 或 Inf 时设为最大误差
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
end

%% ============ 辅助函数：指标反馈分数计算 ============
function score = IndicatorFeedbackScore(Archive,NewSols,ArchiveSizeBefore)
% IndicatorFeedbackScore - 计算新解的指标反馈分数
%
% 反馈分数用于更新指标轮盘的选择概率
%
% 输入：
%   Archive            : 累积的所有真实评估解
%   NewSols            : 本轮新评估的解
%   ArchiveSizeBefore  : 本轮评估前的 Archive 大小
%
% 输出：
%   score : 反馈分数
%           0 = 新解被原始 NDSort 支配（不好）
%           1 = 新解在 NDSort 第一层但被 NDSort_SDR 第一层排除（一般）
%           2 = 新解同时在 NDSort 和 NDSort_SDR 第一层（很好）
%
% 设计动机：
%   NDSort_SDR 使用强支配关系（Strengthened Dominance Relation），
%   比标准 NDSort 更严格。能同时通过两个排序的解是真正"脱颖而出"的解。

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
            % 新解同时在两个排序的第一层，分数为 2
            score = 2;
        end
    catch
        score = min(score,1);
    end
end
