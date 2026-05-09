%% HybridPartition.m
% 结合 REMO 与 PCSAEA 的优劣划分方法，可视化一致好/一致坏/分歧区域，
% 并绘制种群的帕累托前沿。
% 需要 PlatEMO 环境支持。

clear; clc; close all;

%% 添加 PlatEMO 路径（根据你的实际安装位置修改）
% 如果已经运行过 platemo 初始化，可以注释掉下面两行
% platemoPath = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO'; % 替换为你的路径
% addpath(genpath(platemoPath));

%% 设置问题参数
% 这里以 2 目标 ZDT1 为例，可根据需要修改
Problem = DTLZ1();           % 创建问题对象
N = 200;                    % 种群大小
D = Problem.D;              % 决策变量维数
M = Problem.M;              % 目标维数

% 生成随机种群（决策变量在边界内均匀分布）
PopDec = rand(N, D) .* (Problem.upper - Problem.lower) + Problem.lower;
Population = Problem.Evaluation(PopDec);   % 真实评估
PopObj = Population.objs;                  % 目标矩阵

%% 1. REMO 划分
k = 6;  % 参考解个数（与 REMO 默认一致）
Ref = RefSelect(Population, k);            % 选择参考解
RefObj = Ref.objs;
% 计算每个解相对于参考解的 PBI 类别（好=true, 坏=false）
REMO_good = GetOutput_PBI(PopObj, RefObj); % 返回逻辑列向量
REMO_bad  = ~REMO_good;

%% 2. PCSAEA 划分（基于适应度排序）
% 计算适应度（参考 CalFitnessPC 中的逻辑，但直接对整个种群排序）
% 归一化目标值到 [0,1]
Zmin = min(PopObj, [], 1);
Zmax = max(PopObj, [], 1);
PopObj_norm = (PopObj - Zmin) ./ (Zmax - Zmin);
PopObj_norm(isnan(PopObj_norm)) = 0;   % 处理常数值目标

% 计算 SDE 多样性指标（用于 D 值）
Npop = size(PopObj_norm, 1);
SDE = zeros(Npop, 1);
for i = 1:Npop
    SPopuObj = PopObj_norm;
    Temp = repmat(PopObj_norm(i,:), Npop, 1);
    Shifted = PopObj_norm < Temp;
    SPopuObj(Shifted) = Temp(Shifted);
    Distance = pdist2(PopObj_norm(i,:), SPopuObj);
    [~, idx] = sort(Distance);
    Dk = Distance(idx(floor(sqrt(Npop)) + 1));
    SDE(i) = 2 / (Dk + 2);
end

% 计算 Pareto 支配关系
Dominate = false(Npop);
for i = 1:Npop-1
    for j = i+1:Npop
        k = any(PopObj_norm(i,:) < PopObj_norm(j,:)) - any(PopObj_norm(i,:) > PopObj_norm(j,:));
        if k == 1
            Dominate(i,j) = true;
        elseif k == -1
            Dominate(j,i) = true;
        end
    end
end
S = sum(Dominate, 2);                       % 被支配数
R = zeros(1, Npop);
for i = 1:Npop
    R(i) = sum(S(Dominate(:,i)));           % 强度值
end

% 计算余弦距离（多样性）
Dist = pdist2(PopObj_norm, PopObj_norm, 'cosine');
Dist(logical(eye(Npop))) = inf;
Dist = sort(Dist, 2);
D_cos = 1 ./ (Dist(:, floor(sqrt(Npop))) + 2);

% 归一化 R 到 [0,1]
if max(R) > min(R)
    R_norm = (R - min(R)) / (max(R) - min(R));
else
    R_norm = zeros(1, Npop);
end

% 组合适应度（rate 取 0.5，代表中间进化阶段，可调整）
rate = 0.5;
Fitness = rate * R_norm' + (1-rate) * D_cos;

% 排序并取前 25% 为好解，后 25% 为坏解
[~, sortIdx] = sort(Fitness);
good25 = sortIdx(1:ceil(Npop/4));
bad25  = sortIdx(end-ceil(Npop/4)+1:end);

PCSAEA_good = false(Npop,1);
PCSAEA_bad  = false(Npop,1);
PCSAEA_good(good25) = true;
PCSAEA_bad(bad25)   = true;

%% 3. 混合划分：一致好、一致坏、分歧
both_good = REMO_good & PCSAEA_good;      % 两种方法一致认为好
both_bad  = REMO_bad  & PCSAEA_bad;       % 两种方法一致认为坏
conflict1 = REMO_good & PCSAEA_bad;       % REMO好 vs PCSAEA坏
conflict2 = REMO_bad  & PCSAEA_good;      % REMO坏 vs PCSAEA好
disagreement = conflict1 | conflict2;     % 所有分歧

