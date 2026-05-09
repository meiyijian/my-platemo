classdef REMO_new2_confidence < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Expensive multiobjective optimization by relation learning and prediction
% (HPC + Confidence-aware sample weighting)
% 在 REMO_new2 基础上利用 HybridPBI_Classification 输出的置信度对关系对进行加权训练，
% 让神经网络在学习样本对关系时更关注高置信度样本，弱化噪声标签的影响。
%
% 参数:
%   k       - 动态参考解数量 (默认 6)
%   gmax    - 代理模型辅助 GA 内层迭代累计样本上限 (默认 3000)
%   w_min   - 关系对样本权重下限，避免某些样本因置信度过低被网络完全忽略 (默认 0.3)

    methods
        function main(Algorithm,Problem)
            %% 参数设置
            [k,gmax,w_min] = Algorithm.ParameterSet(6,3000,0.3);

            %% 初始化种群
            if Problem.D <= 10
                N = 11*Problem.D-1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec+repmat(Problem.lower,N,1));
            Archive    = Population;

            %% 优化主循环
            t = 1;
            while Algorithm.NotTerminated(Archive)
                % 进化比例 (已评估次数 / 总预算)
                ratio = Problem.FE / Problem.maxFE;

                % HPC 混合分类，同时获得参考解 Ref 与每个解的置信度 confidence
                [~, ~, Catalog, confidence, Ref] = HybridPBI_Classification(...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);

                % 构造样本对 (附带每对样本的置信度权重)
                Input = Population.decs;
                [XXs,YYs,WWs] = GetRelationPairs_confidence(Input, Catalog, confidence);

                % 数据划分 (同步划分权重)
                [TrainIn,TrainOut,TrainW,TestIn,TestOut,~] = DataProcess_confidence(XXs,YYs,WWs);
                xDim = size(TrainIn,2);

                % 训练神经网络 (使用 EW 作为样本权重)
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut,1);

                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
                net.trainParam.showWindow = 0;

                % 归一化样本权重: 平均值拉到 1, 再用 w_min 设下限避免极端样本被忽略
                EW = TrainW(:)';
                if mean(EW) > 1e-12
                    EW = EW / mean(EW);
                else
                    EW = ones(size(EW));
                end
                EW = max(EW, w_min);

                % patternnet 第六个参数为 Error Weights, 对损失加权
                net = train(net, TrainIn_nor', TrainOut_onehot', [], [], EW);

                TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                TestPre    = onehotconv(net(TestIn_nor')',2);
                p_err      = sum(TestPre ~= TestOut)/size(TestPre,1);

                % 模型结构体
                Smodel.X         = Input;
                Smodel.Y         = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net       = net;
                Smodel.p_err     = p_err;

                % 代理模型辅助选择
                Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel);

                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % 环境选择 (从 Archive 中选下一代种群)
                Population = RefSelect(Archive, Problem.N);

                t = t + 1;
            end
        end
    end
end
