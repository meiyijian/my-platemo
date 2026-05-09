classdef MCEAD < ALGORITHM
% <2022> <multi/many> <real/integer> <expensive>
% Multiple classifiers-assisted evolutionary algorithm based on decomposition
% 算法全称：基于分解的多分类器辅助进化算法（MCEA/D）
%
% ==== 算法核心思想 ====
% 解决"昂贵多目标优化问题"（即目标函数计算非常耗时/昂贵的问题）。
% 核心思路：为每个子问题训练一个独立的 SVM 分类器，用 SVM 预测新解的优劣，
% 只将 SVM 判定为"好"的解送去真实评估，从而大幅减少昂贵的目标函数调用次数。
%
% ==== 算法参数说明 ====
% delta  --- 0.9 --- 从邻居中选择父代的概率（0.9表示90%概率从邻域选，10%从全局选）
% nr     ---   2 --- 每个子代最多替换的邻居解数量
% Rmax   ---  10 --- 每个子问题每代最多尝试生成子代的次数（超过则取最好候选）

%------------------------------- Reference --------------------------------
% T. Sonoda and M. Nakata. Multiple classifiers-assisted evolutionary
% algorithm based on decomposition for high-dimensional multi-objective
% problems. IEEE Transactions on Evolutionary Computation, 2022, 26(6):
% 1581-1595.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Masaya Nakata

    methods
        function main(Algorithm, Problem)
            %% ===== 步骤1：参数设置 =====
            % Algorithm.ParameterSet 从配置文件读取参数，若未配置则使用默认值
            [delta, nr, R_max] = Algorithm.ParameterSet(0.9, 2, 10);

            %% ===== 步骤2：生成权重向量（分解的核心） =====
            % UniformPoint 在 M 维目标空间的单位单纯形上均匀生成 N 个点
            % 每个点就是一个权重向量 w = (w1, w2, ..., wM)，满足 sum(w)=1 且每个 wj >= 0
            % 这 N 个权重向量将多目标问题分解为 N 个单目标子问题
            % 例如 M=2 时，权重向量均匀分布在从 (1,0) 到 (0,1) 的线段上
            [W, Problem.N] = UniformPoint(Problem.N, Problem.M);

            %% ===== 步骤3：建立邻域关系 =====
            % 为每个子问题找出 T 个最近的邻居（基于权重向量间的欧氏距离）
            % 邻域大小 T = ceil(N/10)，即约为种群大小的10%
            % 邻域思想：权重向量越接近的子问题，最优解也越相似
            T      = ceil(Problem.N / 10);          % 邻居数量
            B      = pdist2(W, W);                   % 计算所有权重向量两两之间的欧氏距离矩阵
            [~, B] = sort(B, 2);                     % 按距离从小到大排序每一行
            B      = B(:, 1 : T);                    % 取前T个最近的作为邻居索引

            %% ===== 步骤4：初始化种群 =====
            % 使用拉丁超立方采样在决策空间中生成均匀分布的初始种群
            % 拉丁超立方采样比纯随机采样能更好地覆盖整个搜索空间
            PopDec     = UniformPoint(Problem.N, Problem.D, 'Latin');
            % 将归一化的拉丁超立方样本缩放到实际决策空间：
            %   normalized_dec * (upper - lower) + lower
            % 然后调用真实目标函数进行评估（这是昂贵的！）
            Population = Problem.Evaluation(repmat(Problem.upper - Problem.lower, Problem.N, 1) .* PopDec + repmat(Problem.lower, Problem.N, 1));
            A          = Population;                 % A 是存档（Archive），保存所有已评估的解
            Z          = min(Population.objs, [], 1); % Z 是理想点：每个目标的当前最小值

            %% ===== 步骤5：初始化 SVM 分类器 =====
            % 为每个子问题（共 N 个）创建一个 SVM 对象
            % SVM.i 负责判断：对于子问题 i，一个候选解是否比当前最优解更好
            svm_list = SVM(Problem);

            %% ===== 步骤6：主优化循环 =====
            % Algorithm.NotTerminated(A) 检查是否达到最大评估次数
            while Algorithm.NotTerminated(A)
                % 逐个子问题处理（类似 MOEA/D 的逐个子问题更新策略）
                for i = 1 : Problem.N
                    %% ----- 6.1 构建SVM模型 -----
                    % 为子问题 i 的 SVM 准备训练数据并训练
                    % 训练数据来自存档 A 中的已评估解
                    % 标签规则：在邻居子问题中表现最好的解标为+1（正类/好解），其余标为-1（负类/差解）
                    svm_list(i) = svm_list(i).ModelConstruction(A, B(i, :), W, Z);

                    %% ----- 6.2 选择父代 -----
                    % 以概率 delta=0.9 从邻居中选择父代（局部搜索）
                    % 以概率 1-delta=0.1 从整个种群选择父代（全局探索）
                    % rand < delta  → 生成一个[0,1)随机数，小于delta则为真
                    if rand < delta
                        P = B(i, randperm(end));     % 从邻居索引中随机排列后作为父代候选
                    else
                        P = randperm(Problem.N);     % 从全局随机排列作为父代候选
                    end

                    %% ----- 6.3 解生成（SVM辅助的核心）-----
                    % 使用 DE 算子生成候选解，然后用子问题 i 的 SVM 进行筛选
                    % SVM 预测为正类（好解）才返回，否则重试最多 R_max 次
                    y_i = SolutionGeneration(Problem, Population, P, svm_list(i), R_max, i);

                    %% ----- 6.4 真实评估 -----
                    % 只有通过 SVM 筛选的候选解才会被真实目标函数评估
                    y_i = Problem.Evaluation(y_i);

                    %% ----- 6.5 更新理想点 -----
                    % Z = min(当前Z, 新解的各个目标值)
                    % 理想点始终追踪所有已评估解在每个目标上的最小值
                    Z = min(Z, y_i.obj);

                    %% ----- 6.6 更新种群和存档 -----
                    % 使用切比雪夫标量函数比较新旧解的优劣：
                    %   g(x|w,Z) = max_{1≤j≤M} { |f_j(x) - Z_j| * w_j }
                    % 该函数值越小越好（越接近理想点且方向越对齐权重向量）

                    % 计算父代候选集中所有解的切比雪夫值
                    g_old = max(abs(Population(P).objs - repmat(Z, length(P), 1)) .* W(P, :), [], 2);
                    % 计算新解的切比雪夫值（复制到每个父代候选位置以便比较）
                    g_new = max(repmat(abs(y_i.obj - Z), length(P), 1) .* W(P, :), [], 2);

                    % 如果新解的 g 值更小（更好），则替换对应的父代候选解
                    % nr=2 表示最多替换2个邻居解，防止一个超优解"淹没"整个邻域
                    Population(P(find(g_old >= g_new, nr))) = y_i;

                    % 存档总是追加新解（不会删除旧解，用于后续 SVM 训练）
                    A = [A, y_i];

                    %% ----- 6.7 检查终止条件 -----
                    Algorithm.NotTerminated(A);
                end
            end
        end
    end
end