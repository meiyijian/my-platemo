classdef REMO_new2_AdaMaO_SDEOnly < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% AdaMaO SDE-only: 固定 SDE 指标的自适应多目标优化算法
%
% 本算法是 REMO_new2_WFG10 的自适应版本，核心改进：
% 1. 根据运行时诊断结果，动态切换关系对训练模式
% 2. 根据模型精度和种群状态，动态切换候选解选择模式
% 3. 固定使用 PIEA 的 SDE 指标，取消多指标轮盘及其反馈
%
% 算法保留了 WFG10 版本的 PBI 表征一致性加权和 softmax 预测模糊度工具，
% 并通过固定阈值决定是否启用相应分支；这些诊断量是否能代表真实搜索风险需另行验证。
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
            % q_keep: 候选解筛选的分位点（0.80 通常保留高于 80% 分位点、即最高约 20% 的候选）
            % lambda0: softmax 预测模糊度奖励的基础系数
            % w_min: 样本权重的下限（防止权重过小导致训练不稳定）
            % n_min: 每轮真实评估的最少候选解数量
            % n_max: 每轮真实评估的最多候选解数量
            % tau_err: 模型误差阈值（用于决定关系对模式）
            % use_indicator: 是否启用固定 SDE 指标模型（1=启用，0=禁用）
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
            % 拉丁超立方采样生成初始解（改善各决策维度的边际分层覆盖，不保证联合空间完全均匀）
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            % 将 [0,1] 映射到实际决策空间，然后真实评估
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            % Archive 累积所有真实评估过的解（最终输出）
            Archive    = Population;

            %% ============ 初始化固定 SDE 指标 ============
            % Lp 由 Shape_Estimate 每代更新，并供当前 SDE 的低分兜底使用
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
                % 随目标数增加代表解数量；这是经验规模规则，不等同于保证 Pareto 前沿覆盖
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));

                %% ---- 混合 PBI 分类 ----
                % 对种群构造融合排名：前 1/4 标为正组，其余 3/4 标为非正组；同时输出 PBI 表征一致性和代表解
                % 'Nref': 参考向量数量, 'k': 参考解数量, 'theta': PBI 惩罚系数
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                %% ---- 运行时诊断 ----
                % 计算均匀方向占用率和目标矩阵线性维数集中度，用于固定阈值路由
                % coverage: 均匀参考方向的占用比例；其可达上界受种群规模和实际方向数限制
                % degeneracy: 目标矩阵的线性维数集中度，不直接等同于拥挤或区域覆盖不足
                diagnostics = RuntimeDiagnostics(Population,N);
                mean_conf   = mean(confidence(:));

                %% ---- 动态选择关系对训练模式 ----
                % 根据关系对留出误差、PBI 表征一致性和方向占用比例，选择不同的关系对生成策略
                %
                % 'conservative'（等权模式）：使用原始 GetRelationPairs，无权重
                %   - 适用条件：默认模式
                %   - 特点：所有粗组别关系对等权；并不减少对关系模型的依赖
                %
                % 'curriculum'（高一致性过滤模式，名称为兼容保留）：每组固定保留一致性较高的样本
                %   - 适用条件：上一代模型误差大（prev_p_err > tau_err）
                %   - 特点：固定过滤每组一致性最低的 20%，没有逐步从易到难的课程日程
                %
                % 'weighted'（一致性加权模式）：使用 PBI 双表征一致性加权关系对
                %   - 适用条件：上一代关系对留出误差不高、平均一致性较高且方向占用率低于固定阈值
                %   - 特点：让两端一致性分数较高的关系对权重更大；一致性不等于标签正确概率
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
                        % 高一致性过滤模式：每组只保留一致性分数最高的 80%
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
                % 根据是否有权重，选择不同的数据处理和训练方式；p_err 是关系对随机留出误差
                [net,TrainIn_struct,p_err] = TrainRelationModel( ...
                    XXs,YYs,WWs,w_min,strcmp(relation_mode,'weighted'));

                %% ---- 固定 SDE 指标（可选） ----
                % 保留原有外层开关，但指标启用时始终使用当前 SDE-based 分数
                IndicatorModel = [];
                Fitness = [];
                if use_indicator
                    try
                        [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp);
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
                % 根据关系对留出误差和两个启发式诊断量选择候选策略；模式名不代表已验证的风险状态
                %
                % 'conservative'（纯关系小批量模式）：仅使用关系得分，选择 n_min 个候选
                %   - 适用条件：默认模式
                %   - 特点：仍完全依赖关系模型，只是不加入预测模糊度和批次距离项
                %
                % 'explore'（预测模糊度探索模式）：关系得分 + softmax 预测模糊度 + 决策空间分散性
                %   - 触发条件：关系对留出误差不高且方向占用率低于固定阈值
                %   - 特点：奖励输出概率较不尖锐的候选；该量不是认知不确定性，也不能保证识别分布外区域
                %
                % 'indicator'（指标模式）：关系得分粗筛 + 可用时由 SVR 指标值重排序
                %   - 触发条件：启用指标分支、关系对留出误差不高且线性维数集中度达到阈值
                %   - 注意：触发条件未检查 IndicatorModel 是否非空，模型不可用时会回退到关系得分
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
                Smodel.p_err          = p_err;           % 随机留出关系对的分类错误率，不是未见基础解上的严格泛化误差
                Smodel.lambda0        = lambda0;         % softmax 预测模糊度奖励基础系数
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
                if ~isempty(Next) && remain > 0
                    % 截断到剩余预算内
                    Next = Next(1:min(size(Next,1),remain),:);
                    % 真实评估并加入 Archive
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols];
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
%   Nref       : 请求的参考方向数量（ILD 实际产生的方向数可能大于该值）
%
% 输出：
%   diagnostics.coverage   : 均匀参考方向占用率（0~1；上界受解数/实际方向数限制）
%   diagnostics.degeneracy : 目标矩阵线性维数集中度（0~1；不直接衡量拥挤或区域覆盖）
%
% 设计动机：
%   - coverage 低仅表示较少均匀方向被分配到解，是否需要探索取决于方向数校准
%   - degeneracy 高表示 90% 线性能量由较少奇异方向解释，不等同于种群在少数 PF 区域拥挤

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

    % 计算方向占用率：统计有多少参考向量至少被一个解分配
    % 分配标准：解的归一化目标方向与参考向量的余弦相似度最大
    cosine = 1 - pdist2(Direction,V,'cosine');
    [~,assigned] = max(cosine,[],2);
    diagnostics.coverage = numel(unique(assigned)) / size(V,1);

    % 计算线性维数集中度：使用 SVD 分析归一化目标矩阵
    % 如果主要线性变化由少数奇异方向解释，前几个奇异值会占主导
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
    % 线性维数集中度 = 1 - (所需秩 / 目标维度)
    % 数值越高，表示当前目标矩阵的 90% 线性能量集中在更少奇异方向
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

