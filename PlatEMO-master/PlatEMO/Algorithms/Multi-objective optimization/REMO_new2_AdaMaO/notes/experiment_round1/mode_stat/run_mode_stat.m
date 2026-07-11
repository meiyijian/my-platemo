function run_mode_stat(varargin)
% run_mode_stat - 运行 AdaMaO 模式占比统计实验
%
% 遍历 DTLZ1-7 + WFG1-9、M=[10,20]、每问题 10 次，调用 PlatEMO 运行
% REMO_new2_AdaMaO_Stat。每次运行的每代模式统计会保存为 .mat 文件。
%
% 用法（在 MATLAB 命令行）：
%   >> run_mode_stat              % 跑全部（DTLZ1-7+WFG1-9, M=10&20, 10次）
%   >> run_mode_stat('n_run',3)   % 只跑 3 次/问题（快速验证）
%   >> run_mode_stat('problems',{@DTLZ2,@WFG4})  % 只跑指定问题
%   >> run_mode_stat('M_list',[10])              % 只跑 M=10
%   >> run_mode_stat('reproducible',true)        % 固定随机种子（可复现）
%
% 可选键值对：
%   'problems'    <cell of fn handles>  测试问题，默认 DTLZ1-7+WFG1-9
%   'M_list'      <vector>              目标维度列表，默认 [10,20]
%   'D'           <scalar>              决策变量维度，默认 30
%   'N'           <scalar>              种群规模，默认 100
%   'maxFE'       <scalar>              最大评估次数，默认 300
%   'n_run'       <scalar>              每问题独立运行次数，默认 10
%   'reproducible'<logical>             是否固定随机种子（rng(runid)），默认 false
%   'stat_dir'    <char>                统计输出目录，默认 <算法目录>/notes/mode_stat/stat_data
%
% 输出：每次运行一个 .mat 文件，文件名 <Problem>_M<M>_D<D>_run<runid>.mat
%       里面是 stat 结构体，含两类模式的逐代计数与轨迹。
%       跑完后运行 collect_mode_stat 生成 CSV。

    %% ---- 解析可选参数 ----
    p = inputParser;
    addParameter(p,'problems',default_problems());
    addParameter(p,'M_list',[10,20]);
    addParameter(p,'D',30);
    addParameter(p,'N',100);
    addParameter(p,'maxFE',300);
    addParameter(p,'n_run',10);
    addParameter(p,'reproducible',false);
    addParameter(p,'stat_dir','');
    parse(p,varargin{:});
    problems    = p.Results.problems;
    M_list      = p.Results.M_list;
    D           = p.Results.D;
    N           = p.Results.N;
    maxFE       = p.Results.maxFE;
    n_run       = p.Results.n_run;
    reproducible= p.Results.reproducible;
    stat_dir    = p.Results.stat_dir;

    %% ---- 设置 PlatEMO 路径 ----
    platemo_root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    % mfilename 在 .../notes/mode_stat/ 下，往上3级到 PlatEMO 根
    cd(platemo_root);
    addpath(genpath(platemo_root));

    %% ---- 设置统计输出目录 ----
    if isempty(stat_dir)
        stat_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))), 'stat_data');
    end
    if ~exist(stat_dir,'dir'); mkdir(stat_dir); end
    setenv('ADAMAO_STAT_DIR', stat_dir);

    %% ---- 静默 outputFcn（避免画图/清屏）----
    silent = @(~,~)[];

    %% ---- 实验配置摘要 ----
    total = numel(problems)*numel(M_list)*n_run;
    fprintf('========================================\n');
    fprintf(' AdaMaO 模式占比统计实验\n');
    fprintf('========================================\n');
    fprintf(' 问题数      : %d\n', numel(problems));
    fprintf(' M 列表      : [%s]\n', num2str(M_list));
    fprintf(' D / N / maxFE : %d / %d / %d\n', D, N, maxFE);
    fprintf(' 每问题运行  : %d\n', n_run);
    fprintf(' 总运行次数  : %d\n', total);
    fprintf(' 随机种子    : %s\n', ternary(reproducible,'固定 rng(runid)','shuffle'));
    fprintf(' 统计输出目录: %s\n', stat_dir);
    fprintf('========================================\n\n');

    %% ---- 主循环 ----
    idx = 0;
    t_all = tic;
    for pi = 1:numel(problems)
        prob = problems{pi};
        probname = func2str(prob);
        for mi = 1:numel(M_list)
            M = M_list(mi);
            for r = 1:n_run
                idx = idx + 1;
                if reproducible
                    rng(r);   % 固定种子：同 runid 可复现
                else
                    rng('shuffle');
                end
                fprintf('[%3d/%d] %-8s M=%2d run=%2d ... ', idx, total, probname, M, r);
                t0 = tic;
                try
                    % nargout=3 让 platemo 设 save=0（不弹图不存结果文件）
                    [~,~,~] = platemo('algorithm',@REMO_new2_AdaMaO_Stat, ...
                        'problem',prob, ...
                        'M',M, 'D',D, 'maxFE',maxFE, 'N',N, ...
                        'run',r, 'outputFcn',silent);
                    fprintf('done (%6.1fs)\n', toc(t0));
                catch err
                    fprintf('FAILED: %s\n', err.message);
                end
            end
        end
    end

    fprintf('\n========================================\n');
    fprintf(' 全部完成，耗时 %.1f 分钟\n', toc(t_all)/60);
    fprintf(' 统计 .mat 文件目录: %s\n', stat_dir);
    fprintf('========================================\n');
    fprintf('下一步：运行 >> collect_mode_stat  生成 CSV 汇总表\n');
end

%% ---- 默认问题列表 ----
function probs = default_problems()
    probs = {@DTLZ1,@DTLZ2,@DTLZ3,@DTLZ4,@DTLZ5,@DTLZ6,@DTLZ7, ...
             @WFG1,@WFG2,@WFG3,@WFG4,@WFG5,@WFG6,@WFG7,@WFG8,@WFG9};
end

%% ---- 简易三元 ----
function s = ternary(cond,a,b)
    if cond; s = a; else; s = b; end
end
