function run_round2(varargin)
% run_round2 - 第二轮实验：10次运行 + 逐代诊断量记录
%
% 与第一轮（mode_stat/，3次，仅模式计数）的区别：
%   1. 每问题独立运行 10 次（统计意义充分）
%   2. 统计版算法已升级，每代额外记录 p_err/prev_p_err/coverage/degeneracy/mean_conf
%   3. 输出到独立文件夹 experiment_round2/，不覆盖第一轮数据
%
% 产出两份 CSV（由 collect_round2 生成）：
%   mode_distribution_r2.csv  — 模式占比汇总（160行）
%   diagnostics_r2.csv        — 逐代诊断量（每行一代，约5440行）
%
% 用法：
%   >> cd '...\REMO_new2_AdaMaO\notes\experiment_round2'
%   >> run_round2                    % 默认10次，M=[10,20]，跑完自动生成CSV
%   >> run_round2('n_run',5)         % 先跑5次试
%   >> run_round2('reproducible',true) % 固定种子可复现

    %% ---- 路径设置 ----
    this_dir = fileparts(mfilename('fullpath'));
    mode_stat_dir = fullfile(fileparts(this_dir), 'mode_stat');
    addpath(this_dir);
    addpath(mode_stat_dir);

    %% ---- 默认配置 ----
    p = inputParser;
    addParameter(p,'n_run',10);
    addParameter(p,'M_list',[10,20]);
    addParameter(p,'D',30);
    addParameter(p,'N',100);
    addParameter(p,'maxFE',300);
    addParameter(p,'reproducible',false);
    parse(p,varargin{:});

    %% ---- 精选 8 问题（同第一轮，保证可比）----
    problems = {@DTLZ1,@DTLZ2,@DTLZ4,@DTLZ7, @WFG3,@WFG4,@WFG6,@WFG9};

    %% ---- 输出目录（独立，不覆盖第一轮）----
    stat_dir = fullfile(this_dir, 'stat_data');

    total = numel(problems)*numel(p.Results.M_list)*p.Results.n_run;
    fprintf('==========================================================\n');
    fprintf(' 第二轮实验：10次运行 + 逐代诊断量记录\n');
    fprintf('==========================================================\n');
    fprintf(' 问题  : DTLZ1,2,4,7 + WFG3,4,6,9（同第一轮，保证可比）\n');
    fprintf(' M     : [%s]\n', num2str(p.Results.M_list));
    fprintf(' 每问题: %d 次\n', p.Results.n_run);
    fprintf(' 总运行: %d （预计 %.1f 小时）\n', total, total*5/60);
    fprintf(' 输出  : %s\n', stat_dir);
    fprintf(' 随机  : %s\n', ternary(p.Results.reproducible,'固定 rng(runid)','shuffle'));
    fprintf('==========================================================\n\n');

    %% ---- 运行实验（复用 run_mode_stat）----
    run_mode_stat( ...
        'problems',    problems, ...
        'M_list',      p.Results.M_list, ...
        'D',           p.Results.D, ...
        'N',           p.Results.N, ...
        'maxFE',       p.Results.maxFE, ...
        'n_run',       p.Results.n_run, ...
        'reproducible',p.Results.reproducible, ...
        'stat_dir',    stat_dir);

    %% ---- 自动生成两份 CSV ----
    fprintf('\n>>> 实验完成，生成 CSV 汇总 ...\n');
    collect_round2('stat_dir', stat_dir);

    fprintf('\n==========================================================\n');
    fprintf(' 全部完成！\n');
    fprintf(' 模式分布: experiment_round2/mode_distribution_r2.csv\n');
    fprintf(' 逐代诊断: experiment_round2/diagnostics_r2.csv\n');
    fprintf('==========================================================\n');
end

function s = ternary(cond,a,b)
    if cond; s=a; else; s=b; end
end
