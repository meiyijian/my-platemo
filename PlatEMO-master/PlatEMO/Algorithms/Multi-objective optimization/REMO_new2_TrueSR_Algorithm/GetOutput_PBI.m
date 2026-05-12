function [Output,r] = GetOutput_PBI(varargin)
% 使用 PBI（基于惩罚的边界交叉）方法判断每个解是否在参考向量的"好区域"内
%
% 核心思想：
%   对于每个参考点（Ref），沿着连接原点和该参考点的方向，检查哪些解
%   投影到这个方向上后距离参考点"不太远"。距离由 PBI 公式计算：
%       g = d1 + delta * d2
%   其中 d1 是沿参考方向的投影距离，d2 是垂直偏离距离。
%   如果 g > k（参考点到原点的距离），说明该解超出了参考点，标记为 false（不好）。
%
% 输入参数（可变参数）：
%   方式1: GetOutput_PBI(Pop, Ref)
%          - 自适应模式，自动搜索合适的 delta 值
%   方式2: GetOutput_PBI(Pop, Ref, delta)
%          - 手动模式，使用用户指定的 delta 值
%   Pop  : 种群目标值矩阵，每一行是一个解的多个目标函数值
%   Ref  : 参考点目标值矩阵，每一行是一个参考点的多个目标函数值
%   delta: PBI 公式中的惩罚参数，控制对偏离参考方向的容忍度
%
% 输出参数：
%   Output: 逻辑列向量，true 表示该解是"好解"（在约束区域内）
%   r     : 自适应模式下找到的"好解比例"（rate），用于诊断

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 默认开启自适应模式
    selfadapt = true;

    % nargin 表示传入的参数个数
    % 如果传入了 3 个参数（Pop, Ref, delta），则使用手动模式
    if nargin == 3
        selfadapt = false;
        delt      = varargin{3};  % varargin{3} 是第三个参数，即 delta
    end

    % 提取传入的种群和参考点
    Pop = varargin{1};
    Ref = varargin{2};

    if selfadapt
        % ==================== 自适应模式 ====================
        % 使用二分查找法自动搜索合适的 delta 值
        % 目标是让"好解"的比例在 30% 到 70% 之间
        %
        % 为什么需要自适应？
        % - delta 太大会导致只有极少数解被标记为"好"
        % - delta 太小会导致几乎所有解都被标记为"好"
        % - 合适的好解比例（30%-70%）能保证训练数据有足够的信息量

        delt_l = -20;  % delta 搜索下界
        delt_u = 20;   % delta 搜索上界
        r = 0;         % r 初始化为 0，确保进入 while 循环

        % 二分查找：不断调整 delt，直到好解比例落在 [0.3, 0.7] 区间内
        while r > 0.7 || r < 0.3
            delt_c = (delt_l + delt_u) / 2;  % 取中点作为当前尝试的 delta

            % 如果搜索区间已经足够小（< 0.1），停止搜索
            if abs(delt_l - delt_u) < 1e-1
                break;
            end

            % 用当前 delta 对数据进行分类，得到好解比例 r
            [l, r] = split_data(Pop, Ref, delt_c);

            % 根据好解比例调整搜索区间
            if r > 0.7
                % 好解太多 → 增大 delta（使标准更严格）→ 搜索右半区间
                delt_l = delt_c;
            elseif r < 0.3
                % 好解太少 → 减小 delta（使标准更宽松）→ 搜索左半区间
                delt_u = delt_c;
            end
        end
    else
        % ==================== 手动模式 ====================
        % 直接使用用户指定的 delta 值进行分类
        [l, ~] = split_data(Pop, Ref, delt);
    end

    % 返回分类结果
    Output = l;
end

function [Output, rate] = split_data(Pop, Ref, delt)
% 根据给定的 delta 值，判断每个解属于哪个参考向量的"好区域"
%
% 关键变量说明：
%   w      : 从原点到参考点的方向向量
%   W      : w 的单位向量
%   normP  : 每个解到原点的距离
%   normR  : 参考点到原点的距离（即 k）
%   CosineP: 解与参考方向的夹角余弦值
%   g      : PBI 聚合值 = d1 + delta*d2 （经典 PBI 公式）
%   k      : 参考点到原点的距离
%
% 判断标准：g <= k 表示解在参考点的"好区域"内

    N      = size(Pop, 1);          % 种群中的解的数量
    popind = 1:N;                   % 解的索引列表 [1, 2, 3, ..., N]
    Output = true(N, 1);            % 初始假设所有解都是"好解"

    % 将每个解分配给"最近"的参考点（用余弦相似度度量）
    % pdist2(..., 'cosine') 计算 1 - 余弦相似度，所以 1 - 这个值 = 余弦相似度
    % max(..., [], 2) 对每一行取最大值，得到每个解最匹配的参考点索引
    [~, ref_index] = max(1 - pdist2(Pop, Ref, 'cosine'), [], 2);

    % Z 是理想点：所有目标在当前种群中的最小值
    % min(Pop, [], 1) 对每一列（每个目标维度）取最小值
    Z = min(Pop, [], 1);

    % 遍历每个参考点
    for i = 1:size(Ref, 1)
        % 找到分配给当前参考点 i 的所有解
        sub_pop    = Pop(ref_index == i, :);     % 这些解的目标值
        sub_popind = popind(ref_index == i);     % 这些解的原始索引

        % BOUND 是当前参考点的坐标
        BOUND = Ref(i, :);

        % ===== PBI 计算 =====
        % w: 从理想点 Z 到参考点 BOUND 的方向向量
        w = BOUND - Z;

        % W: w 的单位向量（方向不变，长度归一化为 1）
        W = w ./ sqrt(sum(w.^2, 2));

        % normW: W 的长度（=1，因为已归一化）
        normW = sqrt(sum(W.^2, 2));

        % normP: 每个解相对于理想点 Z 的欧氏距离
        % repmat(Z, ...) 把 Z 复制多行，使矩阵维度匹配以进行减法
        normP = sqrt(sum((sub_pop - repmat(Z, size(sub_pop, 1), 1)).^2, 2));

        % normR: 参考点相对于理想点 Z 的距离（即 k）
        normR = sqrt(sum((BOUND - Z).^2, 2));

        % CosineP: 解向量与参考方向 W 之间夹角的余弦值
        % 计算公式：cos(theta) = (A·B) / (|A| * |B|)
        % 分子是点积（逐元素相乘再求和），分母是模长的乘积
        % -1e-6 是避免数值误差导致余弦值略大于 1 的小修正
        CosineP = (sum((sub_pop - repmat(Z, size(sub_pop, 1), 1)) .* ...
                    repmat(W, size(sub_pop, 1), 1), 2) ./ normW ./ normP) - 1e-6;

        % g: PBI 聚合函数值
        %   d1 = normP * cos(theta)：沿参考方向的投影距离
        %   d2 = normP * sin(theta)：垂直于参考方向的偏离距离
        %   sin(theta) = sqrt(1 - cos^2(theta))
        %   g = d1 + delta * d2
        g = normP .* CosineP + delt * normP .* sqrt(1 - CosineP.^2);

        % k: 参考点到理想点的距离
        k = normR;

        % 归一化：g/k > 1 表示该解的投影超出了参考点
        g = g ./ k;

        % 将超出参考点的解标记为"不好"
        Output(sub_popind(g > 1)) = false;
    end

    % rate: "好解"占总体的比例
    rate = sum(Output == 1) / length(Output);
end
