function run_E1(varargin)
% run_E1 - E1 效度检验：confidence 是否真的预测"分类正确性"？
%
% 核心问题：
%   HybridPBI 的 confidence = 1 - |score_v - label_dyn| 被当作"分类可靠性"使用
%   （weighted 模式用 Ws=sqrt(conf_i*conf_j) 加权关系对），但从未校准过。
%   本实验用真实目标值构造真值好类，检验 conf 对"分类正确"的判别力（AUC）。
%
% 判据（预注册）：
%   AUC > 0.6  -> conf 有信息，问题只在阈值放置
%   AUC ≈ 0.5  -> conf 无效，度量必须重设计
%
% 用法：
%   >> run_E1                    % 默认 8问题 x M=[10,20] x 5次 x 5阶段
%   >> run_E1('n_run',3)         % 快速试跑
%
% 输出（写入本文件夹 results/）：
%   E1_summary.csv        - 每快照一行的汇总指标（AUC/ACC 等）
%   E1_solution_level.csv - 逐解明细（conf、分类、真值、是否正确）

    %% ---- 路径设置 ----
    this_dir = fileparts(mfilename('fullpath'));   % E1_conf_validity
    r3_dir   = fileparts(this_dir);                % experiment_round3
    alg_dir  = fileparts(fileparts(r3_dir));       % REMO_new2_AdaMaO
    pe_root  = fileparts(fileparts(fileparts(alg_dir)));  % PlatEMO 根目录（alg -> MO文件夹 -> Algorithms -> PlatEMO）
    addpath(genpath(fullfile(pe_root,'Problems')));            % SOLUTION/PROBLEM/DTLZ/WFG
    addpath(fullfile(pe_root,'Algorithms','Utility functions'));% UniformPoint/NDSort/OperatorGA
    addpath(fullfile(r3_dir,'common'));
    addpath(alg_dir);   % 最后加，置于路径最前，保证用的是本算法的 HybridPBI/RefSelect

    %% ---- 配置 ----
    p = inputParser;
    addParameter(p,'n_run',5);
    addParameter(p,'M_list',[10,20]);
    addParameter(p,'D',30);
    addParameter(p,'N',100);
    parse(p,varargin{:});
    n_run  = p.Results.n_run;
    M_list = p.Results.M_list;
    D      = p.Results.D;
    N      = p.Results.N;

    problems = {@DTLZ1,@DTLZ2,@DTLZ4,@DTLZ7,@WFG3,@WFG4,@WFG6,@WFG9};

    out_dir = fullfile(this_dir,'results');
    if ~exist(out_dir,'dir'); mkdir(out_dir); end

    total = numel(problems)*numel(M_list)*n_run;
    fprintf('==========================================================\n');
    fprintf(' E1 效度检验：conf 是否预测分类正确性\n');
    fprintf(' %d 问题 x M=[%s] x %d 次 x 5 阶段 = %d 快照\n', ...
        numel(problems), num2str(M_list), n_run, total*5);
    fprintf('==========================================================\n');

    sum_rows = {};   % 汇总表
    sol_rows = {};   % 逐解明细表
    good_num = ceil(N/4);
    cnt = 0;

    for ip = 1:numel(problems)
        for M = M_list
            for run = 1:n_run
                cnt = cnt + 1;
                snaps = gen_snapshots(problems{ip}, M, D, N, run);
                pname = func2str(problems{ip});
                k_eff = min(N, max(6, ceil(1.5*M)));   % 与 REMO_new2_AdaMaO_Stat 一致

                for s = 1:numel(snaps)
                    PopObj = snaps(s).PopObj;
                    PopDec = snaps(s).PopDec;
                    ratio  = snaps(s).ratio;

                    % 用真实解构造 SOLUTION，调用被测的分类器（原代码，零改动）
                    Population = SOLUTION(PopDec, PopObj, zeros(N,1));
                    [~,~,Catalog,confidence,~] = HybridPBI_Classification( ...
                        Population, ratio, 'Nref',N, 'k',k_eff, 'theta',5);
                    Catalog    = logical(Catalog(:));
                    confidence = confidence(:);

                    % 真值好类（两种口径）
                    [truth_conv, truth_hyb] = truth_labels(PopObj, good_num, 5);

                    % 解级正确性 + AUC
                    corr_conv = (Catalog == truth_conv);
                    corr_hyb  = (Catalog == truth_hyb);
                    auc_conv  = rank_auc(confidence, corr_conv);
                    auc_hyb   = rank_auc(confidence, corr_hyb);

                    % 关系对级：Ws 是否预测"关系标签正确"
                    [auc_pc, acc_pc, np] = pair_metrics(Catalog, truth_conv, confidence);
                    [auc_ph, acc_ph, ~ ] = pair_metrics(Catalog, truth_hyb,  confidence);

                    sum_rows{end+1} = {pname, M, run, s, snaps(s).gen, ratio, ...
                        mean(confidence), mean(corr_conv), mean(corr_hyb), ...
                        auc_conv, auc_hyb, auc_pc, auc_ph, acc_pc, acc_ph, np}; %#ok<AGROW>

                    for i = 1:N
                        sol_rows{end+1} = {pname, M, run, s, ratio, i, ...
                            confidence(i), Catalog(i), truth_conv(i), truth_hyb(i), ...
                            corr_conv(i), corr_hyb(i)}; %#ok<AGROW>
                    end
                end
                fprintf(' [%3d/%3d] %s M%d run%d 完成\n', cnt, total, pname, M, run);
            end
        end
    end

    %% ---- 写 CSV ----
    Ts = cell2table(vertcat(sum_rows{:}), 'VariableNames', ...
        {'problem','M','run','stage','gen','ratio','mean_conf', ...
         'acc_conv','acc_hyb','auc_conv','auc_hyb', ...
         'auc_pair_conv','auc_pair_hyb','acc_pair_conv','acc_pair_hyb','n_pairs'});
    writetable(Ts, fullfile(out_dir,'E1_summary.csv'));

    Td = cell2table(vertcat(sol_rows{:}), 'VariableNames', ...
        {'problem','M','run','stage','ratio','sol_id', ...
         'conf','catalog','truth_conv','truth_hyb','correct_conv','correct_hyb'});
    writetable(Td, fullfile(out_dir,'E1_solution_level.csv'));

    fprintf('\n==========================================================\n');
    fprintf(' E1 完成！\n');
    fprintf(' 汇总: %s (%d 行)\n', fullfile(out_dir,'E1_summary.csv'), height(Ts));
    fprintf(' 明细: %s (%d 行)\n', fullfile(out_dir,'E1_solution_level.csv'), height(Td));
    fprintf(' 速览: 解级 AUC(conv) 均=%.3f | AUC(hyb) 均=%.3f | 对级 AUC(conv) 均=%.3f\n', ...
        mean(Ts.auc_conv,'omitnan'), mean(Ts.auc_hyb,'omitnan'), mean(Ts.auc_pair_conv,'omitnan'));
    fprintf(' (>0.6=conf有信息, ~0.5=conf无效)\n');
    fprintf(' 下一步: py -3.13 -X utf8 analyze_E1.py\n');
    fprintf('==========================================================\n');
