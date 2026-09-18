function [good_idx, bad_idx, Catalog, confidence, Ref] = PBIQualityClassification(Population, ratio, varargin)
%PBIQualityClassification PBI-assisted quality classification (PAQC).
%   [good_idx,bad_idx,Catalog,confidence,Ref] = PBIQualityClassification(Population,RATIO)
%   根据已评价种群 Population 构造关系学习的正组 C1 和非正组 C2。
%   RATIO 为已用真实评价次数占总预算的比例，对应论文中的 t。
%
%   连续 PBI 质量得分 score_v 对应 S；基于参考解的二值标签 label_dyn
%   对应 L。融合得分 score_hybrid = (1-RATIO)*S + RATIO*L 对应 H。
%   两个信号均由当前已评价种群计算，参考方向用于连续评分，参考解用于二值分类。
%
%   [...] = PBIQualityClassification(Population,RATIO,'Nref',NREF,'k',K,'theta',THETA,'rGood',RGOOD)
%   指定均匀参考方向的请求数量、参考解数量、PBI 惩罚系数和正组比例。
%   默认值依次为种群规模、6、5 和 0.25。自适应方向的数量由非支配解集决定。
%
%   good_idx 为融合排名前 ceil(N*rGood) 个解的索引；Catalog 在这些
%   位置为 true，其余为 false。非正组包含所有未进入正组的解。
%   bad_idx 为融合排名最后 ceil(N*rGood) 个解的索引，主程序不使用此输出。
%   confidence 返回 1-abs(S-L)，主程序不使用此输出。
%   Ref 为从当前种群选出的已评价参考解，同时用于后续交配池。

    %% ============ 参数解析 ============
    N = length(Population);
    M = size(Population(1).obj, 2);
    Nref = get_option(varargin, 'Nref', N);    % 均匀参考方向的请求数量
    k = get_option(varargin, 'k', 6);          % 参考解数量
    theta = get_option(varargin, 'theta', 5);  % PBI 惩罚系数
    rGood = get_option(varargin, 'rGood', 0.25); % 正组比例
    if ~isscalar(rGood) || ~isnumeric(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('AdaMaO:InvalidPositiveGroupRatio', ...
            'rGood must be a finite scalar in (0,0.5].');
    end

    PopObj = [Population.objs];  % N x M 目标值矩阵

    %% ============ 步骤一：构造参考方向集合 ============
    % M<=3 或 N<50 时，使用均匀参考方向。
    if M <= 3 || N < 50
        V = UniformPoint(Nref, M, 'ILD');  % 均匀分布的参考方向
        V = V ./ vecnorm(V, 2, 2);         % 归一化为单位向量
    else
        % 其余情况根据当前非支配解构造参考方向，并检查回退条件。
        V = AdaptiveReferenceVectors(PopObj, Nref);
    end

    %% ============ 步骤二：选择当前种群的参考解 ============
    % 按径向网格选择已评价参考解，数量不超过 k。
    Ref = RefSelect(Population, k);
    RefObj = [Ref.objs];

    % 理想点（每个目标的最小值）
    Zmin = min(PopObj, [], 1);

    %% ============ 步骤三：计算连续 PBI 质量得分 S ============
    score_v = ContinuousPBIQualityAssessment(PopObj,V,Zmin,theta);

    %% ============ 步骤四：基于参考解生成二值标签 L ============
    % label_dyn 对应 L；归一化 PBI 值不大于 1 时取 1，否则取 0。
    label_dyn = RepresentativeBasedClassification(PopObj, RefObj);

    %% ============ 步骤五：融合得分 ============
    % alpha = 1 - ratio
    %   随评价进度增加，连续 PBI 得分的权重由 1-ratio 给出。
    %   参考解二值标签的权重由 ratio 给出。
    % 融合得分 H 同时使用连续排序信息与参考解分类标签。
    alpha = 1 - ratio;
    score_hybrid = alpha * score_v + (1-alpha) * double(label_dyn);

    %% ============ 步骤六：计算 confidence 输出 ============
    % confidence = 1 - |score_v - label_dyn|；主程序不使用该输出。
    % 注意 score_v 是连续量、label_dyn 是二值阈值标签，二者量纲不同，
    % 该差值不构成两个信号的一致性度量。
    confidence = 1 - abs(score_v - double(label_dyn));

    %% ============ 步骤七：确定正组及末端排名索引 ============
    % 按融合得分降序排列
    [~, idx_sorted] = sort(score_hybrid, 'descend');

    % 两端均取 ceil(N*rGood) 个索引；Catalog 仅将前端集合标记为正组。
    good_num = ceil(N * rGood);
    bad_num  = good_num;
    good_idx = idx_sorted(1:good_num);
    bad_idx  = idx_sorted(end-bad_num+1:end);

    %% ============ 输出 Catalog ============
    % Catalog: 融合排名前 ceil(N*rGood) 个为正组，其余为非正组。
    Catalog = false(N,1);
    Catalog(good_idx) = true;
    % 非正组由当前种群中所有未进入正组的解组成。
end

function score_v = ContinuousPBIQualityAssessment(PopObj,V,Zmin,theta)
%ContinuousPBIQualityAssessment Compute continuous directional PBI scores.
    N = size(PopObj,1);
    % 对每个解，使用原始目标向量与 V 的余弦相似度找到关联方向
    % 关联使用原始目标向量；PBI 投影和垂直距离使用相对理想点的目标向量。
    cosine = 1 - pdist2(PopObj, V, 'cosine');  % 余弦相似度
    [~, ref_idx] = max(cosine, [], 2);         % 最相似的参考方向索引

    d1 = zeros(N,1);  % 投影长度
    d2 = zeros(N,1);  % 垂直距离
    for i = 1:N
        vi = ref_idx(i);
        w = V(vi,:);  % 对应的参考方向

        % d1 = 解到理想点沿 w 方向的投影长度
        d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);
        % 投影点
        proj = Zmin + d1(i) * w;
        % d2 = 解到投影点的垂直距离
        d2(i) = norm(PopObj(i,:) - proj);
    end

    % PBI 距离 = d1 + theta * d2（theta 越大，对偏离方向的惩罚越重）
    PBI_v = d1 + theta * d2;
    % 连续质量得分 S=1/(1+PBI)，值越大表示关联方向上的 PBI 值越小。
    score_v = 1 ./ (1 + PBI_v);