% 统计信息
fprintf('种群大小: %d\n', N);
fprintf('REMO好解数: %d, REMO坏解数: %d\n', sum(REMO_good), sum(REMO_bad));
fprintf('PCSAEA好解数: %d, PCSAEA坏解数: %d\n', sum(PCSAEA_good), sum(PCSAEA_bad));
fprintf('一致好解数: %d\n', sum(both_good));
fprintf('一致坏解数: %d\n', sum(both_bad));
fprintf('分歧解数: %d\n', sum(disagreement));
fprintf('  其中 REMO好/PCSAEA坏: %d\n', sum(conflict1));
fprintf('  其中 REMO坏/PCSAEA好: %d\n', sum(conflict2));

%% 4. 可视化
% 找出 Pareto 前沿（非支配解）
FrontNo = NDSort(PopObj, 1);   % 1 表示只返回第一前沿
ParetoIdx = (FrontNo == 1);
ParetoObj = PopObj(ParetoIdx, :);

% 绘制目标空间散点图（前两维）
if M >= 2
    figure;
    hold on;
    % 绘制所有解（灰色小点）
    h_all = plot(PopObj(:,1), PopObj(:,2), 'k.', 'MarkerSize', 6, 'DisplayName', '所有解');
    % 绘制一致好解（绿色）
    if any(both_good)
        h_good = plot(PopObj(both_good,1), PopObj(both_good,2), 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'DisplayName', '一致好');
    else
        h_good = plot(nan, nan, 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'DisplayName', '一致好');
    end
    % 绘制一致坏解（红色）
    if any(both_bad)
        h_bad = plot(PopObj(both_bad,1), PopObj(both_bad,2), 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', '一致坏');
    else
        h_bad = plot(nan, nan, 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', '一致坏');
    end
    % 绘制 REMO好/PCSAEA坏（蓝色方块）
    if any(conflict1)
        h_c1 = plot(PopObj(conflict1,1), PopObj(conflict1,2), 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'DisplayName', 'REMO好/PCSAEA坏');
    else
        h_c1 = plot(nan, nan, 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'b', 'DisplayName', 'REMO好/PCSAEA坏');
    end
    % 绘制 REMO坏/PCSAEA好（品红菱形）
    if any(conflict2)
        h_c2 = plot(PopObj(conflict2,1), PopObj(conflict2,2), 'md', 'MarkerSize', 8, 'MarkerFaceColor', 'm', 'DisplayName', 'REMO坏/PCSAEA好');
    else
        h_c2 = plot(nan, nan, 'md', 'MarkerSize', 8, 'MarkerFaceColor', 'm', 'DisplayName', 'REMO坏/PCSAEA好');
    end
    % 绘制 Pareto 前沿（黑色连线）
    if ~isempty(ParetoObj)
        % 按第一目标排序，以便连线
        ParetoObj_sorted = sortrows(ParetoObj, 1);
        h_pareto = plot(ParetoObj_sorted(:,1), ParetoObj_sorted(:,2), 'k-', 'LineWidth', 2, 'DisplayName', 'Pareto前沿');
    else
        h_pareto = plot(nan, nan, 'k-', 'LineWidth', 2, 'DisplayName', 'Pareto前沿');
    end
    xlabel('f1'); ylabel('f2');
    title('混合划分结果 (REMO vs PCSAEA)');
    legend([h_all, h_good, h_bad, h_c1, h_c2, h_pareto], 'Location', 'best');
    grid on;
    hold off;
else
    warning('目标维数小于2，无法绘制2D散点图。');
end

% 如果目标维数大于2，可添加平行坐标图
if M > 2
    figure;
    % 为每个解分配类别编号
    class = zeros(N, 1);
    class(both_good)   = 1;
    class(both_bad)    = 2;
    class(conflict1)   = 3;
    class(conflict2)   = 4;
    % 绘制平行坐标图，按类别分组
    parallelcoords(PopObj, 'Group', class, 'Labels', arrayfun(@(x) sprintf('f%d',x),1:M,'UniformOutput',false));
    title('混合划分 (平行坐标)');
    colormap([0 1 0; 1 0 0; 0 0 1; 1 0 1]);  % 绿,红,蓝,品红
    legend({'一致好','一致坏','REMO好/PCSAEA坏','REMO坏/PCSAEA好'}, 'Location', 'eastoutside');
end