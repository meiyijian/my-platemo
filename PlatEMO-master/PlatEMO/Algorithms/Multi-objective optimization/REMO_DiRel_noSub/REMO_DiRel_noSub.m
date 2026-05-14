classdef REMO_DiRel_noSub < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_DiRel 消融变体 2：去掉子目标模型 net_S，仲裁器退化为 net_F 单源
%
% 用途：证明"子目标关系网络"的边际贡献 —— 若 DiRel > noSub，
% 说明双尺度建模本身贡献，而不仅是 bagging 集成自身的稳定性收益。
%
% 与 REMO_DiRel 的唯一差异：训练时不构造 net_S，仲裁时直接用 net_F 集成均值

    methods
        function main(Algorithm,Problem)
            [~,tau_conf,~,k,gmax,K_ens,~] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 3000, 5, 3);

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive = Population;

            while Algorithm.NotTerminated(Archive)
                Ref = RefSelect(Population, k);

                Input  = Population.decs;
                PopObj = Population.objs;
                RefObj = Ref.objs;

                Catalog_F = GetOutput_PBI(PopObj, RefObj);
                [XX_F, YY_F] = GetRelationPairs(Input, Catalog_F);

                if isempty(XX_F)
                    Population = RefSelect(Archive, Problem.N);
                    continue;
                end

                % ---- 消融差异：只训 net_F 集成，跳过 net_S ----
                DualNet = TrainDualScaleNet(XX_F, YY_F, XX_F, YY_F, K_ens);
                % 复用 net_F 作为 net_S，使仲裁器退化为单源（mu_F==mu_S, sigma 相同）
                Smodel = struct();
                Smodel.X        = Input;
                Smodel.Y_F      = Catalog_F;
                Smodel.Y_S      = Catalog_F;
                Smodel.DualNet  = DualNet;
                Smodel.S_easy   = 1:Problem.M;
                Smodel.tau_conf = tau_conf;

                Next = ArbitratedSelection(Problem, Ref, Input, gmax, Smodel);

                remain = Problem.maxFE - Problem.FE;
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1), remain), :);
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
