classdef REMO_new2_PIEA3 < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_new2 + PIEA 性能指标体系（轮盘 + Lp + NDSort_SDR 反馈）
% k    ---    6 --- 参考解数量
% gmax --- 3000 --- 代理模型评估上限
% tau  ---   20 --- 指标轮盘历史窗口宽度
%
%------------------------------- 设计要点 ---------------------------------
% 在 REMO_new2 基础上集成 PIEA 的完整性能指标体系：
%   1. 三指标轮盘：SDE / I_epsilon+ / Minkowski(Lp)
%      - 每代按 Pw 概率选一个用作 SVR 的回归目标
%   2. Lp 形状自适应（每代 Shape_Estimate）
%      - 影响 SDE 退化和 MD 距离
%   3. SVR 指标代理（PIEA 风格）
%      - fitrsvm + RBF + auto KernelScale
%      - 输入决策变量，输出 PIEA 指标值
%   4. 两阶段筛选：关系网络粗筛 + 指标 SVR 精排
%      - 关系网络做"哪些方向值得看"，指标 SVR 做"具体哪个最好"
%      - 不是简单加权（避开 PIEA2 路线）
%   5. NDSort_SDR + score=0/1/2 反馈轮盘
%      - 真实评估后用强支配关系评估上代选的指标好不好
%      - 更新 indicator 的 Win_record，下代轮盘自动倾向更优的指标
%   6. 末尾分位数阈值替代 `>3.9`
%      - 每代真实评估 5~8 个解
%
%------------------------------- 与已有版本对比 ---------------------------
%   REMO_new2       : 仅 PBI 分类 + patternnet
%   REMO_new2_PIEA  : 加了"决策空间最远点单选"，每代仅 1 解（保守）
%   REMO_new2_PIEA2 : 加了 SVR 回归 SDE，加权融合（SDE 单独不好，融合也受限）
%   REMO_new2_PIEA3 : 完整 PIEA 体系（三指标 + Lp + 反馈），两阶段筛选
%
%------------------------------- 参考文献 ---------------------------------
% [1] H. Hao et al. REMO. IEEE TEVC, 2022.
% [2] Y. Li, W. Li, S. Li, Y. Zhao. PIEA. Information Sciences, 2024.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            warning off

            %% 启动横幅 + 初始化日志文件
            log_path = fullfile(fileparts(mfilename('fullpath')), 'REMO_new2_PIEA3_debug.log');
            fid = fopen(log_path, 'w');   % 'w' 模式覆盖旧日志
            if fid ~= -1
                fprintf(fid, '========== REMO_new2_PIEA3 启动 ==========\n');
                fprintf(fid, '时间=%s | 问题=%s | M=%d | D=%d | maxFE=%d\n', ...
                    datestr(now,'yyyy-mm-dd HH:MM:SS'), class(Problem), Problem.M, Problem.D, Problem.maxFE);
                fprintf(fid, '日志文件=%s\n', log_path);
                fprintf(fid, '==========================================\n');
                fclose(fid);
            end
            fprintf('\n========== REMO_new2_PIEA3 启动 ==========\n');
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

            Lp = 1;   % PF 形状参数初始化为线性

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

                %% Step 1: HPC 分类（保留 REMO_new2 原逻辑）
                [~, ~, Catalog, ~, Ref] = HybridPBI_Classification( ...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);

                %% Step 2: 构造关系对（保留 REMO_new2 原 GetRelationPairs，含 0 标签）
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

                %% Step 3: 训练关系网络（保留 REMO_new2 原结构）
                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut, 1);
                net = patternnet([ceil(xDim * 1.5), xDim * 1, ceil(xDim / 2)]);
                net.trainParam.showWindow = 0;
                net = train(net, TrainIn_nor', TrainOut_onehot');
                TestIn_nor = mapminmax('apply', TestIn', TrainIn_struct)';
                TestPre = onehotconv(net(TestIn_nor')', 2);
                p_err = sum(TestPre ~= TestOut) / size(TestPre, 1);

                %% Step 4: 轮盘选择性能指标 + 训练 SVR 代理（PIEA 风格）
                [Fitness, flag, Lp] = IndicatorSelector(Population, indicator, Lp);

                IndicatorModel = [];
                try
                    IndicatorModel = fitrsvm(Population.decs, Fitness, ...
                        'KernelFunction', 'rbf', ...
                        'KernelScale', 'auto', ...
                        'Standardize', true);
                catch
                    % SVR 训练失败时记空（model_select 里会回退）
                    IndicatorModel = [];
                end

                %% Step 5: 打包模型
                Smodel = struct();
                Smodel.X              = Input;
                Smodel.Y              = Catalog;
                Smodel.mp_struct      = TrainIn_struct;
                Smodel.net            = net;
                Smodel.p_err          = p_err;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.Lp             = Lp;
                Smodel.flag           = flag;

                %% Step 6: 两阶段筛选 + 真实评估
                ArchiveSizeBefore = length(Archive);
                Next = RSurrogateAssistedSelection( ...
                    Problem, Ref, Population.decs, gmax, Smodel);

                if ~isempty(Next)
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive, NewSols];
                else
                    NewSols = [];
                end

                %% Step 7: NDSort_SDR 评分反馈（PIEA 核心机制）
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

                %% Step 8: 环境选择
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
