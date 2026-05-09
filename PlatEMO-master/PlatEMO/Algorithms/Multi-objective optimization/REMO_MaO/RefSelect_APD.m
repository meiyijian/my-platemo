function Ref = RefSelect_APD(Population, N)
% RefSelect_APD - 环境选择：t-DEA 鲁棒归一化 + RVEA APD niching
%
% 输入：
%   Population : 候选种群（含 Archive 全部解或合并解）
%   N          : 选择数量
%
% 输出：
%   Ref : 选出的 N 个解
%
% 设计要点（替代原雷达图 RefSelect）：
%   1. t-DEA 风格归一化：基于 ASF + 超平面截距，比简单 min-max 更鲁棒
%      避免极端解（异常值）扭曲整个尺度
%   2. NDSort 取前若干层（与原版一致）
%   3. 末层用 RVEA APD niching 替代雷达图的 2D 投影：
%      - 与参考向量关联
%      - 每个参考向量内按 APD 取最优
%      - 不足 N 个时按 APD 全局补齐
%
% 借鉴源：
%   - t-DEA/Normalization.m（ASF+超平面截距）
%   - RVEA/EnvironmentalSelection.m（APD + 关联）

    PopObj = Population.objs;
    [Np, M] = size(PopObj);

    if Np <= N
        Ref = Population;
        return;
    end

    %% 1. NDSort 分层
    [FrontNo, MaxFNo] = NDSort(PopObj, N);
    Next = FrontNo < MaxFNo;
    LastFront = find(FrontNo == MaxFNo);

    %% 2. 鲁棒归一化（t-DEA 风格 ASF + 超平面截距）
    PopObj_n = robustNormalize(PopObj);

    %% 3. 末层用 RVEA APD niching 选剩余
    nNeed = N - sum(Next);
    if nNeed <= 0
        Ref = Population(Next);
        return;
    end

    %% 生成参考向量（与种群规模匹配）
    [V, ~] = UniformPoint(N, M);
    V = V ./ vecnorm(V, 2, 2);

    LastObj = PopObj_n(LastFront, :);
    nLast   = size(LastObj, 1);

    %% 计算 LastFront 中每个解的 APD
    cosV = 1 - pdist2(V, V, 'cosine');
    cosV(logical(eye(size(cosV, 1)))) = 0;
    gamma = min(acos(max(min(cosV, 1), -1)), [], 2);
    gamma(gamma < 1e-6) = 1e-6;

    Angle = acos(max(min(1 - pdist2(LastObj, V, 'cosine'), 1), -1));
    [Ang_min, assoc] = min(Angle, [], 2);

    Norm_F  = sqrt(sum(LastObj .^ 2, 2));
    APD = (1 + M * 0.5 * Ang_min ./ gamma(assoc)) .* Norm_F;

    %% 每个参考向量取 APD 最小的解
    Selected = false(nLast, 1);
    UV = unique(assoc)';
    for v = UV
        cur = find(assoc == v);
        [~, b] = min(APD(cur));
        Selected(cur(b)) = true;
    end

    %% 不足 nNeed 时按 APD 全局补齐；超过则按 APD 截断
    nSel = sum(Selected);
    if nSel < nNeed
        remain = find(~Selected);
        [~, ord] = sort(APD(remain));
        nFill = nNeed - nSel;
        Selected(remain(ord(1 : nFill))) = true;
    elseif nSel > nNeed
        sel_idx = find(Selected);
        [~, ord] = sort(APD(sel_idx));
        Selected = false(nLast, 1);
        Selected(sel_idx(ord(1 : nNeed))) = true;
    end

    %% 合并
    Next(LastFront(Selected)) = true;
    Ref = Population(Next);
end


function PopObj_n = robustNormalize(PopObj)
% 基于 ASF + 超平面截距的鲁棒归一化（t-DEA 风格）
    [N, M] = size(PopObj);
    z = min(PopObj, [], 1);
    znad_init = max(PopObj, [], 1);

    % 寻找极值点
    W_extr = zeros(M) + 1e-6;
    W_extr(logical(eye(M))) = 1;
    ASF = zeros(N, M);
    range_init = max(znad_init - z, 1e-6);
    for i = 1 : M
        ASF(:, i) = max(abs((PopObj - repmat(z, N, 1)) ./ repmat(range_init, N, 1)) ...
                        ./ repmat(W_extr(i, :), N, 1), [], 2);
    end
    [~, extreme] = min(ASF, [], 1);

    % 计算超平面截距
    try
        Hyperplane = (PopObj(extreme, :) - repmat(z, M, 1)) \ ones(M, 1);
        a = (1 ./ Hyperplane)' + z;
    catch
        a = znad_init;
    end
    if any(isnan(a)) || any(a <= z)
        a = znad_init;
    end

    range = max(a - z, 1e-6);
    PopObj_n = (PopObj - repmat(z, N, 1)) ./ repmat(range, N, 1);
end