end

%% ============ 内部函数：解析可选参数 ============
function val = get_option(args, name, default)
%get_option 读取名称-值参数，未提供时使用默认值。

    for i = 1:2:length(args)
        if strcmpi(args{i}, name)
            val = args{i+1};
            return;
        end
    end
    val = default;  % 未找到则返回默认值
end

%% ============ 内部函数：构造自适应参考方向 ============
function V = AdaptiveReferenceVectors(PopObj, Nref)
%AdaptiveReferenceVectors 根据当前非支配解构造单位参考方向。
%   将当前第一非支配前沿中每个解的原始目标向量归一化为单位向量。
%   非支配解数量不足、排序失败或某一目标的取值范围过小时，使用均匀参考方向。
%   Nref 用于数量不足的判断及 UniformPoint 的请求数量。
%   返回矩阵 V 每行对应一个参考方向；其实际行数由上述构造方式决定。

    M = size(PopObj, 2);

    % 提取非支配解（第一前沿）
    try
        FrontNo = NDSort(PopObj, 1);
        ParetoIdx = (FrontNo == 1);
        ParetoObj = PopObj(ParetoIdx, :);
        nPareto = size(ParetoObj, 1);
    catch
        % 若 NDSort 出错，直接使用均匀向量
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 若非支配解数量太少，则使用均匀参考方向
    if nPareto < max(10, Nref/2) || nPareto < 2
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 若任一目标在当前非支配集中的取值范围小于 1e-12，使用均匀参考方向。
    Zmin = min(ParetoObj, [], 1);
    Zmax = max(ParetoObj, [], 1);
    range = Zmax - Zmin;
    if any(range < 1e-12)
        V = UniformPoint(Nref, M, 'ILD');
        V = V ./ vecnorm(V, 2, 2);
        return;
    end

    % 将每个非支配解的原始目标向量归一化为单位参考方向。
    % 返回方向数等于当前非支配解数，无需补齐至 Nref。
    V = ParetoObj ./ vecnorm(ParetoObj, 2, 2);
end
