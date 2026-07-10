function run_classic_subset(varargin)
% run_classic_subset - 精选 8 个经典问题跑 AdaMaO 模式占比统计
%
% 从 DTLZ1-7 选 4 个、WFG1-9 选 4 个，覆盖不同的 PF 形状特性，
% 确保每类模式（curriculum/weighted/indicator/explore/conservative）
% 都有典型代表问题被触发，从而全面观察 AdaMaO 的模式切换行为。
%
% === DTLZ 精选（4/7）===
%   DTLZ1 - 线性PF + g函数高度多模态，收敛极难，模型预测误差偏大
%           → curriculum（误差大时过滤低置信样本）的典型代表
%   DTLZ2 - 凹球形PF，最标准平滑基准，模型易学、精度好、coverage正常
%           → conservative 主导，作为对照 baseline
%   DTLZ4 - DTLZ2 基础上加偏置参数，解在PF上分布极不均匀，退化度高
%           → indicator（退化高时用指标重排序）的典型代表
%   DTLZ7 - 不连续/断开PF，多个不连通前沿段，退化高 + coverage低
%           → explore/indicator 混合（断开PF是AdaMaO重点场景）
%
% === WFG 精选（4/9）===
%   WFG3  - 除第一目标外线性相关，PF退化为低维
%           → indicator 的极端场景（退化度极高）
%   WFG4  - 凹PF + 多峰 deceptive，全面困难的常用基准
%           → curriculum/indicator 混合（误差大+退化）
%   WFG6  - 非凸 + 不连续PF
%           → explore 触发（coverage低），与DTLZ7呼应
%   WFG9  - 凹 + deceptive + 不连续 + 参数相关，WFG中最难
%           → 压力测试，模式分布最丰富
%
% 用法（在 MATLAB 命令行）：
%   >> cd '...\REMO_new2_AdaMaO\notes\mode_stat'
%   >> run_classic_subset              % 默认：M=20, 3次, 跑完自动生成CSV
%   >> run_classic_subset('n_run',10)  % 补到10次
%   >> run_classic_subset('M_list',[10,20])  % 两个M都跑
%
% 可选参数（透传给 run_mode_stat）：
%   'M_list'      默认 [20]（与你已有数据对应；要M=10改为[10,20]）
%   'n_run'       默认 3（先看趋势，满意后改10）
%   'D','N','maxFE','reproducible'  同 run_mode_stat

    %% ---- 确保脚本目录在路径上 ----
    this_dir = fileparts(mfilename('fullpath'));
    if ~isempty(this_dir); addpath(this_dir); end

    %% ---- 默认配置 ----
    p = inputParser;
    addParameter(p,'M_list',[20]);
    addParameter(p,'D',30);
    addParameter(p,'N',100);
    addParameter(p,'maxFE',300);
    addParameter(p,'n_run',3);
    addParameter(p,'reproducible',false);
    parse(p,varargin{:});

    %% ---- 精选问题列表 ----
    problems = {@DTLZ1,@DTLZ2,@DTLZ4,@DTLZ7, ...
                @WFG3,@WFG4,@WFG6,@WFG9};

    fprintf('==========================================================\n');
    fprintf(' AdaMaO 模式占比统计 — 精选 8 问题子集\n');
    fprintf('==========================================================\n');
    fprintf(' DTLZ (4): DTLZ1 DTLZ2 DTLZ4 DTLZ7\n');
    fprintf(' WFG  (4): WFG3  WFG4  WFG6  WFG9\n');
    fprintf(' 选择原因：覆盖 curriculum/weighted/indicator/explore/conservative\n');
    fprintf('           各类模式的典型触发场景\n');
    fprintf('==========================================================\n\n');

    %% ---- 运行实验 ----
    run_mode_stat( ...
        'problems',    problems, ...
        'M_list',      p.Results.M_list, ...
        'D',           p.Results.D, ...
        'N',           p.Results.N, ...
        'maxFE',       p.Results.maxFE, ...
        'n_run',       p.Results.n_run, ...
        'reproducible',p.Results.reproducible);

    %% ---- 自动生成 CSV ----
    fprintf('\n>>> 实验完成，开始生成 CSV 汇总 ...\n');
    collect_mode_stat;

    fprintf('\n==========================================================\n');
    fprintf(' 全部完成！\n');
    fprintf(' CSV 文件：.../notes/mode_stat/mode_distribution.csv\n');
    fprintf('==========================================================\n');
end
