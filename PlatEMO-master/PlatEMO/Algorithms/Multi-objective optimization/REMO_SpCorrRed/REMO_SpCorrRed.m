classdef REMO_SpCorrRed < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO with Spearman Correlation Objective Reduction — 方案二
% 基于 Spearman 秩相关系数将 M 个目标层次聚类为 k_red 个新目标
% 在降维后的目标空间训练关系模型，其余框架与原始 REMO 完全一致
%
% 聚类原理：
%   1. 计算 M×M Spearman 秩相关矩阵 ρ
%   2. 定义距离 D(i,j) = 1 - |ρ(i,j)|
%   3. 用层次聚类（average linkage）将 M 个目标聚为 k_red 组
%   4. 组内 min-max 归一化 + 等权重平均 → 聚合目标
%
% k_red --- 3   --- 降维后的目标组数
% k     --- 6   --- 参考解数量
% gmax  --- 3000 --- 代理模型评估的解数量上限
%
%------------------------------- Reference --------------------------------
% H. Hao, A. Zhou, H. Qian, and H. Zhang. Expensive multiobjective
% optimization by relation learning and prediction. IEEE Transactions on
% Evolutionary Computation, 2022, 26(5): 1157-1170.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            %% Parameter setting（参数设置）
            [k_red, k, gmax] = Algorithm.ParameterSet(3, 6, 3000);

            %% Add REMO path for shared utility functions
            here = fileparts(mfilename('fullpath'));
            addpath(fullfile(here, '..', 'REMO'));

            %% Check parameter validity（参数校验）
            if Problem.M <= k_red
                error('REMO_SpCorrRed:InvalidParam', ...
                    'k_red (%d) must be strictly less than number of objectives M (%d).\nThis algorithm is designed for many-objective problems.', ...
                    k_red, Problem.M);
            end

            %% Initialize population by Latin hypercube sampling（拉丁超立方采样初始化）
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower, N, 1).*PopDec + repmat(Problem.lower, N, 1));
            Archive    = Population;

            %% ★ 方案二核心：基于 Spearman 相关系数的目标聚类（仅初始化时构建一次，全程固定）
            Groups = spearCluster(Population.objs, k_red);

            %% Optimization（主优化循环）
            while Algorithm.NotTerminated(Archive)
                % Step 1: 选择参考解（在原 M 维目标空间，与 REMO 一致）
                Ref = RefSelect(Population, k);

                % Step 2: ★ 对种群和参考解应用降维，在 k_red 维空间做 PBI 分类
                Input       = Population.decs;
                PopObj_red  = applyReduction(Population.objs, Groups);
                RefObj_red  = applyReduction(Ref.objs, Groups);
                Catalog     = GetOutput_PBI(PopObj_red, RefObj_red);

                % Step 3: 构建关系对（与 REMO 一致）
                [XXs, YYs] = GetRelationPairs(Input, Catalog);

                % Step 4: 划分训练集和测试集（与 REMO 一致）
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs);
                xDim = size(TrainIn, 2);

                % Step 5: 训练关系预测模型（与 REMO 一致）
                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor     = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut, 1);
                net = patternnet([ceil(xDim*1.5), xDim*1, ceil(xDim/2)]);
                net.trainParam.showWindow = 0;
                net        = train(net, TrainIn_nor', TrainOut_onehot');
                TestIn_nor = mapminmax('apply', TestIn', TrainIn_struct)';
                TestPre    = onehotconv(net(TestIn_nor')', 2);
                p_err      = sum(TestPre ~= TestOut) / size(TestPre, 1);

                % Step 6: 打包代理模型（与 REMO 一致）
                Smodel.X         = Input;
                Smodel.Y         = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net       = net;
                Smodel.p_err     = p_err;

                % Step 7: 代理模型辅助选择 + 真实评估（与 REMO 一致）
                Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel);
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % Step 8: 从 Archive 中重新选择下一代种群（在原 M 维目标空间，与 REMO 一致）
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end


%% =========================================================================
%  局部辅助函数
%  =========================================================================

function Groups = spearCluster(PopObj, k_red)
% 基于 Spearman 秩相关系数对目标进行层次聚类
%
% 原理：
%   - ρ(i,j) 越接近 ±1 → 目标 i,j 单调相关性强 → 应聚在一起
%   - ρ(i,j) 越接近 0  → 目标 i,j 无单调关系  → 应分开
%   - 用 D(i,j) = 1 - |ρ(i,j)| 作为距离度量
%   - 用层次聚类（average linkage）聚类为 k_red 组
%
% 输入：
%   PopObj - N×M 目标值矩阵
%   k_red  - 目标组数
% 输出：
%   Groups - 1×k_red cell，每个 cell 包含该组的目标索引

    M = size(PopObj, 2);

    % ---- Step 1: 计算 Spearman 秩相关矩阵 ----
    rho = corr(PopObj, 'type', 'Spearman');   % M×M, ρ ∈ [-1, 1]

    % 处理异常值：NaN → 0（例如某目标为常数时可能产生 NaN）
    rho(isnan(rho)) = 0;

    % ---- Step 2: 构造距离矩阵 D = 1 - |ρ| ----
    % |ρ| → 1 表示高度相关（正或负），距离小 → 倾向聚在同一组
    % |ρ| → 0 表示不相关，距离大 → 倾向分到不同组
    D = 1 - abs(rho);

    % 对角线置 0（自己到自己的距离为 0）
    D(1:M+1:end) = 0;

    % ---- Step 3: 层次聚类（average linkage）----
    % squareform: M×M 矩阵 → pdist 向量格式（linkage 所需输入）
    % 'average': 组平均连接，平衡单连接和全连接的极端性
    Z = linkage(squareform(D), 'average');

    % 切分为 k_red 组
    labels = cluster(Z, 'maxclust', k_red);

    % ---- Step 4: 构建 Groups 结构 ----
    Groups = cell(1, k_red);
    for g = 1:k_red
        Groups{g} = sort(find(labels == g)');
    end

    % 按每组最小索引排序 Groups
    first_idx = zeros(1, k_red);
    for g = 1:k_red
        first_idx(g) = min(Groups{g});
    end
    [~, ord] = sort(first_idx);
    Groups = Groups(ord);
end


function ReducedObj = applyReduction(PopObj, Groups)
% 对目标值矩阵应用聚类降维
% Step 1: 每列 min-max 归一化到 [0, 1]
% Step 2: 组内等权重平均 → 一个聚合目标
%
% 输入：
%   PopObj  - N×M 目标值矩阵
%   Groups  - 1×k_red cell，每个 cell 包含该组的目标索引
% 输出：
%   ReducedObj - N×k_red 降维后的目标值矩阵

    [N, M] = size(PopObj);
    K = numel(Groups);

    % ---- Step 1: 逐列 min-max 归一化 ----
    F = double(PopObj);
    for d = 1:M
        col = F(:, d);
        % 处理非有限值
        finite_mask = isfinite(col);
        if any(finite_mask)
            fill_val = median(col(finite_mask));
            col(~finite_mask) = fill_val;
        end
        lo = min(col);
        hi = max(col);
        span = hi - lo;
        if span > 1e-12
            F(:, d) = (col - lo) ./ span;
        else
            F(:, d) = 0;  % 常数列 → 归一化为 0
        end
    end

    % ---- Step 2: 组内等权重平均 ----
    ReducedObj = zeros(N, K);
    for g = 1:K
        C = Groups{g}(:)';                     % 该组包含的目标索引
        w = ones(1, numel(C)) ./ numel(C);      % 等权重
        ReducedObj(:, g) = F(:, C) * w(:);       % 加权求和
    end
end
