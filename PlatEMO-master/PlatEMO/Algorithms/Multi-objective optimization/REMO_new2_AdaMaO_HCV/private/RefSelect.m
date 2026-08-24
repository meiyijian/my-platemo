function Ref = RefSelect(Population,k,wCon)
% RefSelect - 参考解选择（RSEA 策略：Radar grid based Selection Evolutionary Algorithm）
%
% 可选第三个输入 wCon 控制 LastSelection 中收敛项的权重模式：
%   'legacy'（默认）: fitness = 0.1*M*Con - min(RDis)，与原始 RSEA 完全一致
%   'scaled'        : fitness = 0.1*M/max(1,M/3)*Con - min(RDis)，即把系数固定在
%                     低维时的有效量级。动机见下方缺陷说明；该模式为独立可选因子，
%                     默认不启用，以便把它与互补 PBI 的贡献分开测量。
%
% 已定位缺陷（M>=10 时多样性项失效）：
%   LastSelection 的 fitness = 0.1*M*Con(current) - min(RDis(current,Choose))
%   其中 Con 已按 Con./max(Con) 归一到 [0,1]；而 RLoc 经 (RLoc+1)/2 落入单位圆盘，
%   故 RDis <= 1（解析上界即圆盘直径）。于是收敛项的幅度为 0.1*M、多样性项 <= 1：
%       M=3  -> 0.3 vs <=1   多样性项可翻盘
%       M=10 -> 1.0 vs <=1   临界
%       M=20 -> 2.0 vs <=1   收敛项以 2:1 压制，多样性项无法改变 argmin
%   因此在 M>=10 时 LastSelection 近似退化为"在最稀疏网格内取归一化目标和最小者"，
%   仅剩网格计数 CrowdG 提供粗多样性，而网格数只有 ceil(sqrt(k))^2（M=20 时 36 格）。
%
% 从种群中选出 k 个代表解，用于：
% 1. HPC 内部的 PBI 标签计算（k=6）
% 2. 主流程末尾的环境选择（k=Problem.N）
%
% RSEA 策略的核心思想：
%   使用雷达网格将高维目标空间映射到 2D，然后在网格中选择代表性解
%
% 选择标准：
%   1. 自动保留最后一层之前的较优前沿，并额外标记一个靠近全目标均衡方向的代表解
%   2. 优先从当前二维雷达投影中占用较少的网格选择
%   3. 在候选网格中，综合归一化目标和与二维投影距离选择
%
% 输入:
%   Population - 种群对象
%   k          - 需要选出的解数量
% 输出:
%   Ref        - 选出的 k 个解

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    if nargin < 3 || isempty(wCon)
        wCon = 'legacy';
    end

    % k 不能超过种群规模
    k      = min(k,length(Population));
    PopObj = Population.objs;  % N x M 目标值矩阵

    %% ============ 非支配排序 ============
    % 取前若干前沿，直到累计已排序解数达到 k
    [FrontNO,MaxFNO] = NDSort(PopObj,k);
    Next = find(FrontNO<=MaxFNO);  % 保留的解索引

    %% ============ 目标值归一化到 [0,1] ============
    Pmin = min(PopObj,[],1) + 1e-6;  % 加小常数避免除零
    Pmax = max(PopObj,[],1);
    if Pmax > Pmin
        PopObj = (PopObj-repmat(Pmin,size(PopObj,1),1))./repmat(Pmax-Pmin,size(PopObj,1),1);
    end

    %% ============ 环境选择 ============
    % div = ceil(sqrt(k)) 用于雷达网格的分辨率
    Choose = LastSelection(PopObj(Next,:),ismember(Next,find(FrontNO<MaxFNO)),ceil(sqrt(k)),k,wCon);
    Ref    = Population(Next(Choose));
