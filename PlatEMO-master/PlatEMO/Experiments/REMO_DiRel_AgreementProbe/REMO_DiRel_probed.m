classdef REMO_DiRel_probed < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Difficulty-aware dual-scale relation learning for expensive MOO.
%
% PROBE: This is an instrumented copy of REMO_DiRel used by the
% AgreementProbe experiment. The original algorithm is unmodified.
% The probe records three-level network agreement at 5 progress checkpoints.
%
% Public parameters are kept compatible with the original implementation:
% k_easy   --- -1   --- size of the easy-objective subset (-1 = auto)
% tau_conf --- 0.3  --- uncertainty threshold for arbitration
% alpha    --- 0.6  --- difficulty weight for model difficulty
% k        --- 6    --- number of reference solutions
% gmax     --- 1000 --- surrogate-screened candidate budget per generation
% K_ens    --- 3    --- bagging ensemble size
% win_K    --- 3    --- difficulty smoothing window

    methods
        function main(Algorithm, Problem)
        % main - 算法主函数
        %
        % 输入：
        %   Algorithm - 算法对象（包含超参数、终止判断等）
        %   Problem   - 问题对象（包含目标函数、决策变量范围等）
        %
        % 这个函数是 PlatEMO 框架自动调用的，用户不需要手动调用

            % ============================================================
            % 第一步：读取超参数
            % ============================================================
            % Algorithm.ParameterSet 按顺序返回超参数值
            % 如果用户没有传入自定义值，就用默认值
            [k_easy_user, tau_conf, alpha, k, gmax, K_ens, win_K, probe_out_path] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 1000, 3, 3, '');

            % pairMax: 关系对构造的硬上限
            % 原始 REMO 枚举所有组合 O(n²)，这里限制最多 6000 个
            pairMax   = 6000;

            % anchorMax: 每类 anchor 点的最大数量
            % 在 ArbitratorScore 中用于控制评分计算量
            anchorMax = 30;

            % ============================================================
            % 第二步：确定易目标子集大小 k_easy
            % ============================================================
            if Problem.M <= 2
                % 双目标问题：子目标只有 1 个（选一半）
                k_easy = 1;
            elseif k_easy_user <= 0
                % 用户没指定（-1）：自动取 ceil(M/2)，但限制在 [2, M-1]
                k_easy = max(2, min(Problem.M-1, ceil(Problem.M/2)));
            else
                % 用户指定了具体值：限制在 [2, M-1]
                k_easy = max(2, min(Problem.M-1, k_easy_user));
            end

            % ============================================================
            % 第三步：初始化种群
            % ============================================================
            % 确定初始种群大小
            if Problem.D <= 10
                N = 11*Problem.D - 1;  % 低维问题：11D-1 个初始解
            else
                N = 100;               % 高维问题：固定 100 个
            end

            % UniformPoint(N, D, 'Latin') 生成拉丁超立方采样点
            % 拉丁超立方采样能保证样本均匀覆盖整个决策空间
            PopDec = UniformPoint(N, Problem.D, 'Latin');

            % 将 [0,1] 的采样点映射到实际决策变量范围
            % repmat 是 MATLAB 的复制矩阵函数
            % Problem.upper 和 Problem.lower 是决策变量的上下界
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower, N, 1) .* PopDec + ...
                repmat(Problem.lower, N, 1));

            % Archive 存储所有已评估的解（包括初始种群）
            Archive = Population;

            % ============================================================
            % 第四步：初始化历史记录结构体 H
            % ============================================================
            % H 用于存储难度排序需要的历史信息
            % nan(M, win_K) 创建 M×win_K 的 NaN 矩阵
            H.d_score = nan(Problem.M, win_K);   % 历史难度分数
            H.model   = nan(Problem.M, win_K);   % 历史建模难度
            H.improve = nan(Problem.M, win_K);   % 历史改进停滞
            H.conf    = nan(Problem.M, win_K);   % 历史冲突度
            H.best    = nan(Problem.M, 1);        % 各目标历史最优值
            gen       = 0;                         % 当前代数

            % ====== PROBE state ======
            probe_checkpoints = [0.04, 0.20, 0.40, 0.60, 0.80];
            probe_fired = false(1, numel(probe_checkpoints));
            probe_records = {};   % cell array of snapshot structs
            % =========================

            % ============================================================
            % 第五步：主循环
            % ============================================================
            % Algorithm.NotTerminated(Archive) 判断是否达到终止条件
            % 通常是评估次数达到 maxFE
            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                % --------------------------------------------------------
                % Step 1: 参考解选择
                % --------------------------------------------------------
                % RefSelect 使用雷达网格策略选择 k 个参考解
                % 参考解用于构造关系对时的 PBI 分类
                Ref = RefSelect(Population, k);

                % --------------------------------------------------------
                % Step 2: 目标难度在线排序（模块①）
                % --------------------------------------------------------
                % DifficultyProfiler 计算每个目标的难度分数
                % 输出：
                %   d_score - 各目标的难度分数（越小越易）
                %   H       - 更新后的历史记录
                %   S_easy  - 易目标子集的索引
                [d_score, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy);

                % --------------------------------------------------------
                % Step 3: 构造双尺度关系对
                % --------------------------------------------------------
                % 提取当前种群的决策变量和目标值
                Input  = Population.decs;   % N×D 矩阵，N个解的D维决策变量
                PopObj = Population.objs;   % N×M 矩阵，N个解的M个目标值
                RefObj = Ref.objs;          % k×M 矩阵，k个参考解的M个目标值

                % === 全目标支线 ===
                % GetOutput_PBI 使用 PBI 方法将解分类为 1（正类）或非1
                Catalog_F = GetOutput_PBI(PopObj, RefObj);

                % GetRelationPairsBudgeted 构造有上限的平衡关系对
                % 输出：
                %   XX_F - 关系对输入，每行是 [x_i, x_j] 的拼接
                %   YY_F - 关系对标签，+1/0/-1
                [XX_F, YY_F] = GetRelationPairsBudgeted(Input, Catalog_F, pairMax);

                % === 子目标支线 ===
                % S_easy 是易目标子集的索引，例如 [1, 3, 5]
                S_easy    = double(S_easy(:)');      % 转为行向量
                M_sub     = numel(S_easy);           % 子目标数量
                PopObjSub = PopObj(:, S_easy);       % 只保留易目标的列

                % 为子目标空间生成参考向量
                % 'ILD' 是 PlatEMO 内置的均匀分布参考向量生成方法
                Ref_S_obj = UniformPoint(size(RefObj,1), M_sub, 'ILD');

                % 将参考向量缩放到子目标空间的范围内
                % 这样参考向量才在子目标空间内有效
                P_min     = min(PopObjSub, [], 1);              % 各子目标最小值
                P_span    = max(max(PopObjSub, [], 1) - P_min, 1e-12);  % 各子目标跨度
                Ref_S_obj = Ref_S_obj .* P_span + P_min;       % 缩放

                % 用子目标构造关系对
                Catalog_S = GetOutput_PBI(PopObjSub, Ref_S_obj);
                [XX_S, YY_S] = GetRelationPairsBudgeted(Input, Catalog_S, pairMax);

                % --------------------------------------------------------
                % Step 4: 训练双尺度集成网络（模块②）
                % --------------------------------------------------------
                Next = [];
                if ~isempty(XX_F) && ~isempty(XX_S)
                    % TrainDualScaleNet 训练全目标和子目标两个集成网络
                    % DualNet 包含：
                    %   nets_F - 全目标集成网络（3个patternnet）
                    %   nets_S - 子目标集成网络（3个patternnet，迁移初始化）
                    DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens);

                    % 构建代理模型结构体 Smodel，传给仲裁选择模块
                    Smodel = struct();
                    Smodel.X              = Input;           % 训练数据输入
                    Smodel.Y_F            = Catalog_F;       % 全目标分类标签
                    Smodel.Y_S            = Catalog_S;       % 子目标分类标签
                    Smodel.DualNet        = DualNet;         % 双尺度网络
                    Smodel.S_easy         = S_easy;          % 易目标索引
                    Smodel.tau_conf       = tau_conf;        % 置信度阈值
                    Smodel.anchorMax      = anchorMax;       % anchor数量上限
                    Smodel.easyDifficulty = mean(d_score(S_easy));  % 易目标平均难度

                    % ====== PROBE: snapshot at progress checkpoints ======
                    if ~isempty(probe_out_path)
                        progress = Problem.FE / Problem.maxFE;
                        hit = find(progress >= probe_checkpoints & ~probe_fired);
                        if ~isempty(hit)
                            probe_fired(hit) = true;
                            try
                                rec = compute_agreement(Population, Catalog_F, Catalog_S, ...
                                                        DualNet, S_easy, anchorMax, gen, Problem.FE);
                                rec.checkpoint_idx = hit(end);
                                rec.checkpoint_val = probe_checkpoints(hit(end));
                                probe_records{end+1} = rec;
                            catch ME
                                warning('Probe failed at gen %d: %s', gen, ME.message);
                            end
                        end
                    end
                    % =====================================================

                    % --------------------------------------------------------
                    % Step 5: 仲裁选择（模块③）
                    % --------------------------------------------------------
                    % ArbitratedSelection 用 GA 生成候选解，再用仲裁器评分筛选
                    Next = ArbitratedSelection(Problem, Ref, Input, gmax, Smodel);
                end

                % 如果仲裁选择失败（返回空），用 GA 做 fallback
                if isempty(Next)
                    Next = fallbackOffspring(Problem, Ref, Input);
                end

                % --------------------------------------------------------
                % Step 6-8: 评估与更新
                % --------------------------------------------------------
                remain = Problem.maxFE - Problem.FE;  % 剩余评估次数
                if remain > 0
                    % sanitizeCandidates: 去重、边界裁剪、去已评估解
                    Next = sanitizeCandidates(Next, Problem, Archive, remain);
                    % Problem.Evaluation: 真实昂贵评估（核心瓶颈！）
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % RefSelect 重新选择下一代种群
                Population = RefSelect(Archive, Problem.N);
            end

            % ====== PROBE: persist all snapshots ======
            if ~isempty(probe_out_path) && ~isempty(probe_records)
                probe_data = probe_records;   %#ok<NASGU>
                problem_name = class(Problem);
                M_val = Problem.M;
                D_val = Problem.D;
                maxFE_val = Problem.maxFE;
                save(probe_out_path, 'probe_data', 'problem_name', ...
                     'M_val', 'D_val', 'maxFE_val', '-v7');
            end
            % ==========================================
        end
    end
