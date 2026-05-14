classdef REMO_DiRel_noTrans < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_DiRel 消融变体 3：net_S 不做迁移初始化，从头训练
%
% 用途：证明"权重迁移"机制的边际贡献 —— 若 DiRel > noTrans，
% 说明 net_F → net_S 的权重迁移有效缓解了样本稀缺，回应 plan 中缺陷 C 的应对。
%
% 与 REMO_DiRel 的唯一差异：调用本地的 TrainDualScaleNet_noTrans（见同目录）

    methods
        function main(Algorithm,Problem)
            [k_easy_user,tau_conf,alpha,k,gmax,K_ens,win_K] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 3000, 5, 3);

            if k_easy_user <= 0
                k_easy = max(2, min(Problem.M-1, ceil(Problem.M/2)));
            else
                k_easy = max(2, min(Problem.M-1, k_easy_user));
            end

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

            H.d_score = nan(Problem.M, win_K);
            H.nrmse   = nan(Problem.M, win_K);
            H.conf    = nan(Problem.M, win_K);
            gen       = 0;

            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;
                Ref = RefSelect(Population, k);
                [~, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy);

                Input  = Population.decs;
                PopObj = Population.objs;
                RefObj = Ref.objs;

                Catalog_F = GetOutput_PBI(PopObj, RefObj);
                [XX_F, YY_F] = GetRelationPairs(Input, Catalog_F);

                S_easy    = double(S_easy(:)');
                M_sub     = numel(S_easy);
                Ref_S_obj = UniformPoint(size(RefObj,1), M_sub, 'ILD');
                PopObj_sub  = PopObj(:, S_easy);
                P_sub_min   = min(PopObj_sub, [], 1);
                P_sub_max   = max(PopObj_sub, [], 1);
                P_sub_span  = max(P_sub_max - P_sub_min, 1e-12);
                Ref_S_obj   = Ref_S_obj .* P_sub_span + P_sub_min;
                Catalog_S   = GetOutput_PBI(PopObj_sub, Ref_S_obj);
                [XX_S, YY_S] = GetRelationPairs(Input, Catalog_S);

                if isempty(XX_F) || isempty(XX_S)
                    Population = RefSelect(Archive, Problem.N);
                    continue;
                end

                % ---- 消融差异：调用本地 TrainDualScaleNet_noTrans ----
                DualNet = TrainDualScaleNet_noTrans(XX_F, YY_F, XX_S, YY_S, K_ens);

                Smodel = struct();
                Smodel.X        = Input;
                Smodel.Y_F      = Catalog_F;
                Smodel.Y_S      = Catalog_S;
                Smodel.DualNet  = DualNet;
                Smodel.S_easy   = S_easy;
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
