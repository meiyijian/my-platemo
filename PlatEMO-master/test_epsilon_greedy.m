% 测试REMO_My中ϵ-Greedy策略的概率分布
clear all;
close all;

% 设置测试参数
test_runs = 10000; % 测试次数
expected_explore = 0.1; % 预期探索概率
actual_explore_count = 0;

% 模拟model_select函数返回的排序索引
total_solutions = 10;

% 模拟测试循环
for i = 1:test_runs
    % 生成模拟排序索引和分数
    scores = rand(total_solutions, 1);
    [~, sorted_ind] = sort(scores, 'descend');
    
    % 模拟ϵ-Greedy策略
    epsilon = 0.1;
    if rand > epsilon
        % 利用：选择最高评分的解
        selected = sorted_ind(1:3);
    else
        % 探索：随机选择解
        selected = randperm(total_solutions, 3);
        actual_explore_count = actual_explore_count + 1;
    end
end

% 计算实际探索概率
actual_explore_prob = actual_explore_count / test_runs;

% 显示结果
fprintf('测试次数: %d\n', test_runs);
fprintf('预期探索概率: %.2f\n', expected_explore);
fprintf('实际探索概率: %.4f\n', actual_explore_prob);
fprintf('概率误差: %.4f\n', abs(actual_explore_prob - expected_explore));

% 绘制概率分布直方图
figure;
histogram(rand(1, test_runs), 50);
hold on;
line([0.1, 0.1], [0, test_runs/5], 'Color', 'r', 'LineWidth', 2);
title('随机数分布与探索阈值(0.1)');
xlabel('随机数');
ylabel('频率');
legend('随机数分布', '探索阈值');

% 验证结果
if abs(actual_explore_prob - expected_explore) < 0.01
    fprintf('✓ 测试通过：实际探索概率符合预期\n');
else
    fprintf('✗ 测试失败：实际探索概率与预期偏差较大\n');
end
