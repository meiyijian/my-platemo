function score = computeEHVI(CandObj, RefObj, RefPoint)
% <DR_SAEA helper> Expected Hypervolume Improvement for K=2.
%
%   For a 2-dimensional reduced objective space, compute the exact closed-
%   form hypervolume improvement that each candidate brings over the
%   current Pareto front. Returns a column vector of length size(CandObj,1).
%
%   Call:
%       score = computeEHVI(CandObj, RefObj, RefPoint)
%
%   Input:
%       CandObj  - Nq x 2 candidate reduced objectives (Mu from the surrogate)
%       RefObj   - Nf x 2 current non-dominated front in the reduced space
%       RefPoint - 1 x 2 reference point for the hypervolume (e.g. 1.1*max)
%
%   Output:
%       score    - Nq x 1, the exact hypervolume improvement of each candidate
%                  over (RefObj, RefPoint) when used as a deterministic point.
%                  Note: this is the HV improvement, not the expected HV
%                  improvement, since the surrogate is treated as a point
%                  estimate inside the infill criterion. This matches the
%                  practical use in DR_SAEA: balancing convergence (low
%                  objective) and uncertainty (sigma) is handled by the
%                  balanced acquisition directly, while the "EHVI" name
%                  preserves the canonical literature reference.
%
%   命名说明：函数名为 computeEHVI 系沿用文献习惯，但当前实现是
%   "确定性 HV 改善量 (HVI)"，而非对高斯后验做积分的 Expected HVI。
%   当 SurrogateType='Kriging' 且仅用预测均值 Mu 作为点估计时，
%   计算结果与 Hupkens 2013 的 2D 闭式 EHVI 在均值点估计下数值一致。
%   若需要真正的 EHVI（高斯积分），需额外传入 Sigma 并做数值积分。
%
%   This function is part of the DR_SAEA algorithm.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026. You are free to use DR_SAEA for research purposes.
%--------------------------------------------------------------------------

    if size(CandObj, 2) ~= 2
        score = zeros(size(CandObj, 1), 1);
        return;
    end
    if isempty(RefObj)
        RefObj = RefPoint;
    end
    if isempty(RefPoint)
        RefPoint = max(RefObj, [], 1) * 1.1 + 0.1;
    end

    % Clip the reference front to be inside the dominated region only
    F = RefObj(all(RefObj < repmat(RefPoint, size(RefObj, 1), 1), 2), :);
    if isempty(F)
        F = RefPoint;
    end

    Nq = size(CandObj, 1);
    score = zeros(Nq, 1);
    % ---- 对每个候选点，用有序前沿扫描计算精确的 2D HV 贡献量 ----
    % 原理: 将前沿按 f1 升序排列后，HV = Σ (ref1 - fi1) × (prev_f2 - fi2)，
    % 其中 prev_f2 是前一个点的 f2（首个点的 prev_f2 = ref2）。
    % 点 p 的贡献 = HV(F∪{p}) - HV(F)，等价于矩形 [p, RefPoint] 中尚未
    % 被 F 支配的面积。
    %
    % 实现要点（避免 O(N log N) 每候选的重计算）：
    %   1) 在 f1=p1 处的前沿天花板 init_ceil = min{ f2 | f1 ≤ p1, f < ref }
    %   2) 从 p1 向 ref1 扫描，每遇到一个降低天花板的点，计算该段内
    %      已被 F 覆盖的面积（高度 = ref2 - max(ceil, p2)）
    for i = 1 : Nq
        p = CandObj(i, :);
        % 点在参考点之外 → 贡献为 0
        if any(p >= RefPoint)
            score(i) = 0;
            continue;
        end
        % 完整矩形面积：p 支配的区域 [p1,ref1] × [p2,ref2]
        base = (RefPoint(1) - p(1)) * (RefPoint(2) - p(2));
        if isempty(F)
            score(i) = base;
            continue;
        end

        % ---- 计算矩形内已被 F 覆盖的面积 --------------------------------
        % 1. 计算在 f1 = p(1) 处，F 设定的天花板高度。
        %    天花板 = ref2 与所有 f1 ≤ p1 的前沿点 f2 的最小值。
        initCeil = RefPoint(2);
        for j = 1 : size(F, 1)
            if F(j, 1) <= p(1) && F(j, 2) < initCeil
                initCeil = F(j, 2);
            end
        end

        % 2. 沿 f1 轴从 p(1) 向 RefPoint(1) 扫描，逐段累加被覆盖面积
        covered     = 0;
        curCeil     = initCeil;   % 当前扫描段的 f2 天花板
        prevF1      = p(1);       % 上一段的 f1 坐标

        % 只关心 f1 在 (p1, ref1) 之间、且 f2 < ref2 的点
        scanMask = F(:, 1) > p(1) & F(:, 1) < RefPoint(1) ...
                 & F(:, 2) < RefPoint(2);
        Fscan = F(scanMask, :);
        % 按 f1 升序以确保扫描顺序正确
        Fscan = sortrows(Fscan, 1);

        for j = 1 : size(Fscan, 1)
            f = Fscan(j, :);
            % 该点未降低天花板 → 不需更新段
            if f(2) >= curCeil
                continue;
            end
            % 计算本段宽度及覆盖面积（高度 = ref2 到天花板中较高者）
            segW = f(1) - prevF1;
            if segW > 0
                effCeil = max(curCeil, p(2));               % 天花板不低于 p2
                if effCeil < RefPoint(2)
                    covered = covered + segW * (RefPoint(2) - effCeil);
                end
            end
            curCeil = f(2);
            prevF1  = f(1);
        end

        % 3. 最后一段：[prevF1, RefPoint(1)]
        segW = RefPoint(1) - prevF1;
        if segW > 0
            effCeil = max(curCeil, p(2));
            if effCeil < RefPoint(2)
                covered = covered + segW * (RefPoint(2) - effCeil);
            end
        end

        score(i) = max(base - covered, 0);
    end
end
