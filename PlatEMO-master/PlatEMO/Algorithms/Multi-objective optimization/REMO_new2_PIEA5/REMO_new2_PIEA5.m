classdef REMO_new2_PIEA5 < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_new2 + PIEA 性能指标体系 v5：保留候选池修复，回滚 PBI 标签
% k    ---    6 --- 参考解数量
% gmax --- 3000 --- 代理模型评估上限
% tau  ---   20 --- 指标轮盘历史窗口宽度
%
%------------------------------- v5 设计依据 -----------------------------
% v4 实验数据（M=10, D=30, DTLZ+WFG 全集 IGD）揭示两件事：
%   - 候选池修复（n_eval 从 4→8）有效，应该保留
%   - 关系网络改学 Fitness top25% 反而让 IGD 比 v3 还差
%     原因：Fitness 单一指标排序破坏多样性，DTLZ7 暴跌 62%
%     说明：多方向 PBI 标签 与 单值 Fitness 不能合并，必须保留分工
%
% v5 路线 A：分工明确
%   - 关系网络：学 PBI 多方向分类  → 提供"广度/方向"信号  ← 回滚到 v3
%   - SVR：学轮盘选中的 Fitness    → 提供"深度/数值"信号  ← 保留 v4 提前调用
%   - 候选池：累积所有 GA 候选     → 让两阶段筛选有意义    ← 保留 v4 修复
%   - 两阶段筛选：粗筛（关系/广度）→ 精排（SVR/深度）
%
%------------------------------- 主流程对比 ------------------------------
%   PIEA3:                         PIEA4:                          PIEA5:
%   HPC -> Catalog, Ref            HPC -> Ref                      HPC -> Catalog, Ref
%   GetRelationPairs(Catalog)      IndicatorSelector -> Fitness    IndicatorSelector -> Fitness
%   训练关系网络                   Catalog_fit ← top25% Fitness    GetRelationPairs(Catalog) ← v5 回滚
%   IndicatorSelector -> SVR       GetRelationPairs(Catalog_fit)   训练关系网络（PBI 多方向）
%   两阶段筛选（候选 12 个）       训练关系网络                    训练 SVR（Fitness）
%                                  训练 SVR                        两阶段筛选（累积池数百个） ← 保留 v4
%                                  两阶段筛选（累积池数百个）
%
%------------------------------- 参考文献 --------------------------------
% [1] H. Hao et al. REMO. IEEE TEVC, 2022.
% [2] Y. Li et al. PIEA. Information Sciences, 2024.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            warning off

            %% 启动横幅 + 初始化日志文件
            log_path = fullfile(fileparts(mfilename('fullpath')), 'REMO_new2_PIEA5_debug.log');
            fid = fopen(log_path, 'w');   % 'w' 模式覆盖旧日志
            if fid ~= -1
                fprintf(fid, '========== REMO_new2_PIEA5 启动 ==========\n');
                fprintf(fid, '时间=%s | 问题=%s | M=%d | D=%d | maxFE=%d\n', ...
                    datestr(now,'yyyy-mm-dd HH:MM:SS'), class(Problem), Problem.M, Problem.D, Problem.maxFE);
                fprintf(fid, '日志文件=%s\n', log_path);
                fprintf(fid, '==========================================\n');
                fclose(fid);
            end
            fprintf('\n========== REMO_new2_PIEA5 启动 ==========\n');
            fprintf('日志写入: %s\n', log_path);
            fprintf('==========================================\n');

            %% 参数设置
            [k, gmax, tau] = Algorithm.ParameterSet(6, 3000, 20);

            %% 拉丁超立方初始化
            if Problem.D <= 10
                N = 11 * Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper - Problem.lower, N, 1) .* PopDec ...
                + repmat(Problem.lower, N, 1));
            Archive = Population;

            %% 初始化指标轮盘（PIEA 风格）
            indicator(1) = struct('method', 'SDE',         'Choose_record', ones(1, tau), 'Win_record', ones(1, tau), 'Pw', 1/3);
            indicator(2) = struct('method', 'I_epsilon+',  'Choose_record', ones(1, tau), 'Win_record', ones(1, tau), 'Pw', 1/3);
            indicator(3) = struct('method', 'Minkowski',   'Choose_record', ones(1, tau), 'Win_record', ones(1, tau), 'Pw', 1/3);

            Lp = 1;   % PF 形状参数初始化为线性 (v4)

            %% 调试输出开关（设为 false 可关闭打印）
            DEBUG = true;
            gen   = 0;

            %% 主优化循环
            while Algorithm.NotTerminated(Archive)
                gen   = gen + 1;
                if DEBUG && gen == 1
                    fprintf('>>> 进入主循环（第 1 代开始，关系网络训练可能需要 30~60s）...\n');
                end
                ratio = Problem.FE / Problem.maxFE;

                %% Step 1 (v5 回滚): HPC 分类 -> Catalog (PBI 多方向) + Ref
                %  v4 把 Catalog 丢了导致多样性崩溃，v5 拿回来
                [~, ~, Catalog, ~, Ref] = HybridPBI_Classification( ...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);

                %% Step 2 (保留 v4 提前调用): 轮盘选指标 + 计算 Fitness
                %  Fitness 用于 SVR 训练（深度信号），不再混入 Catalog
                [Fitness, flag, Lp] = IndicatorSelector(Population, indicator, Lp);

                %% Step 3 (v5 回滚): 构造关系对——使用 PBI Catalog（广度信号）
                %  关系网络学多方向分类，与 SVR 学单一指标值互补
                Input = Population.decs;
                [XXs, YYs] = GetRelationPairs(Input, Catalog);

                if isempty(XXs)
                    if DEBUG
                        fprintf('[Gen %3d | FE=%4d/%4d] 跳过：关系对为空（Catalog 全为单一类别）\n', ...
                            gen, Problem.FE, Problem.maxFE);
                    end
                    Population = RefSelect(Archive, Problem.N);
                    continue;
                end

                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs);
                xDim = size(TrainIn, 2);

                %% Step 4: 训练关系网络（PBI 多方向标签 / 广度信号）
                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut, 1);
                net = patternnet([ceil(xDim * 1.5), xDim * 1, ceil(xDim / 2)]);
                net.trainParam.showWindow = 0;
                net = train(net, TrainIn_nor', TrainOut_onehot');
                TestIn_nor = mapminmax('apply', TestIn', TrainIn_struct)';
                TestPre = onehotconv(net(TestIn_nor')', 2);
                p_err = sum(TestPre ~= TestOut) / size(TestPre, 1);

                %% Step 5: 训练 SVR 指标代理（学 Fitness / 深度信号）
                IndicatorModel = [];
                try
                    IndicatorModel = fitrsvm(Population.decs, Fitness, ...
                        'KernelFunction', 'rbf', ...
                        'KernelScale', 'auto', ...
                        'Standardize', true);
                catch
                    IndicatorModel = [];
                end

                %% Step 6: 打包模型
                Smodel = struct();
                Smodel.X              = Input;
                Smodel.Y              = Catalog;
                Smodel.mp_struct      = TrainIn_struct;
                Smodel.net            = net;
                Smodel.p_err          = p_err;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.Lp             = Lp;
                Smodel.flag           = flag;

                %% Step 7: 两阶段筛选 + 真实评估（保留 v4 累积候选池）
                ArchiveSizeBefore = length(Archive);
                Next = RSurrogateAssistedSelection( ...
                    Problem, Ref, Population.decs, gmax, Smodel);

                if ~isempty(Next)
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive, NewSols];
                else
                    NewSols = [];
                end

                %% Step 8: NDSort_SDR 评分反馈（PIEA 核心机制）
                score = 0;
                if ~isempty(NewSols)
                    % 取本代真实评估的解中"最好"那个（Lp 距离最小）
                    [FrontNo_all, ~] = NDSort(Archive.objs, 1);
                    % 新解索引位于 Archive 末尾
                    new_idx = ArchiveSizeBefore + (1 : length(NewSols));
                    new_in_F1 = any(FrontNo_all(new_idx) == 1);

                    if new_in_F1
                        score = 1;
                        % 进一步用 NDSort_SDR 检验是否在强支配前沿
                        try
                            F1_subset = Archive(FrontNo_all == 1);
                            [FrontNo_SDR, ~] = NDSort_SDR(F1_subset, 1);
                            % 找到新解在 F1_subset 中的位置
                            new_in_F1_subset_idx = ismember(F1_subset.decs, NewSols.decs, 'rows');
                            if any(FrontNo_SDR(new_in_F1_subset_idx) == 1)
                                score = 2;
                            end
                        catch
                            % NDSort_SDR 失败保持 score=1
                        end
                    end
                end

                indicator = UpdateInformation(flag, score, indicator);

                %% 调试输出（每代打印 p_err / flag / score / Pw / Lp）
                if DEBUG
                    if isempty(NewSols)
                        n_eval = 0;
                    else
                        n_eval = length(NewSols);
                    end
                    try
                        DebugLog(gen, Problem.FE, Problem.maxFE, p_err, flag, score, indicator, Lp, n_eval);
                    catch ME
                        % DebugLog.m 找不到时回退到内联打印（path 缓存兜底）
                        fprintf(['[Gen %3d | FE=%4d/%4d] p_err=%.3f | flag=%d | score=%d | ', ...
                                 'Pw=[%.3f %.3f %.3f] | Lp=%.2f | n_eval=%d  (DebugLog 调用失败: %s)\n'], ...
                            gen, Problem.FE, Problem.maxFE, p_err, flag, score, ...
                            indicator(1).Pw, indicator(2).Pw, indicator(3).Pw, ...
                            Lp, n_eval, ME.message);
                    end
                end

                %% Step 9: 环境选择
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
