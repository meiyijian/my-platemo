function [good_idx, bad_idx, middle_idx, score] = ReferenceVectorPartition(PopObj, varargin)
% 基于参考向量的优劣划分（适用于多目标/超多目标）
% 输入：
%   PopObj     - N×M 目标矩阵（已归一化到 [0,1] 可选，但非必需）
%   varargin   - 可选参数对：'Nref', 参考向量数量（默认 N），'theta', 惩罚因子（默认 5）
% 输出：
%   good_idx   - 好解的索引（前 25%，且至少每个参考向量一个代表）
%   bad_idx    - 坏解的索引（后 25%）
%   middle_idx - 中间解的索引
%   score      - 每个解的综合得分

% 解析输入
if nargin > 1
    for i = 1:2:length(varargin)
        switch lower(varargin{i})
            case 'nref'
                Nref = varargin{i+1};
            case 'theta'
                theta = varargin{i+1};
        end
    end
end
if ~exist('Nref', 'var'), Nref = size(PopObj,1); end   % 默认与种群大小相同
if ~exist('theta', 'var'), theta = 5; end

[N, M] = size(PopObj);

%% Step 1: 生成均匀分布的参考向量
% 使用 Das-Dennis 方法或两层方法生成 Nref 个参考向量
[V, ~] = UniformPoint(Nref, M, 'ILD');   % PlatEMO 内置函数，生成均匀分布的单位向量
V = V ./ vecnorm(V, 2, 2);               % 归一化为单位向量

%% Step 2: 将每个解关联到最近的参考向量（基于角度）
% 计算余弦相似度（或角度）
cosine = 1 - pdist2(PopObj, V, 'cosine');   % 越大表示越接近
[~, ref_idx] = max(cosine, [], 2);          % 每个解关联的参考向量索引

%% Step 3: 计算收敛性指标（PBI 值）
Zmin = min(PopObj, [], 1);                   % 理想点
% 沿参考方向的距离 d1
d1 = sum((PopObj - Zmin) .* V(ref_idx, :), 2) ./ vecnorm(V(ref_idx, :), 2, 2);
% 垂直距离 d2
d2 = sqrt(sum((PopObj - (Zmin + d1 .* V(ref_idx, :))).^2, 2));
PBI = d1 + theta * d2;                        % PBI 值，越小表示该方向收敛越好

%% Step 4: 计算多样性奖励（基于参考向量的稀疏度）
% 每个参考向量关联的解的数量
count_per_ref = accumarray(ref_idx, 1, [Nref, 1]);
% 稀疏度：关联解越少，稀疏度越高（奖励越大）
sparsity = 1 ./ (count_per_ref(ref_idx) + 1e-6);   % 加微小量避免除零

%% Step 5: 综合得分
% 将 PBI 转换为正向指标（越大越好），并与稀疏度结合
% 这里采用负 PBI 加稀疏度，也可根据问题调整权重
score = -PBI + sparsity;      % 得分越高，表示解越好

%% Step 6: 好解选择策略
% 原则：每个参考向量至少选一个代表解（若该方向有解），再按得分补足到前 25%
good_idx = [];
for i = 1:Nref
    in_this_ref = find(ref_idx == i);
    if ~isempty(in_this_ref)
        [~, best] = max(score(in_this_ref));
        good_idx = [good_idx; in_this_ref(best)];
    end
end
% 如果代表解数量不足总体的 25%，从剩余解中按得分补充
good_num = ceil(N / 4);
if length(good_idx) < good_num
    remaining = setdiff(1:N, good_idx);
    [~, sorted_remaining] = sort(score(remaining), 'descend');
    need = good_num - length(good_idx);
    good_idx = [good_idx; remaining(sorted_remaining(1:need))];
end
% 确保 good_idx 是列向量
good_idx = good_idx(:);

%% Step 7: 坏解选择
% 按得分升序排序，取后 25%（得分最低的）
[~, sorted_all] = sort(score);
bad_num = good_num;
bad_idx = sorted_all(1:bad_num);
% 避免与好解重叠
bad_idx = setdiff(bad_idx, good_idx);
if length(bad_idx) < bad_num
    remaining2 = setdiff(1:N, [good_idx; bad_idx]);
    need2 = bad_num - length(bad_idx);
    [~, sorted_remaining2] = sort(score(remaining2));
    bad_idx = [bad_idx; remaining2(sorted_remaining2(1:need2))];
end
bad_idx = bad_idx(:);

%% Step 8: 中间解
middle_idx = setdiff(1:N, [good_idx; bad_idx])';
middle_idx = middle_idx(:);

end