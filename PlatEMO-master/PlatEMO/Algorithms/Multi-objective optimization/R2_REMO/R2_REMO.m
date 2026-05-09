classdef R2_REMO < ALGORITHM
% <2022> <multi/many> <real> <expensive>
% Expensive multiobjective optimization by relation learning and prediction
% (Modified with R2 indicator-based relation labeling)

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [k,gmax] = Algorithm.ParameterSet(6,3000);

            %% Initialize population
            if Problem.D <= 10
                N = 11*Problem.D-1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec+repmat(Problem.lower,N,1));
            Archive    = Population;

            %% Optimization
            t = 1;
            while Algorithm.NotTerminated(Archive)
                % 进化比例
                ratio = Problem.FE / Problem.maxFE;

                % 使用 HPC 混合分类，获得参考解 Ref（不再使用其 Catalog）
                [~, ~, ~, ~, Ref] = HybridPBI_Classification(...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);

                % ---------- 方案一核心改动 ----------
                % 基于 R2 指标重新定义关系标签
                PopObj = Population.objs;
                Z = min(PopObj,[],1);
                % 生成权重向量用于 R2 计算（目标数多时增加数量）
                if Problem.M <= 3
                    nW = 100;
                else
                    nW = 200;
                end
                W = UniformPoint(nW, Problem.M, 'ILD');
                W = W ./ vecnorm(W,2,2);

                % 计算 R2 适应度（越大越好）
                fitness = R2Fitness(PopObj, W, Z);

                % 按适应度中位数将种群划分为“好”与“坏”
                [~, idx] = sort(fitness, 'descend');
                half = ceil(N/2);
                Catalog = false(N,1);
                Catalog(idx(1:half)) = true;   % 前一半为好解
                % ----------------------------------

                % 构造样本对（使用 R2 排序产生的 Catalog）
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input, Catalog);

                % 数据划分与神经网络训练（与原来完全一致）
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
                xDim = size(TrainIn,2);

                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut,1);
                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
                net.trainParam.showWindow =0;
                net = train(net,TrainIn_nor',TrainOut_onehot');
                TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                TestPre = onehotconv(net(TestIn_nor')',2);
                p_err = sum(TestPre ~= TestOut)/size(TestPre,1);

                Smodel.X   = Input;
                Smodel.Y   = Catalog;   % 注意：此处 Y 已基于 R2 指标
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;

                % 代理模型辅助选择
                Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel);

                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % 环境选择
                Population = RefSelect(Archive, Problem.N);
                t = t + 1;
            end
        end
    end
end