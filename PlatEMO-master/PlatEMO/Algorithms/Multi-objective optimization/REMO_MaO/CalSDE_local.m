function SDE = CalSDE_local(PopObj)
% CalSDE_local - 移位密度估计（Shift-based Density Estimation）
%
% 衡量解的多样性 + 收敛性：值越大代表解越优秀（远离他解的"阴影"）
% 在超多目标场景下作为 NDSort 的有效补充。
%
% 引用：
%   M. Li, S. Yang, and X. Liu, "Shift-based density estimation for
%   Pareto-based algorithms in many-objective optimization," IEEE TEVC, 2014.
%
% 复制并简化自 DSR_REMO/CalSDE.m，避免跨目录依赖。

    N = size(PopObj, 1);
    if N <= 1
        SDE = zeros(N, 1);
        return;
    end

    % 归一化（避免量纲影响）
    Zmin = min(PopObj, [], 1);
    Zmax = max(PopObj, [], 1);
    range = Zmax - Zmin;
    range(range == 0) = 1;
    PopObj = (PopObj - repmat(Zmin, N, 1)) ./ repmat(range, N, 1);

    SDE = zeros(N, 1);
    k   = floor(sqrt(N)) + 1;
    if k > N
        k = N;
    end

    for i = 1 : N
        % 把所有他解的"较差维度"上移至 i 解的位置（移位）
        SPopuObj = PopObj;
        Temp     = repmat(PopObj(i, :), N, 1);
        Shifted  = PopObj < Temp;
        SPopuObj(Shifted) = Temp(Shifted);

        % 计算 i 到所有移位后他解的距离
        Distance = pdist2(real(PopObj(i, :)), real(SPopuObj));
        [~, idx] = sort(Distance, 2);
        Dk = Distance(idx(k));

        % SDE = 2/(Dk+2)：Dk 越大表示 i 越孤立 → SDE 越小
        SDE(i) = 2 ./ (Dk + 2);
    end

    % 翻转使"越大越好"，便于后续融合
    SDE = -SDE;
end
