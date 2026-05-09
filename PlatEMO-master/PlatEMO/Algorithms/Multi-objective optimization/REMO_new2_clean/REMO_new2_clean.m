classdef REMO_new2_clean < ALGORITHM
% <2022> <multi/many> <real> <expensive>
% Expensive multiobjective optimization by relation learning and prediction
% (Modified with Hybrid PBI Classification)
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
                % 进化比例（已评估次数/总预算）
                ratio = Problem.FE / Problem.maxFE;
                
                % 使用 HPC 混合分类，同时获得参考解 Ref
                [good_idx, bad_idx, Catalog, confidence, Ref] = HybridPBI_Classification(...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);
                
                % 构造样本对（仍使用原始方法）
                Input = Population.decs;
                [XXs,YYs] = CleanRelationPairs(Input, Catalog);
                
                % 数据划分
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
                xDim = size(TrainIn,2);
                
                % 训练神经网络
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut,1);
                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
                net.trainParam.showWindow =0;
                net = train(net,TrainIn_nor',TrainOut_onehot');
                TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                TestPre = onehotconv(net(TestIn_nor')',2);
                p_err = sum(TestPre ~= TestOut)/size(TestPre,1);
                
                % 模型结构体
                Smodel.X   = Input;
                Smodel.Y   = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;
                
                % 代理模型辅助选择（注意：这里使用 Ref 作为第二个输入参数）
                Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel);
                
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end
                
                % 环境选择（从 Archive 中选择下一代种群）
                Population = RefSelect(Archive, Problem.N);
                
                t = t + 1;
            end
        end
    end
end