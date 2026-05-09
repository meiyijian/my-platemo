classdef R2REMO_SR < ALGORITHM
% <2025> <multi/many> <real> <expensive>
% R²-REMO-SR: R2 indicator-based Soft Relation learning for Expensive MOPs

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [k, gmax] = Algorithm.ParameterSet(6, 3000);
            alpha_soft = 5;    % sigmoid陡峭度

            %% Initialize population
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec+repmat(Problem.lower,N,1));
            Archive    = Population;

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                % 进化比例
                ratio = Problem.FE / Problem.maxFE;

                % 获取参考解 Ref（沿用原RefSelect）
                Ref = RefSelect(Population, k);

                % ---------- R2适应度计算 ----------
                PopObj = Population.objs;
                Z = min(PopObj, [], 1);
                if Problem.M <= 3
                    nW = 100;
                else
                    nW = 200;
                end
                W = UniformPoint(nW, Problem.M, 'ILD');
                W = W ./ vecnorm(W, 2, 2);
                Fitness = R2Fitness(PopObj, W, Z);   % N×1

                % ---------- 构造软关系对 ----------
                Input = Population.decs;
                [XXs, Ps] = GetSoftRelationPairs(Input, Fitness, alpha_soft);

                % ---------- 数据划分 ----------
                % 沿用原DataProcess的逻辑，但这里只需要分成训练/测试
                % 适配连续目标，我们直接用简单随机划分
                randIdx = randperm(size(XXs,1));
                trainNum = ceil(0.75 * size(XXs,1));
                TrainIn = XXs(randIdx(1:trainNum), :);
                TrainOut = Ps(randIdx(1:trainNum));
                TestIn  = XXs(randIdx(trainNum+1:end), :);
                TestOut = Ps(randIdx(trainNum+1:end));

                % ---------- 训练神经网络（回归/二分类概率） ----------
                xDim = size(TrainIn, 2);
                % 网络：隐藏层结构与原REMO一致，输出层1个节点+sigmoid
                net = feedforwardnet([ceil(xDim*1.5), xDim, ceil(xDim/2)]);
                net.layers{end}.transferFcn = 'logsig';  % sigmoid
                net.trainFcn = 'trainscg';               % scaled conjugate gradient
                net.trainParam.showWindow = 0;
                net.divideFcn = 'dividetrain';           % 全部用于训练（因已手动划分）
                net = train(net, TrainIn', TrainOut');   % 输入需转置

                % 测试集预测与误差
                TestPred = net(TestIn')';
                p_err = mean((TestPred - TestOut).^2);   % MSE

                % ---------- 构建代理模型结构体 ----------
                Smodel.X   = Input;
                Smodel.fitness = Fitness;   % 保存适应度
                Smodel.net = net;
                Smodel.p_err = p_err;
                % 储存归一化参数（若需要）
                Smodel.mp_struct = [];       % 若不使用mapminmax可留空

                % ---------- 代理模型辅助选择 ----------
                Next = RSurrogateAssistedSelection_SR(Problem, Ref, Input, gmax, Smodel);

                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % 环境选择
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end