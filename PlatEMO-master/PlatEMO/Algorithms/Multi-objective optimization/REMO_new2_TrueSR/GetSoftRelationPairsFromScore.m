function [XXs,Ps,PairIndex] = GetSoftRelationPairsFromScore(Input,Score,varargin)
% 将连续的排序分数转化为软排序对（soft ranking pairs）
%
% 核心思路：
%   传统方法用"硬标签"：A 比 B 好 → 标签=1；B 比 A 好 → 标签=0。
%   本函数用 Sigmoid 函数将分数差转化为一个 0~1 之间的"软概率"：
%       P(A 比 B 好) = 1 / (1 + exp(-alpha * (score_A - score_B)))
%   这样做的好处：
%     1. 分数接近时概率接近 0.5（表示"差不多"），而非强行分 0/1
%     2. 神经网络学习时梯度更平滑，训练更稳定
%
% 输入参数：
%   Input   : 决策向量矩阵，每一行是一个解的特征
%   Score   : 每个解对应的排序分数（数值越高表示解越好）
%   varargin: 可选参数对（'参数名', 参数值）
%             'Alpha'    - Sigmoid 的陡峭系数（默认 6），越大曲线越陡
%             'MaxPairs' - 最大配对数量（默认 inf，即不做限制）
%             'MinGap'   - 最小分数差阈值（默认 0），差值小于此值的对会被过滤
%
% 输出参数：
%   XXs      : 输入特征对矩阵，每行是 [解i的特征, 解j的特征]
%   Ps       : 软排序概率列向量，P(i 比 j 好) 的概率值
%   PairIndex: 配对索引矩阵，每行是 [i索引, j索引]

    % 从可选参数中提取配置值
    alpha    = get_option(varargin,'Alpha',6);
    maxPairs = get_option(varargin,'MaxPairs',inf);
    minGap   = get_option(varargin,'MinGap',0);

    % 确保 Score 是列向量
    Score = Score(:);
    N     = size(Input,1);  % 解的个数

    % 检查输入的合法性
    if numel(Score) ~= N
        error('分数个数必须等于决策向量个数。');
    end

    % 如果只有 0 或 1 个解，无法产生配对，返回空
    if N < 2
        XXs       = [];
        Ps        = [];
        PairIndex = [];
        return;
    end

    % ===== 步骤1：将分数归一化到 [0, 1] 区间 =====
    % 这样不同问题上的分数都在同一尺度上，alpha 参数才能通用
    sMin = min(Score);
    sMax = max(Score);
    if sMax > sMin  % 分数有差异时，做归一化
        Score = (Score - sMin) ./ (sMax - sMin);
    else
        % 所有分数相同时，全部设为 0.5（中等分数）
        Score = 0.5 .* ones(size(Score));
    end

    % ===== 步骤2：生成所有可能的配对 =====
    % find(~eye(N)) 找到非对角线元素（即 i != j 的所有组合）
    % eye(N) 是 N×N 的单位矩阵（对角线为 1），~eye(N) 取反后非对角线为 1
    [I,J] = find(~eye(N));
    % 此时 I 和 J 包含了所有 (i,j) 配对，其中 i != j
    % 例如 N=3 时，包含 (1,2), (1,3), (2,1), (2,3), (3,1), (3,2)

    % ===== 步骤3：过滤分数差距太小的配对 =====
    gap  = abs(Score(I) - Score(J));  % 计算每对的分数差绝对值
    keep = gap >= minGap;             % 只保留差距 >= minGap 的配对
    I    = I(keep);
    J    = J(keep);

    % ===== 步骤4：如果配对太多，随机采样限制数量 =====
    pairNum = numel(I);  % numel 返回元素总数
    if isfinite(maxPairs) && pairNum > maxPairs
        % 从所有配对中随机选择 maxPairs 个
        choose = randperm(pairNum, maxPairs);
        I = I(choose);
        J = J(choose);
    end

    % ===== 步骤5：用 Sigmoid 函数计算软排序概率 =====
    % delta = score_I - score_J
    % 当 delta > 0（i 比 j 好），P → 1（趋近于 1）
    % 当 delta < 0（j 比 i 好），P → 0（趋近于 0）
    % 当 delta ≈ 0（差不多），   P ≈ 0.5
    delta = Score(I) - Score(J);
    Ps    = 1 ./ (1 + exp(-alpha .* delta));  % Sigmoid 函数

    % ===== 步骤6：拼接输入特征 =====
    % 每行将 i 的特征和 j 的特征拼接在一起：[x_i | x_j]
    XXs       = [Input(I,:), Input(J,:)];
    PairIndex = [I, J];          % 记录配对索引，便于追踪

    % ===== 步骤7：打乱顺序，避免训练时同一对反复出现 =====
    order     = randperm(size(XXs,1));
    XXs       = XXs(order,:);
    Ps        = Ps(order,:);
    PairIndex = PairIndex(order,:);
end

function val = get_option(args,name,default)
% 从可选参数列表中提取参数值的小工具函数
% args 是 { ..., '参数名', 参数值, ...} 格式的参数对
    val = default;
    for i = 1:2:length(args)  % 步长为 2，每次处理一个 (参数名, 参数值) 对
        if strcmpi(args{i}, name)  % strcmpi 忽略大小写比较字符串
            val = args{i+1};
            return;
        end
    end
end
