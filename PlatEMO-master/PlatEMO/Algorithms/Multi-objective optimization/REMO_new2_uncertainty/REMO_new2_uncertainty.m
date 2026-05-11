classdef REMO_new2_uncertainty < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Expensive multiobjective optimization by relation learning with uncertainty analysis
% (HPC + Confidence-aware training + Entropy-based uncertainty selection)
%
% 在 REMO_new2 基础上引入双层不确定性分析:
%   训练阶段: 置信度加权训练 (来自 REMO_new2_confidence)
%   选择阶段: 预测概率信息熵 + UCB 自适应探索 (参考 R2AEA)
%
% 参数:
%   k       - 动态参考解数量 (默认 6)
%   gmax    - 代理模型辅助 GA 内层迭代累计样本上限 (默认 3000)
%   lambda0 - UCB 不确定性初始权重 (默认 0.5)
%   q_keep  - 最终筛选分位数阈值 (默认 0.70)
%   w_min   - 样本权重下限 (默认 0.3)

    methods
        function main(Algorithm,Problem)
            %% 参数设置
            [k,gmax,lambda0,q_keep,w_min] = Algorithm.ParameterSet(6,3000,0.5,0.70,0.3);

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
            while Algorithm.NotTerminated(Archive)
                % 进化比例 (已评估次数 / 总预算)
                ratio = Problem.FE / Problem.maxFE;

                % HPC 混合分类, 获得参考解 Ref 与每个解的置信度 confidence
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

                % 归一化样本权重: 平均值拉到 1, 用 w_min 设下限
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

                % 模型结构体 (附加 lambda 用于 UCB)
                Smodel.X         = Input;
                Smodel.Y         = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net       = net;
                Smodel.p_err     = p_err;
                Smodel.lambda    = lambda0 * (1 - ratio);

                % 不确定性感知的代理模型辅助选择
                Next = RSurrogateAssistedSelection_uncertainty(Problem,Ref,Population.decs,gmax,Smodel,q_keep);

                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % 环境选择 (从 Archive 中选下一代种群)
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
