%% HybridPartition_Weighted.m
% 综合得分策略：结合 REMO 的 PBI 分类得分和 PCSAEA 的归一化适应度排名，
% 按加权综合得分排序，取前 25% 为“好”，后 25% 为“坏”，其余为中间。
% 需要 PlatEMO 环境支持。

clear; clc; close all;



%% 设置问题参数
Problem = DTLZ1();           % 可选择其他问题，如 DTLZ2
N = 200;                    % 种群大小
D = Problem.D;
M = Problem.M;

% 生成随机种群
PopDec = rand(N, D) .* (Problem.upper - Problem.lower) + Problem.lower;
Population = Problem.Evaluation(PopDec);
PopObj = Population.objs;

%% 1. 计算 REMO 的 PBI 分类得分（好=1，坏=0）
k = 6;
Ref = RefSelect(Population, k);            % 选择参考解
RefObj = Ref.objs;
REMO_good = GetOutput_PBI(PopObj, RefObj); % 逻辑列向量，好=true
PBI_score = double(REMO_good);              % 好=1，坏=0

%% 2. 计算 PCSAEA 的适应度排名（归一化适应度，排名越前得分越高）
% 归一化目标值
Zmin = min(PopObj, [], 1);
Zmax = max(PopObj, [], 1);
PopObj_norm = (PopObj - Zmin) ./ (Zmax - Zmin);
PopObj_norm(isnan(PopObj_norm)) = 0;

% 计算 SDE 多样性指标
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
S = sum(Dominate, 2);               % 被支配数
R = zeros(1, Npop);
for i = 1:Npop
    R(i) = sum(S(Dominate(:,i)));   % 强度值
end

% 计算余弦距离
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

% 组合适应度（rate=0.5，可根据需要调整）
rate = 0.5;
Fitness = rate * R_norm' + (1-rate) * D_cos;

% 将适应度转换为排名得分（排名越前得分越高）
[~, sortIdx] = sort(Fitness, 'descend');   % 适应度越大越好
rank_score = zeros(Npop, 1);
rank_score(sortIdx) = (1:Npop)';            % 排名：1 最好，N 最差
% 归一化排名得分到 [0,1]，使得最好得分为1，最差为0
norm_rank = 1 - (rank_score - 1) / (Npop - 1);  % 归一化：1（最好）~ 0（最差）

%% 3. 计算综合得分
w1 = 0.5;   % PBI 分类得分的权重（可根据偏好调整）
w2 = 0.5;   % 归一化排名得分的权重
Composite_score = w1 * PBI_score + w2 * norm_rank;

%% 4. 按综合得分排序，取前 25% 为“好”，后 25% 为“坏”
[~, compIdx] = sort(Composite_score, 'descend');
good_num = ceil(Npop / 4);
bad_num  = good_num;
good_idx = compIdx(1:good_num);
bad_idx  = compIdx(end-bad_num+1:end);
middle_idx = setdiff(1:Npop, [good_idx; bad_idx]);

%% 5. 可视化
% 找出 Pareto 前沿
FrontNo = NDSort(PopObj, 1);
ParetoIdx = (FrontNo == 1);
ParetoObj = PopObj(ParetoIdx, :);

if M >= 2
    figure;
    hold on;
    % 绘制所有解（灰色小点）
    plot(PopObj(:,1), PopObj(:,2), 'k.', 'MarkerSize', 6, 'DisplayName', '所有解');
    % 绘制好解（绿色三角）
    if ~isempty(good_idx)
        plot(PopObj(good_idx,1), PopObj(good_idx,2), 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'DisplayName', '好解 (前25%)');
    end
    % 绘制坏解（红色倒三角）
    if ~isempty(bad_idx)
        plot(PopObj(bad_idx,1), PopObj(bad_idx,2), 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', '坏解 (后25%)');
    end
    % 绘制中间解（蓝色方块）
    if ~isempty(middle_idx)
        plot(PopObj(middle_idx,1), PopObj(middle_idx,2), 'bs', 'MarkerSize', 6, 'MarkerFaceColor', 'b', 'DisplayName', '中间解');
    end
    % 绘制 Pareto 前沿（黑色连线）
    if ~isempty(ParetoObj)
        ParetoObj_sorted = sortrows(ParetoObj, 1);
        plot(ParetoObj_sorted(:,1), ParetoObj_sorted(:,2), 'k-', 'LineWidth', 2, 'DisplayName', 'Pareto前沿');
    end
    xlabel('f1'); ylabel('f2');
    title(sprintf('综合得分划分 (w1=%.2f, w2=%.2f)', w1, w2));
    legend('Location', 'best');
    grid on;
    hold off;
else
    warning('目标维数小于2，无法绘制2D散点图。');
end

% 打印统计信息
fprintf('种群大小: %d\n', N);
fprintf('好解数量: %d (前25%%)\n', good_num);
fprintf('坏解数量: %d (后25%%)\n', bad_num);
fprintf('中间解数量: %d\n', length(middle_idx));