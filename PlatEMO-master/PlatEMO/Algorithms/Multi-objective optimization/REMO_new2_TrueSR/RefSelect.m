function Ref = RefSelect(Population, k)
% 从种群中选择 k 个有代表性的参考解（基于 RSEA 策略）
%
% RSEA = Radar-grid based Selection in Environmental selection Algorithm
% 即"基于雷达网格的环境选择算法"
%
% 核心思路：
%   参考解的选择需要兼顾"收敛性"（靠近真实帕累托前沿）和
%   "多样性"（在前沿上均匀分布）。本函数分两步实现：
%
%   步骤1（NDSort + 归一化）：
%     用非支配排序选出前沿层，同时将目标值归一化以消除尺度差异
%
%   步骤2（LastSelection——雷达网格选择）：
%     - 将目标空间映射到二维雷达坐标（角度编码）
%     - 在雷达坐标上划分网格
%     - 优先从稀疏的网格中选择解，同时偏向收敛性好的解
%     - 这保证了选出的参考解既有代表性又多样化
%
% 输入参数：
%   Population: 待选择种群对象（包含多个解，每个解有目标值）
%   k         : 需要选出的参考解数量
%
% 输出参数：
%   Ref: 选出的 k 个参考解（种群对象）

    % 确保 k 不超过种群中的解数量
    k = min(k, length(Population));

    % 提取所有解的目标函数值矩阵
    PopObj = Population.objs;

    % ===== 步骤1：非支配排序，选出前 k 个前沿层的解 =====
    % NDSort(PopObj, k) 返回：
    %   FrontNO：每个解属于第几层前沿
    %   MaxFNO ：包含前 k 个解所需的最大前沿层编号
    % 例如：第1前沿有30个解，第2前沿有20个，k=25 → MaxFNO=1（只取第1前沿就够了）
    [FrontNO, MaxFNO] = NDSort(PopObj, k);

    % Next：属于前 MaxFNO 层的所有解的索引
    Next = find(FrontNO <= MaxFNO);

    % ===== 步骤2：目标值归一化 =====
    % 在计算距离和角度前，将各目标值缩放到 [0,1] 区间
    % 否则目标尺度差异会扭曲距离计算
    Pmin  = min(PopObj, [], 1) + 1e-6;   % 各目标的最小值（+1e-6 防止除以 0）
    Pmax  = max(PopObj, [], 1);           % 各目标的最大值

    range = Pmax - Pmin;                   % 各目标的范围
    valid = range > 0;                     % 有效目标（范围 > 0 的目标维度）

    if any(valid)
        % 对有效维度做 Min-Max 归一化：(x - min) / (max - min)
        % repmat 将向量复制多行，使矩阵维度匹配
        PopObj(:, valid) = (PopObj(:, valid) - repmat(Pmin(valid), size(PopObj, 1), 1)) ./ ...
                          repmat(range(valid), size(PopObj, 1), 1);
    end

    % ===== 步骤3：雷达网格选择 =====
    % 从归一化后的候选解中选出 k 个最有代表性的解
    % ismember(Next, find(FrontNO < MaxFNO))：
    %   标记 Next 中那些来自"更靠前的前沿层"的解（这些解天然更有优势，优先保留）
    % ceil(sqrt(k))：网格划分参数 div（网格密度）
    Choose = LastSelection(PopObj(Next, :), ...
        ismember(Next, find(FrontNO < MaxFNO)), ceil(sqrt(k)), k);

    % 返回选中的参考解
    Ref = Population(Next(Choose));
end

