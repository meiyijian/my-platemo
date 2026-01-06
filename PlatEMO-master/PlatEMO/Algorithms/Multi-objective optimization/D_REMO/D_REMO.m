classdef D_REMO < ALGORITHM
% <2022> <multi/many> <real> <expensive>
% Expensive multiobjective optimization by relation learning and prediction
% k    ---    6 --- Number of reference solutions
% gmax --- 3000 --- Number of solutions evaluated by surrogate model

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes.
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [k,gmax] = Algorithm.ParameterSet(6,3000);

            %% Initalize the population by Latin hypercube sampling
            if Problem.D <= 10
                N = 11*Problem.D-1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec+repmat(Problem.lower,N,1));
            Archive    = Population;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                % Select reference solutions and preprocess the data
                Ref       = RefSelect(Population,k);
                Input     = Population.decs; 
                Catalog   = GetOutput_PBI(Population.objs,Ref.objs); 
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
                xDim = size(TrainIn,2);
                
                % Train relation model (Original REMO Logic)
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor     = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut,1);
                
                % 建议：增加 'showWindow',0 以静默运行，提高速度
                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
                net.trainParam.showWindow = 0; 
                net.trainParam.showCommandLine = 0; 
                
                net        = train(net,TrainIn_nor',TrainOut_onehot');
                TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                TestPre    = onehotconv(net(TestIn_nor')',2);             
                p_err      = sum(TestPre ~= TestOut)/size(TestPre,1);
                
                Smodel.X   = Input;
                Smodel.Y   = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net       = net;
                Smodel.p_err     = p_err;
                
                %% --- D-REMO 核心修改：学习分布信息 ---
                
                % 策略改进：优先使用 REMO 自己的 PBI 分类结果 (Catalog==1 为非支配/好解)
                % Catalog 通常是 1, 2, ... 或者 1 (Good), -1 (Bad)
                % 假设 GetOutput_PBI 返回 1 代表 Pn (非支配)，非 1 代表 Pd
                % 如果 Catalog 的定义不同，请检查 GetOutput_PBI 的输出
                
                % 【修改前】只用了当前代的 Input
                % GoodDecs = Input(Catalog == 1, :); 

                % 【修改后】使用整个 Archive 的非支配解，分布更精准！
                [FrontNO, ~] = NDSort(Archive.objs, 1);
                GoodDecs = Archive(FrontNO == 1).decs;
                
                % 兜底策略：如果 PBI 划分的好解太少（导致协方差无法计算），则补充 NDSort 的解
                if size(GoodDecs, 1) < Problem.D + 2
                     [F,~] = NDSort(Population.objs, inf);
                     % 取前 50% 的解，保证样本充足
                     GoodDecs = Population(F <= max(1, max(F)/2)).decs;
                end
                
                % 计算分布参数
                mu = mean(GoodDecs, 1); 
                
                % 计算协方差矩阵 (加 try-catch 并不够，需要在源头处理)
                if size(GoodDecs, 1) > 1
                    K = cov(GoodDecs);
                else
                    K = eye(Problem.D); % 极端情况兜底
                end
                
                % --- 关键修复：协方差矩阵正则化 (Regularization) ---
                % 解决高维空间下样本不足导致的矩阵奇异问题
                % 加上一个微小的对角矩阵 (Ridge Regularization)
                K = K + 1e-6 * eye(Problem.D);
                
                % 将分布信息存储到模型结构体中
                Smodel.mu = mu;
                Smodel.K  = K;
                
                %% --- Selection ---
                Next = RSurrogateAssistedSelection(Problem,Ref,Population.decs,gmax,Smodel);
                if ~isempty(Next)
                    Archive = [Archive,Problem.Evaluation(Next)];
                end
                Population = RefSelect(Archive,Problem.N);
            end
        end
	end
end