end


%% ========================================================================
%  以下是局部辅助函数（只在本文件内可见）
%  MATLAB 中，classdef 文件的函数定义必须放在 classdef 块内
%  但可以用独立函数文件（如 fallbackOffspring.m）来替代
%  ========================================================================

function Next = fallbackOffspring(Problem, Ref, Input)
% fallbackOffspring - 当代理模型失败时的后备策略
%
% 使用遗传算子 (OperatorGA) 生成后代
% OperatorGA 是 PlatEMO 内置的遗传算子
% 输入：[当前种群决策变量; 参考解决策变量]
% 参数：{交叉概率, 交叉分布指数, 变异概率, 变异分布指数}

    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 20, 1, 20});
end


function Next = sanitizeCandidates(Next, Problem, Archive, remain)
% sanitizeCandidates - 清洗候选解
%
% 功能：
%   1. 边界裁剪：确保决策变量在 [lower, upper] 范围内
%   2. 去重：去除重复解
%   3. 去已评估：去除已经在 Archive 中的解
%   4. 数量限制：最多保留 remain 个解
%
% 输入：
%   Next    - 候选解决策变量矩阵
%   Problem - 问题对象
%   Archive - 已评估的解集
%   remain  - 剩余评估次数

    if isempty(Next)
        % 如果候选解为空，随机生成 4 个解作为兜底
        Next = randomFill(Problem, min(4, remain));
        return;
    end

    % 边界裁剪：min(max(Next, Lower), Upper) 将值限制在范围内
    Lower = repmat(Problem.lower, size(Next,1), 1);
    Upper = repmat(Problem.upper, size(Next,1), 1);
    Next  = min(max(Next, Lower), Upper);

    % 去重：unique(..., 'rows', 'stable') 按行去重，保持原顺序
    Next = unique(Next, 'rows', 'stable');

    % 去除已评估的解
    if ~isempty(Archive)
        % ismember(..., 'rows') 检查每行是否在 Archive 中
        old  = ismember(Next, Archive.decs, 'rows');
        Next = Next(~old, :);  % 保留不在 Archive 中的解
    end

    % 数量限制
    if isempty(Next)
        Next = randomFill(Problem, min(4, remain));
    elseif size(Next,1) > remain
        Next = Next(1:remain, :);  % 只取前 remain 个
    end
end


function X = randomFill(Problem, n)
% randomFill - 生成随机解（兜底策略）
%
% 当候选解为空时，随机生成拉丁超立方采样点
% 输入：
%   Problem - 问题对象
%   n       - 要生成的解数量

    if n <= 0
        X = zeros(0, Problem.D);
        return;
    end
    U = UniformPoint(n, Problem.D, 'Latin');
    X = repmat(Problem.upper-Problem.lower, n, 1) .* U + repmat(Problem.lower, n, 1);
end
