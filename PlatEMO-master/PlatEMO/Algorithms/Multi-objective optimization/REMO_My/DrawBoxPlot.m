%% --- 自动读取 PlatEMO 30次运行数据并画统计图 ---
clear; clc;

% ================= 配置区域 (请修改这里) =================
% 请把下面的路径换成你电脑上存放 .mat 文件的真实文件夹路径
% 文件夹1：原版 REMO 的数据
Path_REMO    = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Data\REMO'; 

% 文件夹2：你的 REMO_My 的数据
Path_REMO_My = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Data\REMO_My'; 

% 想要对比的指标名称 (必须与 .mat 文件里的变量名一致)
MetricName   = 'IGD'; 
% =======================================================

%% 1. 读取数据
Data_REMO    = ReadFromFolder(Path_REMO, MetricName);
Data_REMO_My = ReadFromFolder(Path_REMO_My, MetricName);

% 检查数据是否读取成功
if isempty(Data_REMO) || isempty(Data_REMO_My)
    error('读取失败！请检查文件夹路径是否正确，以及文件夹里是否有 .mat 文件。');
end

%% 2. 绘制箱线图 (Box Plot)
figure('Color', 'w', 'Position', [300, 300, 500, 400]);

% 把数据合并成矩阵 (假设都是30次)
% 如果次数不一样，需要截取
MinRuns = min(length(Data_REMO), length(Data_REMO_My));
PlotData = [Data_REMO(1:MinRuns), Data_REMO_My(1:MinRuns)];

% 画图
boxplot(PlotData, {'REMO', 'REMO-My'}, 'Width', 0.5);

% 美化图形
ylabel(MetricName, 'FontSize', 12, 'FontWeight', 'bold');
title(['Statistical Comparison on ', num2str(MinRuns), ' Runs'], 'FontSize', 12);
grid on;
set(gca, 'FontSize', 11, 'LineWidth', 1.2);

% 加上散点 (Jitter Points) 展示真实分布
hold on;
x_jitter1 = 1 + (rand(size(Data_REMO))-0.5)*0.1;
x_jitter2 = 2 + (rand(size(Data_REMO_My))-0.5)*0.1;
scatter(x_jitter1, Data_REMO, 20, 'k', 'filled', 'MarkerFaceAlpha', 0.3);
scatter(x_jitter2, Data_REMO_My, 20, 'r', 'filled', 'MarkerFaceAlpha', 0.3);
hold off;

%% 3. 自动计算显著性检验 (Rank Sum Test)
% p < 0.05 意味着显著不同
[p, h] = ranksum(Data_REMO, Data_REMO_My);

fprintf('========================================\n');
fprintf('统计结果对比 (越小越好):\n');
fprintf('REMO     平均值: %.4e (标准差: %.4e)\n', mean(Data_REMO), std(Data_REMO));
fprintf('REMO-My  平均值: %.4e (标准差: %.4e)\n', mean(Data_REMO_My), std(Data_REMO_My));
fprintf('----------------------------------------\n');
if p < 0.05
    if mean(Data_REMO_My) < mean(Data_REMO)
        fprintf('结论: REMO-My 【显著优于】 REMO (p = %.4e)\n', p);
    else
        fprintf('结论: REMO-My 显著差于 REMO\n');
    end
else
    fprintf('结论: 两者无显著差异 (平手) (p = %.4f)\n', p);
end
fprintf('========================================\n');


%% --- 内部读取函数 ---
function Data = ReadFromFolder(FolderPath, MetricName)
    Files = dir(fullfile(FolderPath, '*.mat'));
    Data = [];
    if isempty(Files)
        warning(['在文件夹中找不到 .mat 文件: ', FolderPath]);
        return;
    end
    
    fprintf('正在读取文件夹: %s ...\n', FolderPath);
    for i = 1:length(Files)
        FilePath = fullfile(FolderPath, Files(i).name);
        try
            Content = load(FilePath);
            % 尝试获取 metric 结构体
            if isfield(Content, 'metric') && isfield(Content.metric, MetricName)
                Val = Content.metric.(MetricName);
                Data = [Data; Val];
            elseif isfield(Content, MetricName) % 有些版本直接存变量
                Val = Content.(MetricName);
                Data = [Data; Val];
            end
        catch
            warning(['文件损坏或格式不对: ', Files(i).name]);
        end
    end
end