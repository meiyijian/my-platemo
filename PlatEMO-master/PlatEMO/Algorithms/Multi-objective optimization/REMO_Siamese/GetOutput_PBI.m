function [Output,r] = GetOutput_PBI(varargin)
% 基于PBI（Penalty-based Boundary Intersection，基于惩罚的边界交叉）方法
% 对解进行分类：将每个解标记为"好"(1)或"不好"(~1)
%
% 核心思想：以参考解为基准，在参考解附近的解被认为是"好"的，
% 远离参考解的被认为"不好"。PBI方法在分解多目标优化中常用。
%
% varargin{1} = Pop（所有解的目标值）
% varargin{2} = Ref（参考解的目标值）
% varargin{3} = delt（可选，手动指定PBI的惩罚参数）
% Output      = 分类结果（true=好，false=不好）
% r           = 好解所占的比例

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. All rights reserved.
%--------------------------------------------------------------------------

    selfadapt = true;  % 默认自适应调整
    if nargin == 3
        % 如果传入了3个参数，则使用用户指定的delt值，不自适应
        selfadapt = false;
        delt      = varargin{3};
    end

    Pop = varargin{1};  % 种群的目标值
    Ref = varargin{2};  % 参考解的目标值

    if selfadapt
        % 自适应模式：通过二分法找到合适的 delt 值
        % 使得好解的比例 r 在 0.3~0.7 之间（大约一半好一半不好）
        delt_l = -20;   % 搜索下界
        delt_u = 20;    % 搜索上界
        r = 0;           % 好解比例
        while r>0.7 || r<0.3
            delt_c = (delt_l + delt_u)/2;  % 二分取中间值
            if abs(delt_l-delt_u)<1e-1
                break;  % 搜索范围足够小就停止
            end
            [l,r] = split_data(Pop,Ref,delt_c);  % 用当前delt值分类
            if r > 0.7
                delt_l = delt_c;  % 好解太多，增大delt（扩大"好"区域）
            elseif r < 0.3
                delt_u = delt_c;  % 好解太少，减小delt（缩小"好"区域）
            end
        end
    else
        % 非自适应模式：直接用给定的delt值分类
        [l,~] = split_data(Pop,Ref,delt);
    end
    Output = l;  % 返回分类结果
end

function [Output,rate] = split_data(Pop,Ref,delt)
% 用PBI方法将解分为"好"和"不好"两类
%
% Pop  - 目标值矩阵，每行一个解
% Ref  - 参考解的目标值，每行一个参考解
% delt - 惩罚参数（控制好解区域的宽松程度）
% Output - 逻辑数组：true=好解（在参考解附近），false=不好解
% rate   - 好解所占的比例

    N      = size(Pop,1);     % 种群大小
    popind = 1 : N;            % 解的编号（用于索引）
    Output = true(N,1);        % 初始默认全部为好解

    % 余弦相似度：计算每个解与哪个参考解最相似（角度最近）
    % pdist2(...,'cosine') = 计算余弦距离，1-余弦距离=余弦相似度
    % ref_index = 每个解属于哪个参考解的"领地"
    [~,ref_index] = max(1-pdist2(Pop,Ref,'cosine'),[],2);

    Z = min(Pop,[],1);  % 理想点（每个目标上的最小值）

    % 对每个参考解，检查其"领地"内的解哪些是好的
    for i = 1 : size(Ref,1)
        % 找出属于当前参考解领地的所有解
        belong_idx = find(ref_index==i);

        % 如果没有解属于这个参考解，跳过
        if isempty(belong_idx)
            continue;
        end

        sub_pop    = Pop(belong_idx,:);           % 属于该参考解领地的所有解
        sub_popind = belong_idx;                   % 这些解的原始编号
        BOUND      = Ref(i,:);                     % 当前参考解的目标值

        % w = 从理想点到参考解的方向向量
        w = BOUND-Z;
        w_norm = sqrt(sum(w.^2,2));

        % 避免除以零
        if w_norm < 1e-10
            continue;
        end

        W = w./w_norm;  % 归一化方向向量（长度为1）

        % normW = 方向向量的长度（应该是1，因为归一化了）
        normW   = sqrt(sum(W.^2,2));
        % normP = 每个解到理想点的距离
        normP   = sqrt(sum((sub_pop - Z).^2, 2));
        % normR = 参考解到理想点的距离
        normR   = sqrt(sum((BOUND-Z).^2,2));

        % 避免除以零
        if normR < 1e-10
            continue;
        end

        % 处理normP中的零值（解恰好在理想点）
        normP(normP < 1e-10) = 1e-10;

        % CosineP = 解的方向与参考方向之间的夹角余弦值
        CosineP = (sum((sub_pop - Z) .* W, 2) ./ normW ./ normP) - 1e-6;

        % 限制CosineP的范围，避免sqrt中的负数
        CosineP = max(-1, min(1, CosineP));

        % PBI值 = d1 + delt * d2
        % d1 = 解在参考方向上的投影距离（沿参考方向前进的距离）
        % d2 = 解偏离参考方向的垂直距离（惩罚项）
        % g = d1 + delt * d2，再除以参考距离normR进行归一化
        g = normP .* CosineP + delt * normP .* sqrt(1 - CosineP.^2);
        g = g ./ normR;

        % 找出PBI值大于1的解（离参考解太远）
        bad_idx = g > 1;

        % 如果有坏解，标记它们
        if any(bad_idx)
            Output(sub_popind(bad_idx)) = false;
        end
    end

    % 计算好解比例
    rate = sum(Output) / length(Output);
end