end

%% ============ 关系对级指标 ============
function [auc_p, acc_p, npairs] = pair_metrics(Catalog, truth, conf)
% 复刻 GetRelationPairs_confidence 的四块配对构造（C1C1/C2C2/C1C2/C2C1），
% 权重 W=sqrt(conf_i*conf_j)，检验 W 是否预测"关系标签正确"。
    C1 = find(Catalog);
    C2 = find(~Catalog);

    [I,J] = ndgrid(C1,C1); keep = I~=J;
    P = [I(keep), J(keep)];              L = zeros(nnz(keep),1);
    [I,J] = ndgrid(C2,C2); keep = I~=J;
    P = [P; [I(keep), J(keep)]];         L = [L; zeros(nnz(keep),1)];
    [I,J] = ndgrid(C1,C2);
    P = [P; [I(:), J(:)]];               L = [L;  ones(numel(I),1)];
    [I,J] = ndgrid(C2,C1);
    P = [P; [I(:), J(:)]];               L = [L; -ones(numel(I),1)];

    % 真值关系标签（同类=0，真好vs真坏=+1，反之=-1）
    ti = truth(P(:,1));  tj = truth(P(:,2));
    Lt = zeros(size(L));
    Lt(ti & ~tj)  =  1;
    Lt(~ti & tj)  = -1;

    correct = (L == Lt);
    W = sqrt(conf(P(:,1)) .* conf(P(:,2)));
    auc_p  = rank_auc(W, correct);
    acc_p  = mean(correct);
    npairs = numel(correct);
end