%% ============ 辅助函数：高一致性过滤模式的关系对生成 ============
function [XXs,YYs] = GetRelationPairs_curriculum(Input,Catalog,confidence,q_keep)
% GetRelationPairs_curriculum - 固定比例高一致性过滤（函数名为兼容保留）
%
% 函数名沿用 curriculum，但当前实现仅执行一次固定比例的高一致性样本过滤：
%   每个粗质量组只保留 PBI 双表征一致性最高的 q_keep 比例
%   本函数没有随训练逐步引入低一致性样本的课程日程
%
% 输入：
%   Input      : N x D 决策变量矩阵
%   Catalog    : N x 1 logical，正组(true) / 非正组(false)
%   confidence : N x 1 PBI 双表征一致性分数（变量名为兼容保留）
%   q_keep     : 保留比例（默认 0.80，即保留前 80%）
%
% 输出：
%   XXs : n_pair x 2D 关系对样本
%   YYs : n_pair x 1 关系标签 {-1, 0, +1}

    Catalog = Catalog(:);
    confidence = confidence(:);

    % 分离正组和非正组
    good_idx = find(Catalog == 1);
    rest_idx = find(Catalog ~= 1);

    % 对每组只保留一致性分数最高的 q_keep 比例
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
% KeepMostConfident - 从索引集合中保留一致性分数最高的 q_keep 比例
%
% 输入：
%   idx        : 原始索引向量
%   confidence : PBI 双表征一致性向量
%   q_keep     : 保留比例
%
% 输出：
%   idx : 保留的索引向量

    idx = idx(:);
    if isempty(idx)
        return;
    end
    % 按 PBI 双表征一致性分数降序排序
    [~,order] = sort(confidence(idx),'descend');
    % 保留一致性分数最高的 q_keep 比例（至少保留 1 个）
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
%   p_err          : 随机留出关系对的分类错误率；基础解和反向关系可能跨训练/测试集合出现

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