end
%% ============ 内部函数：基于雷达网格的环境选择 ============
function Choose = LastSelection(PopObj,Choose,div,k,wCon)
% LastSelection - 基于雷达网格策略选择 k 个解
%
% 输入:
%   PopObj  - 归一化后的目标值
%   Choose  - 逻辑向量，已自动保留的较优前沿解
%   div     - 网格分辨率
%   k       - 需要选出的总数

    %% ---- 识别全目标均衡方向代表解 ----
    % 选择到 (1,1,...,1) 对角方向垂直距离最小的一个解。
    % 该解通常靠近全目标均衡方向，不是按各目标分别选择的 PF 边界极端点。
    [~,Extreme] = min(sqrt(sum(PopObj.^2,2)).* ...
        sqrt(1-(1-pdist2(PopObj,ones(1,size(PopObj,2)),'cosine')).^2),[],1);
    Choose = Choose | ismember(1:size(PopObj,1),Extreme);

    %% ---- 计算收敛性 ----
    % 收敛性 = 到原点的距离（归一化后），越小越好
    Con = sum(PopObj.^1,2).^1;
    Con = Con./max(Con);

    %% ---- 计算雷达网格 ----
    % 将 M 维目标空间映射到 2 维雷达坐标
    [Site,RLoc] = RadarGrid(PopObj,div);
    % 计算各解二维雷达投影坐标之间的距离；RLoc 不是网格中心坐标
    RDis        = pdist2(RLoc,RLoc);
    RDis(logical(eye(length(RDis)))) = inf;  % 对角线设为无穷

    % 统计每个网格中的已选解数量
    CrowdG      = zeros(1,max(Site));
    temp        = tabulate(Site(Choose));
    CrowdG(temp(:,1)) = temp(:,2);

    %% ---- 迭代选择直到选满 k 个 ----
    while sum(Choose) < k
        % 找到最稀疏的网格
        remainS  = find(~Choose);           % 未选中的解
        remainG  = unique(Site(remainS));   % 未选中解所在的网格
        bestG    = CrowdG(remainG) == min(CrowdG(remainG));  % 最稀疏的网格
        current  = remainS(ismember(Site(remainS),remainG(bestG)));

        % 适应度 = wc*归一化目标和 - 与已选解的最小二维投影距离
        % legacy: wc = 0.1*M（原始 RSEA）；scaled: 把 wc 钳制在低维有效量级
        M  = size(PopObj,2);
        wc = 0.1.*M;
        if strcmpi(wCon,'scaled')
            wc = 0.1.*M./max(1,M/3);
        end
        fitness  = wc.*Con(current) - min(RDis(current,Choose),[],2);
        [~,best] = min(fitness);

        % 选中并更新网格计数
        Choose(current(best))       = true;
        CrowdG(Site(current(best))) = CrowdG(Site(current(best))) + 1;
    end
end

%% ============ 内部函数：雷达网格映射 ============
function [Site,RLoc] = RadarGrid(P,div)
% RadarGrid - 将 M 维目标空间映射到 2 维雷达坐标，并划分网格
%
% 输入:
%   P   - N x M 归一化目标值
%   div - 网格分辨率
% 输出:
%   Site - N x 1 每个解所属的网格编号
%   RLoc - 每个解的 2D 雷达投影坐标

    [N,M] = size(P);

    %% ---- 计算雷达坐标 ----
    % theta: M 个等间隔角度
    theta     = 0 : 2*pi/M : 2*pi/M*(M-1);
    % 防御：某解归一化后各目标之和为 0（例如恰为理想点）时，原实现得到 0/0 = NaN，
    % 该 NaN 会经 min/max 污染整个 YL/YU。此处把零分母置 1，使该解落到原点。
    denom     = sum(P,2);
    denom(abs(denom) < 1e-12) = 1;
    % x 坐标 = 目标值加权余弦和 / 目标值和
    RLoc(:,1) = sum(P.*repmat(cos(theta),N,1),2)./denom;
    % y 坐标 = 目标值加权正弦和 / 目标值和
    RLoc(:,2) = sum(P.*repmat(sin(theta),N,1),2)./denom;
    % 映射到 [0,1]
    RLoc      = (RLoc+1)/2;

    %% ---- 归一化到 [0,1] ----
    YL        = min(RLoc,[],1);                             % 下界
    YU        = max(RLoc,[],1);                             % 上界
    % 防御：雷达投影完全退化（YU==YL，例如种群所有解相同）时，原实现会得到
    % NRLoc = 0/0 = NaN，进而 Site 全为 0，最终在 CrowdG(0) 处抛出
    % MATLAB:badsubscript。此处把零展度维置 0，语义为"全部落入同一网格"。
    % 该保护只在原实现会崩溃的输入上生效，非退化输入的行为逐位不变。
    span      = YU - YL;
    span(span <= 0) = 1;
    NRLoc     = (RLoc-repmat(YL,N,1))./repmat(span,N,1);   % 归一化

    %% ---- 划分网格 ----
    % 将 [0,1] 均匀划分为 div x div 网格
    GLoc            = floor(NRLoc.*div);
    GLoc(GLoc>=div) = div - 1;  % 边界处理

    % 唯一网格编号
    UniqueGLoc      = sortrows(unique(GLoc,'rows'));
    [~,Site]        = ismember(GLoc,UniqueGLoc,'rows');
end
