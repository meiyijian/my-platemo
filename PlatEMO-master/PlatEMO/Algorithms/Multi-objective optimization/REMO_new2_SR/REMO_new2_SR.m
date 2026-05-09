classdef REMO_new2_SR < ALGORITHM
% <2025> <multi/many> <real> <expensive>
% REMO_new2_SR_Strict: Strict Soft Relation version of REMO_new2
%   Only changes: hard labels -> soft labels, everything else unchanged

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [k, gmax] = Algorithm.ParameterSet(6, 3000);
            alpha_soft = 5;

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
                ratio = Problem.FE / Problem.maxFE;

                % 使用 HPC 混合分类，获得 good_idx, bad_idx, Catalog, Ref, score_hybrid
                [good_idx, bad_idx, Catalog, ~, Ref, score_hybrid] = HybridPBI_Classification(...
                    Population, ratio, 'Nref', N, 'k', k, 'theta', 5);

                Input = Population.decs;

                % ========== 唯一改动1：构造软关系对 ==========
                [XXs, Ps] = GetSoftRelationPairsFromCatalog(Input, Catalog, score_hybrid, alpha_soft);
                % 原版是： [XXs, YYs] = GetRelationPairs(Input, Catalog);

                % ========== 数据划分（沿用原 DataProcess 逻辑，但适配连续输出）==========
                randIdx = randperm(size(XXs,1));
                trainNum = ceil(0.75 * size(XXs,1));
                TrainIn = XXs(randIdx(1:trainNum), :);
                TrainOut = Ps(randIdx(1:trainNum));
                TestIn  = XXs(randIdx(trainNum+1:end), :);
                TestOut = Ps(randIdx(trainNum+1:end));

                % ========== 唯一改动2：网络结构适配二分类概率输出 ==========
                xDim = size(TrainIn, 2);
                net = feedforwardnet([ceil(xDim*1.5), xDim, ceil(xDim/2)]);
                net.layers{end}.transferFcn = 'logsig';   % sigmoid 输出
                net.trainFcn = 'trainscg';
                net.trainParam.showWindow = 0;
                net.divideFcn = 'dividetrain';
                net = train(net, TrainIn', TrainOut');
                % 原版是： net = patternnet(...) + train(net, TrainIn_nor', TrainOut_onehot');

                TestPred = net(TestIn')';
                p_err = mean((TestPred - TestOut).^2);

                % 模型结构体（沿用原格式，Y 改为连续 Fitness）
                Smodel.X   = Input;
                Smodel.fitness = score_hybrid;  % 原版 Smodel.Y = Catalog;
                Smodel.net = net;
                Smodel.p_err = p_err;

                % ========== 代理辅助选择（使用 SR 版评分函数）==========
                Next = RSurrogateAssistedSelection_SR(Problem, Ref, Input, gmax, Smodel);
                % 原版是： Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel);

                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                % 环境选择（完全不动）
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end