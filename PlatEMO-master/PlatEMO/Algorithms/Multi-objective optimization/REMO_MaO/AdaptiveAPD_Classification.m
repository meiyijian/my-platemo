function [Catalog, Ref] = AdaptiveAPD_Classification(Population, ratio, Nref, k)
% AdaptiveAPD_Classification - 基于 RVEA APD + SDE 的自适应二元分类
%
% 输入：
%   Population : 当前种群（PlatEMO Solution 数组）
%   ratio      : 进化比例（FE / maxFE，∈ [0,1]）
%   Nref       : 参考向量数量（一般取 N）
%   k          : 参考解数量（用于代理辅助选择）
%
% 输出：
%   Catalog : N×1 logical，true=好解，false=差解
%             好解和差解各 ⌈N/4⌉，中间 N/2 解默认归为差类（不强行抛弃）
%   Ref     : 参考解集合（按融合得分前 k 个）
%
% 设计要点（针对超多目标 M=5~20 的改进）：
%   1. 用 RVEA APD 替代 PBI，避免 θ=5 在高维下淹没 d1
%        APD = (1 + θ_t * Angle/γ) * ||F-Z||
%        θ_t = (FE/maxFE)^2 * M    自适应；早期 θ_t≈0 偏收敛，后期偏多样性
%   2. 参考向量直接用 UniformPoint NBI，避免 K-means 在高维退化
%   3. 用 SDE 提供超多目标多样性信号，弥补 NDSort 失效
%   4. 标签直接二元，与 BinaryRelationPairs/onehotconv2 一致
%
% 借鉴源：
%   - RVEA/EnvironmentalSelection.m（APD 计算）
%   - SPEA2+SDE/CalFitness.m（SDE 思想）

    N = length(Population);
    M = size(Population(1).obj, 2);
    PopObj = Population.objs;

    %% 1. 生成参考向量（NBI 模式，对 M≤20 有较好覆盖）
    [V, ~] = UniformPoint(Nref, M);
    V = V ./ vecnorm(V, 2, 2);   % 归一化为单位向量

    %% 2. 计算 RVEA APD
    Zmin = min(PopObj, [], 1);
    PopObj_t = PopObj - repmat(Zmin, N, 1);   % 平移到原点

    % 参考向量两两最小夹角 γ（用于 APD 中的尺度归一）
    cosV = 1 - pdist2(V, V, 'cosine');
    cosV(logical(eye(size(cosV, 1)))) = 0;
    gamma = min(acos(max(min(cosV, 1), -1)), [], 2);
    gamma(gamma < 1e-6) = 1e-6;

    % 每个解关联到夹角最小的参考向量
    Angle = acos(max(min(1 - pdist2(PopObj_t, V, 'cosine'), 1), -1));
    [Ang_min, assoc] = min(Angle, [], 2);

    % 自适应 θ_t：早期偏收敛、后期偏多样性
    theta_t = (ratio ^ 2) * M;

    % APD = (1 + θ_t * Angle/γ) * ||F-Z||
    Norm_F  = sqrt(sum(PopObj_t .^ 2, 2));
    APD = (1 + theta_t * Ang_min ./ gamma(assoc)) .* Norm_F;

    %% 3. 计算 SDE（多样性信号）
    SDE = CalSDE_local(PopObj);   % 越大越好

    %% 4. 融合得分（APD 越小越好，所以取负）
    score_apd = -APD;
    score_sde = SDE;
    % 归一化到 [0,1] 后融合
    score_apd_n = norm01(score_apd);
    score_sde_n = norm01(score_sde);
    score_final = score_apd_n + 0.3 * score_sde_n;

    %% 5. 划分好/差
    [~, idx_sorted] = sort(score_final, 'descend');
    good_num = ceil(N / 4);

    Catalog = false(N, 1);
    Catalog(idx_sorted(1 : good_num)) = true;   % 前 N/4 为好

    %% 6. 选参考解：融合得分最高的 k 个
    k = min(k, N);
    Ref = Population(idx_sorted(1 : k));
end

function s = norm01(x)
    a = min(x);
    b = max(x);
    if b - a < 1e-12
        s = ones(size(x)) * 0.5;
    else
        s = (x - a) / (b - a);
    end
end
