classdef PIEA_R < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% PIEA with Relation learning from indicator continuous values
% k    ---    6 --- Number of reference solutions
% gmax --- 3000 --- Maximum surrogate evaluations per generation
% tau  ---   20 --- Window width for indicator roulette history
% q    ---  0.3 --- Quantile threshold for relation pair labeling

%------------------------------- 核心创新 ---------------------------------
% 用 PIEA 的性能指标连续值直接构建关系对标签，替代 REMO 中基于 PBI 的
% 二元分类。与 PIEA4（硬性 top-25% 切割导致 DTLZ7 暴跌）的关键区别：
%   - 成对连续差值（而非全局二元切割）
%   - 自适应阈值 threshold = quantile(|diff|, q)
%   - 三类标签 {-1, 0, +1} 保留连续信息
%
% 设计分工：
%   - 关系网络：学指标 Fitness 的成对比较 → 提供"方向"信号
%   - SVR：学指标 Fitness 的连续值 → 提供"深度"信号
%   - 两阶段筛选：粗筛（关系）→ 精排（SVR）
%
%------------------------------- 参考文献 --------------------------------
% [1] H. Hao et al. REMO. IEEE TEVC, 2022.
% [2] Y. Li et al. PIEA. Information Sciences, 2024.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            warning off

            %% 参数设置
            [k, gmax, tau, q] = Algorithm.ParameterSet(6, 3000, 20, 0.3);

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
            indicator(1) = struct('method', 'SDE',        'Choose_record', ones(1, tau), 'Win_record', ones(1, tau), 'Pw', 1/3);
            indicator(2) = struct('method', 'I_epsilon+', 'Choose_record', ones(1, tau), 'Win_record', ones(1, tau), 'Pw', 1/3);
            indicator(3) = struct('method', 'Minkowski',  'Choose_record', ones(1, tau), 'Win_record', ones(1, tau), 'Pw', 1/3);

            Lp = 1;

            %% 调试输出开关
            DEBUG = true;
            gen   = 0;

            %% 主优化循环
            while Algorithm.NotTerminated(Archive)
                gen   = gen + 1;

                %% Step 1: 指标轮盘选择 + 计算 Fitness
                [Fitness, flag, Lp] = IndicatorSelector(Population, indicator, Lp);

                %% Step 2: 选择参考解
                Ref = RefSelect(Population, k);

                %% Step 3: 用 Fitness 连续值构建关系对（核心创新）
                %  替代 PBI 分类 + GetRelationPairs 的流程
                Input = Population.decs;
                [XXs, YYs] = BuildIndicatorRelationPairs(Input, Fitness, q);

                if isempty(XXs)
                    if DEBUG
                        fprintf('[Gen %3d | FE=%4d/%4d] 跳过：关系对为空\n', ...
                            gen, Problem.FE, Problem.maxFE);
                    end
                    Population = RefSelect(Archive, Problem.N);
                    continue;
                end

                %% Step 4: 训练关系网络（patternnet，同 REMO 流水线）
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs);
                xDim = size(TrainIn, 2);

                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut, 1);

                net = patternnet([ceil(xDim * 1.5), xDim * 1, ceil(xDim / 2)]);
                net.trainParam.showWindow = 0;
                net = train(net, TrainIn_nor', TrainOut_onehot');

                TestIn_nor = mapminmax('apply', TestIn', TrainIn_struct)';
                TestPre = onehotconv(net(TestIn_nor')', 2);
                p_err = sum(TestPre ~= TestOut) / size(TestPre, 1);

                %% Step 5: 训练 SVR 指标代理（PIEA 风格，学 Fitness 连续值）
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
                %  Smodel.Y 用于 model_select_relation 的 C1/C2 分组
                %  这里用 Fitness 中位数做二元分割（仅用于评分，不影响关系网络训练）
                Smodel = struct();
                Smodel.X              = Input;
                Smodel.Y              = (Fitness > median(Fitness));
                Smodel.mp_struct      = TrainIn_struct;
                Smodel.net            = net;
                Smodel.p_err          = p_err;
                Smodel.IndicatorModel = IndicatorModel;
                Smodel.Lp             = Lp;
                Smodel.flag           = flag;

                %% Step 7: 两阶段筛选 + 真实评估
                ArchiveSizeBefore = length(Archive);
                Next = RSurrogateAssistedSelection( ...
                    Problem, Ref, Population.decs, gmax, Smodel);

                if ~isempty(Next)
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive, NewSols];
                else
                    NewSols = [];
                end

                %% Step 8: NDSort_SDR 反馈更新轮盘（PIEA 核心机制）
                score = 0;
                if ~isempty(NewSols)
                    [FrontNo_all, ~] = NDSort(Archive.objs, 1);
                    new_idx = ArchiveSizeBefore + (1 : length(NewSols));
                    new_in_F1 = any(FrontNo_all(new_idx) == 1);

                    if new_in_F1
                        score = 1;
                        try
                            F1_subset = Archive(FrontNo_all == 1);
                            [FrontNo_SDR, ~] = NDSort_SDR(F1_subset, 1);
                            new_in_F1_idx = ismember(F1_subset.decs, NewSols.decs, 'rows');
                            if any(FrontNo_SDR(new_in_F1_idx) == 1)
                                score = 2;
                            end
                        catch
                        end
                    end
                end

                indicator = UpdateInformation(flag, score, indicator);

                %% 调试输出
                if DEBUG
                    if isempty(NewSols)
                        n_eval = 0;
                    else
                        n_eval = length(NewSols);
                    end
                    try
                        DebugLog(gen, Problem.FE, Problem.maxFE, p_err, flag, score, indicator, Lp, n_eval);
                    catch
                        fprintf(['[Gen %3d | FE=%4d/%4d] p_err=%.3f | flag=%d | score=%d | ', ...
                                 'Pw=[%.3f %.3f %.3f] | Lp=%.2f | n_eval=%d\n'], ...
                            gen, Problem.FE, Problem.maxFE, p_err, flag, score, ...
                            indicator(1).Pw, indicator(2).Pw, indicator(3).Pw, ...
                            Lp, n_eval);
                    end
                end

                %% Step 9: 环境选择
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
