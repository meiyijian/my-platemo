% 对比 REMO 与 PCSAEA 的种群划分
% 需要先运行 PlatEMO 初始化，或在 PlatEMO 目录下执行此脚本

clear; clc;

% 设置问题参数（以 2 目标 ZDT1 为例，决策变量维数可调）
Problem = ZDT1();                % 创建问题对象
N = 100;                          % 种群大小
D = Problem.D;                    % 决策变量维数
M = Problem.M;                    % 目标维数

% 随机生成初始种群（决策变量在边界内均匀分布）
PopDec = rand(N, D) .* (Problem.upper - Problem.lower) + Problem.lower;
Population = Problem.Evaluation(PopDec);   % 真实评估得到目标值

% 提取目标矩阵
PopObj = Population.objs;

%% 1. REMO 的划分
% 选择参考解（k = 6，与 REMO 默认一致）
k = 6;
Ref = RefSelect(Population, k);          % 返回 INDIVIDUAL 对象数组
RefObj = Ref.objs;

% 计算每个解的类别（好解 = 1，坏解 = 0）
Catalog = GetOutput_PBI(PopObj, RefObj);   % Catalog 为逻辑列向量
REMO_good = Catalog;                        % 好解索引
REMO_bad  = ~Catalog;                        % 坏解索引

%% 2. PCSAEA 的划分（基于适应度排序）
% 计算适应度（使用 CalFitnessPC 中的组合适应度）
% 需要归一化目标值
Zmin = min(PopObj, [], 1);
Zmax = max(PopObj, [], 1);
PopObj_norm = (PopObj - Zmin) ./ (Zmax - Zmin);

% 计算 SDE（多样性）部分（简化，直接调用 CalFitnessPC 中的 SDE 计算）
% 这里我们复用 CalFitnessPC 的一部分逻辑，但不执行样本选择
N = size(PopObj_norm, 1);
SDE = zeros(N, 1);
for i = 1:N
    SPopuObj = PopObj_norm;
    Temp = repmat(PopObj_norm(i,:), N, 1);
    Shifted = PopObj_norm < Temp;
    SPopuObj(Shifted) = Temp(Shifted);
    Distance = pdist2(real(PopObj_norm(i,:)), real(SPopuObj));
    [~, index] = sort(Distance, 2);
    Dk = Distance(index(floor(sqrt(N)) + 1));
    SDE(i) = 2 / (Dk + 2);
end

% 计算支配关系（用于 R 值）
Dominate = false(N);
for i = 1:N-1
    for j = i+1:N
        k = any(PopObj_norm(i,:) < PopObj_norm(j,:)) - any(PopObj_norm(i,:) > PopObj_norm(j,:));
        if k == 1
            Dominate(i,j) = true;
        elseif k == -1
            Dominate(j,i) = true;
        end
    end
end
S = sum(Dominate, 2);
R = zeros(1,N);
for i = 1:N
    R(i) = sum(S(Dominate(:,i)));
end

% 计算余弦距离（多样性）
Distance = pdist2(real(PopObj_norm), real(PopObj_norm), 'cosine');
Distance(logical(eye(N))) = inf;
Distance = sort(Distance, 2);
D_cos = 1 ./ (Distance(:, floor(sqrt(N))) + 2);

% 归一化 R 到 [0,1]
Rmin = min(R); Rmax = max(R);
if Rmax > Rmin
    R_norm = (R - Rmin) / (Rmax - Rmin);
else
    R_norm = zeros(1,N);
end

% 组合适应度（rate = 当前进化进度，这里用固定 0.5 作为示例）
rate = 0.5;   % 可根据实际 FE 比例调整
Fitness = rate * R_norm' + (1-rate) * D_cos;

% 排序并划分前 25% 为好解，后 25% 为坏解
[~, sortIdx] = sort(Fitness);
good25 = sortIdx(1:ceil(N/4));
bad25  = sortIdx(end-ceil(N/4)+1:end);

PCSAEA_good = false(N,1);
PCSAEA_bad  = false(N,1);
PCSAEA_good(good25) = true;
PCSAEA_bad(bad25) = true;

%% 3. 对比两种划分
% 计算重合部分
both_good = REMO_good & PCSAEA_good;   % 两种方法都认为好
both_bad  = REMO_bad  & PCSAEA_bad;    % 两种方法都认为坏
conflict1 = REMO_good & PCSAEA_bad;    % REMO好 vs PCSAEA坏
conflict2 = REMO_bad  & PCSAEA_good;   % REMO坏 vs PCSAEA好

% 输出统计
fprintf('种群大小: %d\n', N);
fprintf('REMO好解数: %d, REMO坏解数: %d\n', sum(REMO_good), sum(REMO_bad));
fprintf('PCSAEA好解数: %d, PCSAEA坏解数: %d\n', sum(PCSAEA_good), sum(PCSAEA_bad));
fprintf('两种方法一致的好解数: %d\n', sum(both_good));
fprintf('两种方法一致的坏解数: %d\n', sum(both_bad));
fprintf('冲突 (REMO好 vs PCSAEA坏): %d\n', sum(conflict1));
fprintf('冲突 (REMO坏 vs PCSAEA好): %d\n', sum(conflict2));

%% 4. 可视化（在目标空间的前两维）
if M >= 2
    figure;
    hold on;
    % 绘制所有解（灰色小点）
    plot(PopObj(:,1), PopObj(:,2), 'k.', 'MarkerSize', 5);
    % 标记一致的好解（绿色）
    plot(PopObj(both_good,1), PopObj(both_good,2), 'g^', 'MarkerSize', 8, 'MarkerFaceColor', 'g');
    % 标记一致的坏解（红色）
    plot(PopObj(both_bad,1), PopObj(both_bad,2), 'rv', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
    % 标记冲突1（REMO好 vs PCSAEA坏）：蓝色方块
    plot(PopObj(conflict1,1), PopObj(conflict1,2), 'bs', 'MarkerSize', 8, 'MarkerFaceColor', 'b');
    % 标记冲突2（REMO坏 vs PCSAEA好）：黄色菱形
    plot(PopObj(conflict2,1), PopObj(conflict2,2), 'md', 'MarkerSize', 8, 'MarkerFaceColor', 'm');
    xlabel('f1'); ylabel('f2');
    title('REMO vs PCSAEA 划分对比');
    legend('所有解', '一致好解', '一致坏解', 'REMO好/PCSAEA坏', 'REMO坏/PCSAEA好', 'Location', 'best');
    grid on;
    hold off;
else
    warning('目标维数小于2，无法绘制2D散点图。');
end

%% 5. 如需在更高维可视化，可以使用平行坐标图
if M > 2
    figure;
    % 将类别转换为数值用于颜色映射
    class = zeros(N,1);
    class(both_good)   = 1;   % 一致好
    class(both_bad)    = 2;   % 一致坏
    class(conflict1)   = 3;   % REMO好/PCSAEA坏
    class(conflict2)   = 4;   % REMO坏/PCSAEA好
    % 绘制平行坐标图
    parallelcoords(PopObj, 'Group', class, 'Labels', arrayfun(@(x) sprintf('f%d',x),1:M,'UniformOutput',false));
    title('REMO vs PCSAEA 划分 (平行坐标)');
    colormap([0 1 0; 1 0 0; 0 0 1; 1 0 1]);  % 绿红蓝品红
    legend({'一致好','一致坏','REMO好/PCSAEA坏','REMO坏/PCSAEA好'}, 'Location', 'eastoutside');
end