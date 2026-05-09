classdef REMO_DORL < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_DORL: Decision-Objective joint Relation Learning
% k        ---     6  --- 参考解数量
% gmax     ---  3000  --- 代理评估上限
% tau_err  ---  0.30  --- 课程切换阈值（p_err < tau_err 时切到阶段 2）
% use_LOS  ---     1  --- 是否启用轻量目标回归器（消融用，0=关）
% use_ORC  ---     1  --- 是否启用一致性置信度（消融用，0=关）
%
%------------------------------- 设计要点 ---------------------------------
%   在 REMO_new2_PIEA（HybridPBI 分类 + 关系学习）的基础上，针对 REMO 系列
%   长期被忽视的盲点引入决策-目标联合关系学习：
%
%   ① DO-Joint Input（决策-目标联合输入，主线）
%      - 关系网络输入从 [x_i, x_j] 升级为 [x_i, x_j, f̃_i, f̃_j]
%      - f 是已花昂贵代价评估出来的"免费午餐"，原 REMO 系列在输入端丢弃
%      - 模型负担骤降：M 越大收益越大（论文卖点）
%
%   ② Lightweight Objective Surrogate（LOS，工程支撑）
%      - 用 RBF 同时回归 M 维目标值，archive 训练，零额外评估代价
%      - 推理时把 f̂(x_new) 作为软先验喂入关系网络
%      - 解决推理时 f(x_new) 未知的"先有鸡还是先有蛋"问题
%
%   ③ Objective-distance Curriculum（ODC，增强）
%      - 阶段 1（"易"）：仅保留目标空间距离 > median 的对（关系标签清晰）
%      - 阶段 2（"难"）：放开所有对
%      - 切换由上一代 p_err 自适应判断（继承 REMO_C2RL）
%
%   ④ Objective-Relation Consistency（ORC，鲁棒性）
%      - softmax max prob × (0.5 + 0.5×agree_score)
%      - 关系网络与 LOS 互相校验：两者矛盾时降权该对
%      - 避免单边噪声主导决策
%
%------------------------------- 与已有版本对比 ---------------------------
%   REMO_new2          : 基础关系学习 + HybridPBI
%   REMO_new2_PIEA     : 加自适应参考向量
%   REMO_C2RL          : 加课程化 + softmax 置信度 + UCB
%   REMO_DORL（本算法）: 决策-目标联合输入（范式级）+ LOS + ODC + ORC
%
%------------------------------- 参考文献 ---------------------------------
% [1] H. Hao et al. REMO. IEEE TEVC, 2022, 26(5): 1157-1170.
% [2] Bengio et al. Curriculum Learning. ICML 2009.
% [3] Y. Li et al. PIEA. Information Sciences, 2024.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm, Problem)
            warning off
            %% 参数设置
            [k, gmax, tau_err, use_LOS, use_ORC] = ...
                Algorithm.ParameterSet(6, 3000, 0.30, 1, 1);

            %% 拉丁超立方初始化（与 REMO_new2 一致）
            if Problem.D <= 10
                N = 11 * Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper - Problem.lower, N, 1) .* PopDec ...
                + repmat(Problem.lower, N, 1));
            Archive    = Population;

            %% 课程阶段状态
            stage      = 1;     % 1 = 易（极端对）, 2 = 难（全部对）
            p_err_prev = 1.0;   % 第一代默认 p_err 高 → 强制阶段 1

            %% 主优化循环
            while Algorithm.NotTerminated(Archive)
                ratio = Problem.FE / Problem.maxFE;

                %% Step 1: HPC 混合分类（保留 REMO_new2_PIEA 核心）
                [~, ~, Catalog, ~, Ref] = HybridPBI_Classification( ...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);

                %% Step 2: 课程阶段切换（基于上一代 p_err 自适应）
                if p_err_prev <= tau_err
                    stage = 2;
                else
                    stage = 1;
                end

                %% Step 3: 训练轻量目标回归器（创新 2）
                %  archive 太小（< 2N）时 RBF 不可靠，跳过
                if use_LOS && length(Archive) >= 2 * N
                    LOS = ObjectiveSurrogate('train', Archive.decs, Archive.objs);
                else
                    LOS = [];
                end

                %% Step 4: 决策-目标联合关系对构造（创新 1 + 创新 3）
                Input = Population.decs;
                Objs  = Population.objs;
                [XXs, YYs] = GetRelationPairs_DO(Input, Objs, Catalog, stage);

                if isempty(XXs)
                    % 兜底：关系对为空时跳过本代
                    Population = RefSelect(Archive, Problem.N);
                    continue;
                end

                %% Step 5: 训练关系网络（patternnet，输入维度 = 2D + 2M）
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs);
                xDim = size(TrainIn, 2);     % 2D + 2M

                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor      = TrainIn_nor';
                TrainOut_onehot  = onehotconv(TrainOut, 1);

                net = patternnet([ceil(xDim*1.5), xDim*1, ceil(xDim/2)]);
                net.trainParam.showWindow = 0;
                net = train(net, TrainIn_nor', TrainOut_onehot');

                TestIn_nor  = mapminmax('apply', TestIn', TrainIn_struct)';
                TestPre     = onehotconv(net(TestIn_nor')', 2);
                p_err       = sum(TestPre ~= TestOut) / size(TestPre, 1);
                p_err_prev  = p_err;

                %% Step 6: 打包代理模型
                Smodel = struct();
                Smodel.X         = Input;
                Smodel.F         = Objs;
                Smodel.Y         = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net       = net;
                Smodel.p_err     = p_err;
                Smodel.stage     = stage;
                Smodel.LOS       = LOS;
                Smodel.use_LOS   = use_LOS;
                Smodel.use_ORC   = use_ORC;

                %% Step 7: 决策-目标联合 + ORC 一致性 + 分位数阈值选择
                Next = RSurrogateAssistedSelection_DO( ...
                    Problem, Ref, Population.decs, gmax, Smodel);

                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                %% Step 8: 环境选择
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
