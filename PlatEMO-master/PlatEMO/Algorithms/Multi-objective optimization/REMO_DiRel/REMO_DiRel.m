classdef REMO_DiRel < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_DiRel: 难度感知的双尺度关系学习算法
% Difficulty-Aware Dual-Scale Relation Learning for Expensive Many-objective Optimization
%
% 核心创新：
%   1. 难度量化器 (DifficultyProfiler)：用 GP 留一 NRMSE + Spearman 冲突度
%      联合度量每个目标的"难度"，动态选出最易子集。
%   2. 双尺度关系网络 (TrainDualScaleNet)：训一个全目标关系网络 net_F，
%      然后用迁移微调得到子目标关系网络 net_S（共享 backbone, 冻结 trunk）。
%   3. 仲裁器 (ArbitratedSelection)：用 bagging 集成方差做"逐候选解的逆方差权重"，
%      融合 net_F 与 net_S 的预测。冲突分支单独处理。
%
% 与现有 REMO 家族变体的差异：
%   vs REMO            : 单一全目标模型 → 双尺度（全 + 易子集）
%   vs Subproblem_REMO : 静态相邻分组 → 动态难度排序 + 共享 backbone + 迁移
%   vs SRMaO           : 集成方差做全局权重 → 做逐候选解条件权重
%   vs AdaMaO          : 10+ 超参 + 4 魔数阈值 → 3 个超参 + 数据驱动
%
%--------------------- 超参数（只暴露 3 个）---------------------
% k_easy   --- -1   --- 易目标子集大小（-1 表示自动 ceil(M/2)）
% tau_conf --- 0.3  --- 仲裁器判定"高/低置信"的归一化方差阈值
% alpha    --- 0.6  --- 难度公式中 NRMSE 项的权重，(1-alpha) 给冲突度项
%---------------------- 沿用 REMO 的固定参数 ---------------------
% k        --- 6    --- 参考解数量
% gmax     --- 3000 --- 代理模型评估上限
% K_ens    --- 5    --- bagging 集成大小（不确定性估计用）
% win_K    --- 3    --- 难度滑动平均窗口（代）
%
%------------------------------- Reference --------------------------------
% [Working paper] DiRel: Difficulty-Aware Dual-Scale Relation Learning
% for Expensive Many-objective Optimization, 2026.
%------------------------------- Dependency -------------------------------
% 跨目录复用以下文件（PlatEMO path 自动可达）：
%   REMO/RefSelect.m, REMO/GetOutput_PBI.m, REMO/GetRelationPairs.m,
%   REMO/DataProcess.m, REMO/onehotconv.m,
%   REMO_SRMaO/SRMaO_DropoutEnsemble.m (bagging variance),
%   SIBEA-kEMOSS/kEMOSS.m (用于参考实现的目标约简，非强依赖),
%   K-RVEA/dacefit.m + predictor.m (GP NRMSE 用)
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% ---- 参数 ----
            [k_easy_user,tau_conf,alpha,k,gmax,K_ens,win_K] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 3000, 5, 3);

            % 自动决定 k_easy
            if k_easy_user <= 0
                k_easy = max(2, min(Problem.M-1, ceil(Problem.M/2)));
            else
                k_easy = max(2, min(Problem.M-1, k_easy_user));
            end

            %% ---- 初始化 ----
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

            % H = 难度历史 (M × win_K 矩阵)，存近 win_K 代的归一化难度
            % H_nrmse / H_conf 分别存原始两个指标的近 win_K 代值，便于复盘
            H.d_score = nan(Problem.M, win_K);
            H.nrmse   = nan(Problem.M, win_K);
            H.conf    = nan(Problem.M, win_K);
            gen       = 0;

            %% ---- 主循环 ----
            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                % Step 1: 选参考解（沿用 REMO）
                Ref = RefSelect(Population, k);

                % Step 2: 难度分析（模块 ①）
                [d_score, H, S_easy] = DifficultyProfiler( ...
                    Population, H, gen, alpha, k_easy);

                % Step 3: 构造关系对（全目标 + 子目标）
                Input  = Population.decs;
                PopObj = Population.objs;
                RefObj = Ref.objs;

                % 全目标 PBI 分类（沿用 REMO）
                Catalog_F = GetOutput_PBI(PopObj, RefObj);
                [XX_F, YY_F] = GetRelationPairs(Input, Catalog_F);

                % 子目标 PBI 分类：在 |S_easy| 维子空间重新生成参考点
                % 注意：不能投影全维 Ref，必须在子维上重新均匀采样参考向量
                S_easy    = double(S_easy(:)');           % 强制 double 行向量
                M_sub     = numel(S_easy);
                Ref_S_obj = UniformPoint(size(RefObj,1), M_sub, 'ILD');
                % 把参考向量缩放到种群子目标范围内（避免 PBI 失效）
                PopObj_sub  = PopObj(:, S_easy);
                P_sub_min   = min(PopObj_sub, [], 1);
                P_sub_max   = max(PopObj_sub, [], 1);
                P_sub_span  = max(P_sub_max - P_sub_min, 1e-12);
                Ref_S_obj   = Ref_S_obj .* P_sub_span + P_sub_min;
                Catalog_S   = GetOutput_PBI(PopObj_sub, Ref_S_obj);
                [XX_S, YY_S] = GetRelationPairs(Input, Catalog_S);

                % 空集防御
                if isempty(XX_F) || isempty(XX_S)
                    Population = RefSelect(Archive, Problem.N);
                    continue;
                end

                % Step 4: 训练双尺度关系网络（模块 ②）
                [DualNet] = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens);

                % Step 5: 仲裁器辅助筛选（模块 ③）
                Smodel = struct();
                Smodel.X        = Input;
                Smodel.Y_F      = Catalog_F;
                Smodel.Y_S      = Catalog_S;
                Smodel.DualNet  = DualNet;
                Smodel.S_easy   = S_easy;
                Smodel.tau_conf = tau_conf;

                Next = ArbitratedSelection(Problem, Ref, Input, gmax, Smodel);

                % Step 6: 真实评估
                remain = Problem.maxFE - Problem.FE;
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1), remain), :);
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % Step 7: 下一代种群
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
