classdef CSEA < ALGORITHM
% <2019> <multi/many> <real/integer> <expensive>
% Classification based surrogate-assisted evolutionary algorithm
% k    ---    6 --- Number of reference solutions
% gmax --- 3000 --- Number of solutions evaluated by surrogate model

%------------------------------- Reference --------------------------------
% L. Pan, C. He, Y. Tian, H. Wang, X. Zhang, and Y. Jin. A classification
% based surrogate-assisted evolutionary algorithm for expensive
% many-objective optimization. IEEE Transactions on Evolutionary
% Computation, 2019, 23(1): 74-88.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He

    methods
        function main(Algorithm,Problem)
            %% 参数设置
            % k: 参考解的数量，默认为6
            % gmax: 代理模型评估的最大解数量，默认为3000
            [k,gmax] = Algorithm.ParameterSet(6,3000);

            %% 使用拉丁超立方采样初始化种群
            % N: 初始种群大小，取11*D-1和109中的较小值
            % PopDec: 通过拉丁超立方采样生成的初始决策变量
            % Population: 初始评估后的种群
            % Arc: 外部存档，用于保存所有评估过的解
            N          = min(11*Problem.D-1,109);
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec+repmat(Problem.lower,N,1));
            Arc        = Population;
            
            %% 初始化神经网络模型
            % 隐藏层大小设置为决策变量维度的2倍（向上取整）
            % 构建神经网络架构：输入层 -> 全连接层 -> 批归一化层 -> ReLU激活层 -> 全连接层 -> Sigmoid层 -> 回归层
            hiddenLayerSize = ceil(Problem.D*2);
            layers = [featureInputLayer(Problem.D,'Normalization', 'zscore')
                    fullyConnectedLayer(hiddenLayerSize)
                    batchNormalizationLayer
                    reluLayer
                    fullyConnectedLayer(1)
                    sigmoidLayer
                    regressionLayer];

            % 设置训练参数
            maxEpochs = 400;        % 最大训练轮数
            miniBatchSize = 32;     % 小批量大小
            options = trainingOptions('adam', ...
                        'ExecutionEnvironment','auto', ... % 自动选择执行环境（CPU或GPU）
                        'MaxEpochs',maxEpochs, ...
                        'MiniBatchSize',miniBatchSize, ...
                        'Shuffle','every-epoch', ...        % 每轮打乱数据
                        'Plots','none', ...                 % 不显示训练过程图
                        'Verbose',false);                   % 不显示详细训练信息

            %% 优化主循环
            while Algorithm.NotTerminated(Arc)
                % 选择参考解并预处理数据
                % Ref: 从当前种群中选择的参考解
                % Input: 种群的决策变量
                % Output: 根据参考解计算的分类标签
                % rr: 正样本比例
                % tr: 阈值调整参数
                Ref    = RefSelect(Population,k);
                Input  = Population.decs;  
                Output = GetOutput(Population.objs,Ref.objs); 
                rr     = sum(Output)/length(Output);
                tr     = min(rr,1-rr)*0.5;
                
                % 划分训练集和测试集 
                [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(Input,Output);
                
                % 训练神经网络模型
                net = trainNetwork(TrainIn,TrainOut-0,layers,options);

                % 计算错误率
                % TestPre: 测试集的预测结果
                % p0: 正样本的平均预测误差
                % p1: 负样本的平均预测误差
                TestPre = predict(net,TestIn);
                IndexGood = TestOut==1;
                p0 = sum(abs((TestOut(IndexGood)-TestPre(IndexGood))))/sum(IndexGood);
                p1 = sum(abs((TestOut(~IndexGood)-TestPre(~IndexGood))))/sum(~IndexGood);

                % 基于代理模型进行辅助选择，并更新种群
                % Next: 代理辅助选择的有希望的解
                Next = SurrogateAssistedSelection(Problem,net,p0,p1,Ref,Population.decs,gmax,tr);
                
                % 评估新解并更新外部存档
                if ~isempty(Next)
                    Arc = [Arc,Problem.Evaluation(Next)];
                end
                
                % 从外部存档中选择新一代种群
                Population = RefSelect(Arc,Problem.N);
            end
        end
    end
end