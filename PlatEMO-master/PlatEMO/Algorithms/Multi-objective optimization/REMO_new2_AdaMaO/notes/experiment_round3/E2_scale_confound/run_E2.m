function run_E2(varargin)
% run_E2 - E2 尺度混淆检验：confidence 是否被目标量纲污染？
%
% 核心问题：
%   score_v = 1/(1+PBI) 的 PBI 在未归一化的原始目标空间计算，
%   而 label_dyn（GetOutput_PBI）内部已除以 ||Ref-Zmin||、对均匀缩放不变。
%   => 若把同一种群的目标值整体乘以常数 c（问题本质完全不变），
%      conf 的漂移只能来自 score_v 的尺度依赖。
%
% 预注册预测（来自代码分析，实验前写下）：
%   c -> 0   : score_v -> 1，conf_i -> label_i，mean_conf -> 好类标签占比
%   c -> inf : score_v -> 0，conf_i -> 1-label_i，mean_conf -> 坏类标签占比
%   即 mean_conf 随 c 单调滑动，且 mean_conf>=0.55 的门控会被量纲翻转。
%
% 变体列表（对每个快照各算一次 confidence）：
%   base    : 原始目标值（c=1）
%   x0.1/x10/x100 : 均匀缩放（问题本质不变，理想度量应完全不变）
%   wfg_style     : 第 j 个目标乘 2j（把 DTLZ 变成 WFG 式量纲，检验跨问题可比性）
%   de_wfg        : 第 j 个目标除 2j（把 WFG 式量纲拉平）
%   minmax        : 各目标 min-max 归一化到 [0,1]（候选修复方案的预演）
%
% 用法：
%   >> run_E2                    % 默认 8问题 x M=[10,20] x 5次 x 5阶段
%   >> run_E2('n_run',2)         % 快速试跑
%
% 输出（写入本文件夹 results/）：
%   E2_variants.csv - 每快照 x 每变体一行

    %% ---- 路径设置 ----
    this_dir = fileparts(mfilename('fullpath'));   % E2_scale_confound
    r3_dir   = fileparts(this_dir);                % experiment_round3
    alg_dir  = fileparts(fileparts(r3_dir));       % REMO_new2_AdaMaO
    pe_root  = fileparts(fileparts(fileparts(alg_dir)));  % PlatEMO 根目录（alg -> MO文件夹 -> Algorithms -> PlatEMO）
    addpath(genpath(fullfile(pe_root,'Problems')));
    addpath(fullfile(pe_root,'Algorithms','Utility functions'));
    addpath(fullfile(r3_dir,'common'));
    addpath(alg_dir);   % 最后加，保证用本算法的 HybridPBI/RefSelect

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
    fprintf(' E2 尺度混淆检验：conf 是否被目标量纲污染\n');
    fprintf(' %d 问题 x M=[%s] x %d 次 x 5 阶段 x 7 变体\n', ...
        numel(problems), num2str(M_list), n_run);
    fprintf('==========================================================\n');

    rows = {};
    cnt  = 0;

    for ip = 1:numel(problems)
        for M = M_list
            variants = build_variants(M);
            for run = 1:n_run
                cnt = cnt + 1;
                % seed 与 E1 相同 -> 两实验的种群完全一致，可互相印证
                snaps = gen_snapshots(problems{ip}, M, D, N, run);
                pname = func2str(problems{ip});
                k_eff = min(N, max(6, ceil(1.5*M)));

                for s = 1:numel(snaps)
                    PopObj = snaps(s).PopObj;
                    PopDec = snaps(s).PopDec;
                    ratio  = snaps(s).ratio;

                    % 先算基准（c=1）
                    [conf_b, cat_b, mc_b] = classify_once(PopDec, PopObj, ratio, N, k_eff);

                    for iv = 1:numel(variants)
                        ObjV = variants(iv).fn(PopObj);
                        if strcmp(variants(iv).name,'base')
                            conf_v = conf_b;  cat_v = cat_b;  mc_v = mc_b;
                        else
                            [conf_v, cat_v, mc_v] = classify_once(PopDec, ObjV, ratio, N, k_eff);
                        end
                        % 与基准比较
                        rho  = corr(conf_v, conf_b, 'type','Spearman');
                        jac  = nnz(cat_v & cat_b) / nnz(cat_v | cat_b);   % 好类集合 Jaccard
                        rows{end+1} = {pname, M, run, s, ratio, variants(iv).name, ...
                            mc_v, double(mc_v>=0.55), mc_v-mc_b, rho, jac}; %#ok<AGROW>
                    end
                end
                fprintf(' [%3d/%3d] %s M%d run%d 完成\n', cnt, total, pname, M, run);
            end
        end
    end

    %% ---- 写 CSV ----
    T = cell2table(vertcat(rows{:}), 'VariableNames', ...
        {'problem','M','run','stage','ratio','variant', ...
         'mean_conf','gate_weighted','delta_mean_conf','spearman_vs_base','jaccard_vs_base'});
    writetable(T, fullfile(out_dir,'E2_variants.csv'));

    fprintf('\n==========================================================\n');
    fprintf(' E2 完成！输出: %s (%d 行)\n', fullfile(out_dir,'E2_variants.csv'), height(T));
    % 速览：均匀缩放下 mean_conf 的漂移（理想度量应为 0）
    for v = {'x0.1','x10','x100'}
        sub = T(strcmp(T.variant,v{1}),:);
        fprintf(' 变体 %-5s: |Δmean_conf| 均=%.3f, 门控翻转率=%.0f%%\n', v{1}, ...
            mean(abs(sub.delta_mean_conf)), ...
            100*mean(sub.gate_weighted ~= (T.gate_weighted(strcmp(T.variant,'base')))));
    end
    fprintf(' (理想的尺度不变度量：Δ=0、翻转率=0%%)\n');
    fprintf(' 下一步: py -3.13 -X utf8 analyze_E2.py\n');
    fprintf('==========================================================\n');
end

%% ============ 变体定义 ============
function variants = build_variants(M)
    col = 2*(1:M);   % WFG 式量纲：第 j 目标幅度 ~ 2j
    variants = struct('name',{},'fn',{});
    variants(end+1) = struct('name','base',     'fn',@(O) O);
    variants(end+1) = struct('name','x0.1',     'fn',@(O) O*0.1);
    variants(end+1) = struct('name','x10',      'fn',@(O) O*10);
    variants(end+1) = struct('name','x100',     'fn',@(O) O*100);
    variants(end+1) = struct('name','wfg_style','fn',@(O) O .* col);
    variants(end+1) = struct('name','de_wfg',   'fn',@(O) O ./ col);
    variants(end+1) = struct('name','minmax',   'fn',@minmax_norm);
end

function O = minmax_norm(O)
    Zmin  = min(O,[],1);
    range = max(max(O,[],1) - Zmin, 1e-12);
    O = (O - Zmin) ./ range;
end

%% ============ 单次分类调用 ============
function [conf, cat, mc] = classify_once(PopDec, PopObj, ratio, N, k_eff)
% 用（可能被缩放的）目标值构造 SOLUTION，调用原版分类器
    Population = SOLUTION(PopDec, PopObj, zeros(N,1));
    [~,~,cat,conf,~] = HybridPBI_Classification( ...
        Population, ratio, 'Nref',N, 'k',k_eff, 'theta',5);
    cat  = logical(cat(:));
    conf = conf(:);
    mc   = mean(conf);
end
