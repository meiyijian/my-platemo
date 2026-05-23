classdef REMO_DiRel_dualProbe < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% REMO_DiRel with dual-network probe: records per-candidate predictions,
% fusion weights, conflict flags, and Pareto ground truth at each generation.

    methods
        function main(Algorithm, Problem)
            [k_easy_user, tau_conf, alpha, k, gmax, K_ens, win_K, probe_out_path] = ...
                Algorithm.ParameterSet(-1, 0.3, 0.6, 6, 1000, 3, 3, '');

            pairMax   = 6000;
            anchorMax = 30;

            if Problem.M <= 2
                k_easy = 1;
            elseif k_easy_user <= 0
                k_easy = max(2, min(Problem.M-1, ceil(Problem.M/2)));
            else
                k_easy = max(2, min(Problem.M-1, k_easy_user));
            end

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end

            PopDec = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower, N, 1) .* PopDec + ...
                repmat(Problem.lower, N, 1));
            Archive = Population;

            H.d_score = nan(Problem.M, win_K);
            H.model   = nan(Problem.M, win_K);
            H.improve = nan(Problem.M, win_K);
            H.conf    = nan(Problem.M, win_K);
            H.best    = nan(Problem.M, 1);
            gen       = 0;

            % ====== PROBE state ======
            probe_records = {};
            gen_records   = {};
            % =========================

            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                Ref = RefSelect(Population, k);
                [d_score, H, S_easy] = DifficultyProfiler(Population, H, gen, alpha, k_easy);

                Input  = Population.decs;
                PopObj = Population.objs;
                RefObj = Ref.objs;

                Catalog_F = GetOutput_PBI(PopObj, RefObj);
                [XX_F, YY_F] = GetRelationPairsBudgeted(Input, Catalog_F, pairMax);

                S_easy    = double(S_easy(:)');
                M_sub     = numel(S_easy);
                PopObjSub = PopObj(:, S_easy);

                Ref_S_obj = UniformPoint(size(RefObj,1), M_sub, 'ILD');
                P_min     = min(PopObjSub, [], 1);
                P_span    = max(max(PopObjSub, [], 1) - P_min, 1e-12);
                Ref_S_obj = Ref_S_obj .* P_span + P_min;

                Catalog_S = GetOutput_PBI(PopObjSub, Ref_S_obj);
                [XX_S, YY_S] = GetRelationPairsBudgeted(Input, Catalog_S, pairMax);

                Next = [];
                used_fallback = true;

                if ~isempty(XX_F) && ~isempty(XX_S)
                    DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens);

                    Smodel = struct();
                    Smodel.X              = Input;
                    Smodel.Y_F            = Catalog_F;
                    Smodel.Y_S            = Catalog_S;
                    Smodel.DualNet        = DualNet;
                    Smodel.S_easy         = S_easy;
                    Smodel.tau_conf       = tau_conf;
                    Smodel.anchorMax      = anchorMax;
                    Smodel.easyDifficulty = mean(d_score(S_easy));

                    % ====== PROBE: record per-generation summary ======
                    try
                        gen_rec = struct();
                        gen_rec.gen = gen;
                        gen_rec.FE  = Problem.FE;
                        gen_rec.N   = size(Input, 1);
                        gen_rec.M   = Problem.M;
                        gen_rec.S_easy = S_easy;
                        gen_rec.d_score = d_score;
                        gen_rec.p_err_F = DualNet.p_err_F;
                        gen_rec.p_err_S = DualNet.p_err_S;
                        gen_rec.PopObj  = PopObj;

                        % 样本一部分候选做详细分析（避免太慢）
                        % 先用 ArbitratedSelection 生成候选，再对这些候选做分析
                        gen_records{end+1} = gen_rec; %#ok<AGROW>
                    catch ME
                        warning('Gen summary failed at gen %d: %s', gen, ME.message);
                    end
                    % =====================================================

                    % ====== PROBE: record candidate-level metrics ======
                    % 生成一批候选解用于分析（不影响算法正常流程）
                    try
                        testCand = OperatorGA(Problem, [Input; Ref.decs], {1, 20, 1, 20});
                        % 限制候选数量以控制计算开销
                        if size(testCand, 1) > 50
                            sel = randperm(size(testCand, 1), 50);
                            testCand = testCand(sel, :);
                        end
                        % 边界裁剪
                        Lower = repmat(Problem.lower, size(testCand,1), 1);
                        Upper = repmat(Problem.upper, size(testCand,1), 1);
                        testCand = min(max(testCand, Lower), Upper);

                        rec = compute_dualnet_metrics(Problem, Population, testCand, Smodel, gen, Problem.FE);
                        probe_records{end+1} = rec; %#ok<AGROW>

                        % 增量保存（PlatEMO通过异常退出，循环后save不可达）
                        probe_data = probe_records; %#ok<NASGU>
                        gen_data   = gen_records;   %#ok<NASGU>
                        problem_name = class(Problem); %#ok<NASGU>
                        M_val = Problem.M; %#ok<NASGU>
                        D_val = Problem.D; %#ok<NASGU>
                        save(probe_out_path, 'probe_data', 'gen_data', ...
                             'problem_name', 'M_val', 'D_val', '-v7');
                    catch ME
                        warning('Probe failed at gen %d: %s', gen, ME.message);
                    end
                    % =====================================================

                    Next = ArbitratedSelection(Problem, Ref, Input, gmax, Smodel);
                    used_fallback = isempty(Next);
                end

                if isempty(Next)
                    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 20, 1, 20});
                end

                remain = Problem.maxFE - Problem.FE;
                if remain > 0
                    Next = sanitizeCandidates(Next, Problem, Archive, remain);
                    Archive = [Archive, Problem.Evaluation(Next)];
                end

                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end


%% ========================================================================
%  辅助函数
%  ========================================================================

function Next = sanitizeCandidates(Next, Problem, Archive, remain)
    if isempty(Next)
        Next = randomFill(Problem, min(4, remain));
        return;
    end
    Lower = repmat(Problem.lower, size(Next,1), 1);
    Upper = repmat(Problem.upper, size(Next,1), 1);
    Next  = min(max(Next, Lower), Upper);
    Next = unique(Next, 'rows', 'stable');
    if ~isempty(Archive)
        old  = ismember(Next, Archive.decs, 'rows');
        Next = Next(~old, :);
    end
    if isempty(Next)
        Next = randomFill(Problem, min(4, remain));
    elseif size(Next,1) > remain
        Next = Next(1:remain, :);
    end
end


function X = randomFill(Problem, n)
    if n <= 0
        X = zeros(0, Problem.D);
        return;
    end
    U = UniformPoint(n, Problem.D, 'Latin');
    X = repmat(Problem.upper-Problem.lower, n, 1) .* U + repmat(Problem.lower, n, 1);
end
