classdef REMO_new2_PIEA2 < ALGORITHM
% <2022> <multi/many> <real> <expensive>
% Expensive multiobjective optimization by relation learning and prediction
% (Modified with Hybrid PBI Classification + SDE Indicator Fusion)

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
                [XXs,YYs] = GetRelationPairs(Input, Catalog);
                
                % 数据划分
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
                xDim = size(TrainIn,2);
                
                % 训练关系神经网络
                [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut,1);
                net = patternnet([ceil(xDim*1.5),xDim*1,ceil(xDim/2)]);
                net.trainParam.showWindow =0;
                net = train(net,TrainIn_nor',TrainOut_onehot');
                TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
                TestPre = onehotconv(net(TestIn_nor')',2);
                p_err = sum(TestPre ~= TestOut)/size(TestPre,1);
                
                % ========== 新增：训练 SDE 指标回归模型 ==========
                % 估计前沿形状参数 p
                Lp = Shape_Estimate(Population, Problem.N);
                % 计算当前种群每个解的 SDE 指标值
                SDE_Fitness = calFitness_SDE(Population.objs, Lp);
                % 训练 SVM 回归模型
                IndicatorModel = fitrsvm(Population.decs, SDE_Fitness, ...
                    'KernelFunction', 'rbf', 'KernelScale', 'auto', 'Standardize', true);
                % =============================================
                
                % 模型结构体（加入指标模型）
                Smodel.X   = Input;
                Smodel.Y   = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net = net;
                Smodel.p_err = p_err;
                Smodel.IndicatorModel = IndicatorModel;   % 新增
                Smodel.Lp = Lp;                            % 新增
                
                % 代理模型辅助选择（使用融合得分）
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

% ========== 从 PIEA 移植的辅助函数 ==========

function Fitness = calFitness_SDE(PopObj, Lp)
% Calculate the fitness by shift-based density (SDE)
    N      = size(PopObj,1);
    fmax   = max(PopObj,[],1);
    fmin   = min(PopObj,[],1);
    PopObj = (PopObj-repmat(fmin,N,1))./repmat(fmax-fmin,N,1);
    Dis    = inf(N);
    for i = 1 : N
        SPopObj = max(PopObj,repmat(PopObj(i,:),N,1));
        for j = [1:i-1,i+1:N]
            Dis(i,j) = norm(PopObj(i,:)-SPopObj(j,:));
        end
    end
    Fitness = min(Dis,[],2);
    Fitness = 3/(max(Fitness)+eps-min(Fitness))*(Fitness-min(Fitness));
    dis = pdist2(PopObj, min(PopObj), 'minkowski', Lp);
    dis = -3/(max(dis)+eps-min(dis))*(dis-min(dis));
    Fitness(Fitness<10^-4) = dis(Fitness<10^-4);
    Fitness = tansig(Fitness);
end

function p = Shape_Estimate(Population, N)
% Estimate the shape of PF
    [FrontNo,~] = NDSort(Population.objs, N);
    Pop = Population(FrontNo<=1);
    if length(Pop) < 20
        p = 1;
        return;
    end
    PopObj = Pop.objs;
    [Np,~] = size(PopObj);
    PopObj = (PopObj - min(PopObj)) ./ (max(PopObj) - min(PopObj));
    k = 1.5;
    CP = [0.27 0.36 0.43 0.5 0.57 0.66 0.75 0.86 1 1.15 1.35 1.6 2 2.4 3.1 4.2 6.5];
    Vp = zeros(1,length(CP));
    for i = 1:length(CP)
        Gp = (sum(PopObj.^CP(i),2)).^(1/CP(i));
        temp = sort(Gp);
        Q1 = temp(max(fix(Np*0.25),1));
        Q3 = temp(max(fix(Np*0.75),1));
        Max = Q3 + k*(Q3-Q1);
        Gp(Gp>Max) = [];
        Vp(i) = std(Gp./max(Gp));
    end
    [~,idx] = min(Vp);
    p = CP(idx);
end