function Choose = LastSelection(PopObj, Choose, div, k)
% 基于雷达网格的最后一轮选择：选出精确的 k 个解
%
% 输入：
%   PopObj : 归一化后的目标值矩阵
%   Choose : 已预设的选择标记（前沿层更靠前的解已预先标记为选中）
%   div    : 网格密度（即每个维度分成几格）
%   k      : 最终需要选出的解数量
%
% 输出：
%   Choose : 经过增量选择后的逻辑标记向量

    % ===== 步骤A：选择极值解 =====
    % 极值解是在某些目标上表现最优的解（有助于保持多样性）
    % 公式分析：
    %   sqrt(sum(PopObj.^2, 2))：每个解到原点的距离
    %   1 - pdist2(..., 'cosine')：每个解与各坐标轴的余弦相似度
    %   整体：在靠近各坐标轴的方向上选距离原点最近的解
    [~, Extreme] = min(sqrt(sum(PopObj.^2, 2)) .* ...
        sqrt(1 - (1 - pdist2(PopObj, ones(1, size(PopObj, 2)), 'cosine')).^2), [], 1);
    % 将极值解标记为已选中
    Choose = Choose | ismember(1:size(PopObj, 1), Extreme);

    % ===== 步骤B：计算收敛性指标 =====
    % Con：各解的目标值和，越小表示收敛性越好（更靠近原点）
    Con = sum(PopObj, 2);
    if max(Con) > 0
        Con = Con ./ max(Con);  % 归一化到 [0,1]
    end

    % ===== 步骤C：构建雷达网格 =====
    % 将目标空间映射到二维雷达坐标，并划分网格
    [Site, RLoc] = RadarGrid(PopObj, div);

    % 计算所有网格中心点之间的距离矩阵
    RDis = pdist2(RLoc, RLoc);
    RDis(logical(eye(length(RDis)))) = inf;  % 对角设无穷（自己到自己的距离不考虑）

    % CrowdG：每个网格中已选中解的数量（拥挤度）
    CrowdG = zeros(1, max(Site));

    % 统计每个网格中已选中解的数量
    temp = tabulate(Site(Choose));
    CrowdG(temp(:, 1)) = temp(:, 2);

    % ===== 步骤D：增量选择，直到选满 k 个 =====
    while sum(Choose) < k
        % 找出还未被选中的解的索引
        remainS = find(~Choose);

        % 找出未选中解所在的网格
        remainG = unique(Site(remainS));

        % 找到最稀疏的网格（已选解最少的网格）
        % 优先从稀疏网格中选解 → 保证多样性
        bestG = CrowdG(remainG) == min(CrowdG(remainG));

        % 从最稀疏网格中筛选候选解
        current = remainS(ismember(Site(remainS), remainG(bestG)));

        % fitness：综合评分，越低越好选中
        %   第一项 0.1*M*Con(current)：收敛性得分（小目标值和优先）
        %   第二项 -min(RDis(current, Choose), [], 2)：
        %       距"离最近已选解的距离"越远越好（越远，-距离越小，
        %       即 min 值越小越优先，保持多样性）
        %   σ=0.1 是为了平衡收敛性和多样性的权重
        fitness = 0.1 .* size(PopObj, 2) .* Con(current) - min(RDis(current, Choose), [], 2);

        % 选 fitness 最小的（综合得分最高的）
        [~, best] = min(fitness);
        Choose(current(best)) = true;

        % 更新该网格的拥挤度计数
        CrowdG(Site(current(best))) = CrowdG(Site(current(best))) + 1;
    end
end

function [Site, RLoc] = RadarGrid(P, div)
% 将目标空间中的解映射到二维雷达坐标，并划分网格
%
% 雷达坐标映射原理：
%   类似于雷达扫描显示，将多维目标向量投影到二维极坐标上
%   步骤：
%     1. 将目标向量归一化为和为 1 的方向
%     2. 计算该方向与各坐标轴夹角余弦/正弦的加权和
%     3. 映射到 [0,1]² 的二维坐标中
%     4. 在二维坐标上划分网格
%
% 输入：
%   P   : 目标值矩阵（N 行 × M 列）
%   div : 每个维度划分的网格数
%
% 输出：
%   Site : 每个解所属的网格编号
%   RLoc : 所有非空网格的中心坐标

    [N, M] = size(P);  % N=解的数量, M=目标个数

    % ===== 步骤1：计算雷达坐标映射的角度 =====
    % 在 0 到 2π 之间均匀取 M 个角度（对应 M 个目标维度）
    theta = 0 : 2*pi/M : 2*pi/M*(M-1);

    % ===== 步骤2：将解映射到二维雷达坐标 =====
    % denom：每个解的目标值之和（用于归一化）
    denom = sum(P, 2);
    denom(denom == 0) = eps;  % 防止除以 0（eps 是最小正浮点数）

    % RLoc(:,1) = Σ (P(:,m) * cos(theta_m)) / Σ P
    %   将每个目标维度投影到 x 轴方向，按目标值加权平均
    RLoc(:, 1) = sum(P .* repmat(cos(theta), N, 1), 2) ./ denom;

    % RLoc(:,2) = Σ (P(:,m) * sin(theta_m)) / Σ P
    %   将每个目标维度投影到 y 轴方向，按目标值加权平均
    RLoc(:, 2) = sum(P .* repmat(sin(theta), N, 1), 2) ./ denom;

    % 将雷达坐标从 [-1,1] 映射到 [0,1]
    RLoc = (RLoc + 1) / 2;

    % ===== 步骤3：网格划分 =====
    % 对所有解的雷达坐标做归一化（缩放到 [0,1]）
    YL    = min(RLoc, [], 1);     % x,y 坐标的最小值
    YU    = max(RLoc, [], 1);     % x,y 坐标的最大值
    range = YU - YL;              % x,y 坐标的范围
    range(range == 0) = 1;        % 防止除以 0
    NRLoc = (RLoc - repmat(YL, N, 1)) ./ repmat(range, N, 1);  % 归一化到 [0,1]

    % 将连续坐标离散化为网格索引
    % floor(NRLoc * div)：坐标 × div，向下取整，得到网格的行列号
    GLoc = floor(NRLoc .* div);
    GLoc(GLoc >= div) = div - 1;  % 确保不超过 div-1

    % 找出所有非空的网格
    UniqueGLoc = sortrows(unique(GLoc, 'rows'));

    % 把每个解分配到对应的网格（Site 是网格编号）
    [~, Site] = ismember(GLoc, UniqueGLoc, 'rows');
end
