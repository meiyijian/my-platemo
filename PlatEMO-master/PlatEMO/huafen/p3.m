%% ImprovedPartition_fixed.m
% 改进的综合得分策略（修正维度问题）
clear; clc; close all;

% 添加 PlatEMO 路径
platemoPath = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO'; % 请替换
addpath(genpath(platemoPath));

% 设置问题
Problem = DTLZ1();
N = 200;
PopDec = rand(N, Problem.D) .* (Problem.upper - Problem.lower) + Problem.lower;
Population = Problem.Evaluation(PopDec);
PopObj = Population.objs;

% 非支配前沿
FrontNo = NDSort(PopObj, 1);
isPareto = (FrontNo == 1);

% 收敛性指标（到理想点距离）
Zmin = min(PopObj, [], 1);
Convergence = sqrt(sum((PopObj - Zmin).^2, 2));
Convergence = Convergence / max(Convergence);

% 多样性指标
Diversity = zeros(N, 1);
if sum(isPareto) > 1
    Crowd = CrowdingDistance(PopObj(isPareto, :));
    if max(Crowd) > min(Crowd)
        Crowd_norm = (Crowd - min(Crowd)) / (max(Crowd) - min(Crowd));
    else
        Crowd_norm = zeros(size(Crowd));
    end
    Diversity(isPareto) = Crowd_norm;
end
Diversity(~isPareto) = 0.1;

% 综合得分（乘积形式）
Score = (1 - Convergence) .* (1 + Diversity);

% 好解选择
good_candidates = find(isPareto);
[~, idx] = sort(Score(good_candidates), 'descend');
good_num = ceil(N / 4);

if length(good_candidates) >= good_num
    good_idx = good_candidates(idx(1:good_num));
else
    good_idx = good_candidates(:);  % 强制列向量
    remaining = setdiff(1:N, good_idx);
    if ~isempty(remaining)
        [~, remIdx] = sort(Convergence(remaining));
        need = good_num - length(good_idx);
        add = remaining(remIdx(1:min(need, length(remIdx))));
        add = add(:);  % 强制列向量
        good_idx = [good_idx; add];
    end
end

% 坏解选择
remaining_all = setdiff(1:N, good_idx);
[~, badIdx] = sort(Convergence(remaining_all), 'descend');
bad_num = good_num;
bad_idx = remaining_all(badIdx(1:min(bad_num, length(badIdx))));

% 确保 good_idx 和 bad_idx 为列向量
good_idx = good_idx(:);
bad_idx = bad_idx(:);

% 中间解
middle_idx = setdiff(1:N, [good_idx; bad_idx]);

% 可视化
figure;
hold on;
plot(PopObj(:,1), PopObj(:,2), 'k.', 'MarkerSize', 6, 'DisplayName', '所有解');
plot(PopObj(good_idx,1), PopObj(good_idx,2), 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g', 'DisplayName', '好解');
plot(PopObj(bad_idx,1), PopObj(bad_idx,2), 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'DisplayName', '坏解');
plot(PopObj(middle_idx,1), PopObj(middle_idx,2), 'bs', 'MarkerSize', 6, 'MarkerFaceColor', 'b', 'DisplayName', '中间解');
ParetoObj = PopObj(isPareto, :);
if ~isempty(ParetoObj)
    ParetoObj_sorted = sortrows(ParetoObj, 1);
    plot(ParetoObj_sorted(:,1), ParetoObj_sorted(:,2), 'k-', 'LineWidth', 2, 'DisplayName', 'Pareto前沿');
end
xlabel('f1'); ylabel('f2');
title('改进划分结果');
legend('Location', 'best');
grid on;
hold off;

fprintf('种群大小: %d\n', N);
fprintf('Pareto解数量: %d\n', sum(isPareto));
fprintf('好解数量: %d\n', length(good_idx));
fprintf('坏解数量: %d\n', length(bad_idx));
fprintf('中间解数量: %d\n', length(middle_idx));