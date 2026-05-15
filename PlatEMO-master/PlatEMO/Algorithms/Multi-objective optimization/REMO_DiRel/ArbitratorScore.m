function scores = ArbitratorScore(Smodel, Candidates)
% ArbitratorScore - 逐候选逆方差仲裁评分（模块③核心）
%
% 功能概述：
%   对每个候选解，用全目标集成网络(net_F)和子目标集成网络(net_S)分别评分，
%   然后用逆方差自适应权重融合两个模型的预测
%
% 核心创新：逐候选逆方差权重
%   - 传统方法：全局标量权重 w_F=0.7, w_S=0.3（对所有候选解相同）
%   - 本方法：对每个候选解x独立计算权重
%     w_F(x) = (1/σ²_F(x)) / (1/σ²_F(x) + 1/σ²_S(x))
%   - 含义：哪个模型对这个候选解更确定（方差小），就更信任它
%
% 冲突分支处理：
%   当两个模型预测方向相反时：
%   1. 两模型都不确定 → 弃权（得分0）
%   2. 子目标确定、全目标不确定 → 加多样性奖励
%
% 输入：
%   Smodel    - 代理模型结构体，包含：
%               .X, .Y_F, .Y_S - 训练数据和标签
%               .DualNet.nets_F, .nets_S - 双尺度集成网络
%               .DualNet.mp_struct_F, .mp_struct_S - 归一化参数
%               .tau_conf - 置信度阈值（默认0.3）
%               .anchorMax - 每类anchor最大数量（默认30）
%   Candidates - nCand×D 矩阵，候选解决策变量
%
% 输出：
%   scores    - nCand×1 向量，各候选解的得分（越高越好）
%
% 调用示例：
%   scores = ArbitratorScore(Smodel, Candidates);

    nCand = size(Candidates, 1);
    if nCand == 0
        scores = zeros(0, 1);
        return;
    end

    % ===================================================================
    % 第一步：用两个集成网络分别对候选解评分
    % ===================================================================
    % scoreAllByEnsemble 对每个候选解，计算与anchor点的关系对，
    % 然后用集成网络预测，返回均值(mu)和方差(sigma2)

    % 全目标网络评分
    [mu_F, sigma2_F] = scoreAllByEnsemble( ...
        Smodel.X, Smodel.Y_F, Smodel.DualNet.nets_F, ...
        Smodel.DualNet.mp_struct_F, Candidates, Smodel.anchorMax);

    % 子目标网络评分
    [mu_S, sigma2_S] = scoreAllByEnsemble( ...
        Smodel.X, Smodel.Y_S, Smodel.DualNet.nets_S, ...
        Smodel.DualNet.mp_struct_S, Candidates, Smodel.anchorMax);

    % ===================================================================
    % 第二步：计算归一化标准差（用于判断置信度）
    % ===================================================================
    % sqrt(方差) = 标准差
    s_F = sqrt(max(sigma2_F, 0));   % 防止负方差（数值误差）
    s_S = sqrt(max(sigma2_S, 0));

    % minmaxNorm 归一化到 [0, 1]
    n_F = minmaxNorm(s_F);   % 全目标网络的归一化标准差
    n_S = minmaxNorm(s_S);   % 子目标网络的归一化标准差

    % ===================================================================
    % 第三步：计算归一化得分
    % ===================================================================
    % minmaxNormScore 归一化到 [0, 4] 范围
    tildeS_F = minmaxNormScore(mu_F);
    tildeS_S = minmaxNormScore(mu_S);

    % ===================================================================
    % 第四步：计算逆方差权重
    % ===================================================================
    % 核心公式：w_F(x) = (1/σ²_F) / (1/σ²_F + 1/σ²_S)
    % 方差越小 → 1/σ²越大 → 权重越大
    eps_v = 1e-6;   % 防止除零的小常数
    invF  = 1 ./ (s_F.^2 + eps_v);   % 全目标网络的逆方差
    invS  = 1 ./ (s_S.^2 + eps_v);   % 子目标网络的逆方差
    w_F   = invF ./ (invF + invS);   % 全目标网络的权重
    w_S   = 1 - w_F;                 % 子目标网络的权重

    % 基础得分 = 加权平均
    base = w_F .* tildeS_F + w_S .* tildeS_S;

    % ===================================================================
    % 第五步：冲突分支处理
    % ===================================================================
    tau      = Smodel.tau_conf;   % 置信度阈值（默认0.3）

    % 判断冲突：两个模型预测方向相反
    % sign(mu_F) 和 sign(mu_S) 取符号（+1或-1）
    % 如果符号相反，乘积为负
    conflict = (sign(mu_F) .* sign(mu_S)) < 0;

    % --- 分支1：弃权 ---
    % 条件：冲突 + 两个模型都不确定（归一化标准差 > 阈值）
    % 处理：得分设为0（弃权，不推荐这个候选解）
    abstain  = conflict & (n_F > tau) & (n_S > tau);
    base(abstain) = 0;

    % --- 分支2：子目标主导冲突 ---
    % 条件：冲突 + 子目标预测为正 + 全目标预测为负 + 全目标不确定 + 子目标确定
    % 含义：子目标模型很确定这个解好，但全目标模型不确定
    % 处理：加多样性奖励（鼓励探索稀缺区域）
    subwin = conflict & (mu_S > 0) & (mu_F < 0) & (n_F > tau) & (n_S <= tau);
    if any(subwin)
        % 计算候选解之间的欧氏距离矩阵
        D_pairs = pdist2(Candidates, Candidates);

        % 对角线设为inf（自己到自己的距离不算）
        D_pairs(logical(eye(nCand))) = inf;

        % novelty = 到最近邻居的距离
        % 距离越大 → 越"新颖"（周围没有其他候选解）
        novelty = min(D_pairs, [], 2);
        novelty(~isfinite(novelty)) = 0;   % 处理inf
        novelty = minmaxNorm(novelty);      % 归一化到 [0, 1]

        % 加多样性奖励：base += 0.5 * novelty
        base(subwin) = base(subwin) + 0.5 .* novelty(subwin);
    end

    scores = base;
end


%% ========================================================================
%  局部辅助函数
%  ========================================================================

function [mu, sigma2] = scoreAllByEnsemble(X_train, Y_train, nets, mp_struct, Candidates, anchorMax)
% scoreAllByEnsemble - 用集成网络对候选解评分
%
% 功能：
%   1. 从训练数据中选择anchor点（每类最多anchorMax个）
%   2. 对每个候选解，计算与anchor点的关系对
%   3. 用K个网络分别预测，返回均值和方差
%
% 输入：
%   X_train   - 训练输入（已归一化）
%   Y_train   - 训练标签（+1/0/-1）
%   nets      - 1×K cell，集成网络
%   mp_struct - 归一化参数
%   Candidates - 候选解决策变量
%   anchorMax  - 每类anchor最大数量
%
% 输出：
%   mu     - nCand×1，集成预测均值
%   sigma2 - nCand×1，集成预测方差

    % 过滤空网络
    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    K = numel(nets_v);
    nCand = size(Candidates, 1);

    if K == 0
        mu = zeros(nCand, 1);
        sigma2 = ones(nCand, 1);
        return;
    end

    % 选择anchor点
    % C1: 正类anchor（标签为+1的训练样本）
    % C2: 负类anchor（标签为-1或0的训练样本）
    C1 = selectAnchors(X_train(Y_train == 1, :), anchorMax);
    C2 = selectAnchors(X_train(Y_train ~= 1, :), anchorMax);

    % 对每个网络计算候选解得分
    sample_scores = zeros(nCand, K);
    for kk = 1:K
        sample_scores(:, kk) = scoreOneNet(C1, C2, nets_v{kk}, mp_struct, Candidates);
    end

    % 计算均值和方差
    mu = mean(sample_scores, 2);
    if K >= 2
        sigma2 = var(sample_scores, 0, 2);   % 方差
    else
        sigma2 = ones(nCand, 1);   % 单网络无法计算方差，设为1
    end
end


function X = selectAnchors(X, anchorMax)
% selectAnchors - 选择anchor点
%
% 功能：从X中均匀选择最多anchorMax个点
%       用于控制评分计算量
%
% 输入：
%   X         - n×D 矩阵
%   anchorMax - 最大数量
%
% 输出：
%   X         - 选择后的矩阵

    n = size(X, 1);
    if n <= anchorMax
        return;   % 样本数不超过上限，全部保留
    end
    % linspace(1, n, anchorMax) 生成均匀间隔的索引
    idx = unique(round(linspace(1, n, anchorMax)), 'stable');
    X = X(idx, :);
end


function scoreVec = scoreOneNet(C1, C2, net, mp_struct, Candidates)
% scoreOneNet - 用单个网络对候选解评分
%
% 功能：
%   对每个候选x：
%   1. 构造与C1(正类anchor)的关系对：[C1, x] 和 [x, C1]
%   2. 构造与C2(负类anchor)的关系对：[C2, x] 和 [x, C2]
%   3. 用网络预测每对的关系（+1/0/-1概率）
%   4. 综合得分 = 正类得分 - 负类得分
%
% 输入：
%   C1, C2   - 正类和负类的anchor点
%   net      - 单个patternnet
%   mp_struct - 归一化参数
%   Candidates - 候选解
%
% 输出：
%   scoreVec - nCand×1 得分向量

    n1 = size(C1, 1);   % 正类anchor数量
    n2 = size(C2, 1);   % 负类anchor数量
    nCand = size(Candidates, 1);

    if nCand == 0 || (n1 + n2) == 0
        scoreVec = zeros(nCand, 1);
        return;
    end

    D = size(Candidates, 2);   % 决策变量维度

    % 构造所有关系对
    % 每个候选解需要与所有anchor构造关系对
    rowCount = 2 * (n1 + n2) * nCand;
    all_pairs = zeros(rowCount, 2 * D);

    for i = 1:nCand
        base = (i-1) * 2 * (n1 + n2);

        % 与正类anchor的关系对
        if n1 > 0
            Xi = repmat(Candidates(i, :), n1, 1);   % 复制n1份
            all_pairs(base+1 : base+n1, :)      = [C1, Xi];   % [C1, x]
            all_pairs(base+1+n1 : base+2*n1, :) = [Xi, C1];   % [x, C1]
        end

        % 与负类anchor的关系对
        if n2 > 0
            Xi = repmat(Candidates(i, :), n2, 1);
            p0 = base + 2*n1;
            all_pairs(p0+1 : p0+n2, :)      = [C2, Xi];   % [C2, x]
            all_pairs(p0+1+n2 : p0+2*n2, :) = [Xi, C2];   % [x, C2]
        end
    end

    % 用网络预测
    try
        TestIn_nor = mapminmax('apply', all_pairs', mp_struct)';   % 归一化
        pre_out = net(TestIn_nor')';   % 预测，输出 n×3 概率矩阵
    catch
        scoreVec = zeros(nCand, 1);
        return;
    end

    % 综合得分
    scoreVec = zeros(nCand, 1);
    for i = 1:nCand
        base = (i-1) * 2 * (n1 + n2);
        Cscore = [0, 0];   % [正类得分, 负类得分]

        % 与正类anchor的关系
        if n1 > 0
            % [C1, x] 的预测：如果预测为+1（x≻C1），正类得分+1
            pre_C1Xi = sum(pre_out(base+1 : base+n1, :), 1) ./ n1;
            Cscore(1) = Cscore(1) + pre_C1Xi(2) + pre_C1Xi(3);   % P(0) + P(-1) 表示x不比C1差
            Cscore(2) = Cscore(2) + pre_C1Xi(1);                  % P(+1) 表示x≻C1

            % [x, C1] 的预测
            pre_XiC1 = sum(pre_out(base+1+n1 : base+2*n1, :), 1) ./ n1;
            Cscore(1) = Cscore(1) + pre_XiC1(2) + pre_XiC1(1);   % P(0) + P(+1) 表示x不比C1差
            Cscore(2) = Cscore(2) + pre_XiC1(3);                  % P(-1) 表示C1≻x
        end

        % 与负类anchor的关系
        if n2 > 0
            p0 = base + 2*n1;
            % [C2, x] 的预测
            pre_C2Xi = sum(pre_out(p0+1 : p0+n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_C2Xi(3);                  % P(-1) 表示C2≻x（对x有利）
            Cscore(2) = Cscore(2) + pre_C2Xi(2) + pre_C2Xi(1);   % P(0) + P(+1) 表示x不比C2好

            % [x, C2] 的预测
            pre_XiC2 = sum(pre_out(p0+1+n2 : p0+2*n2, :), 1) ./ n2;
            Cscore(1) = Cscore(1) + pre_XiC2(1);                  % P(+1) 表示x≻C2（对x有利）
            Cscore(2) = Cscore(2) + pre_XiC2(2) + pre_XiC2(3);   % P(0) + P(-1) 表示x不比C2好
        end

        % 最终得分 = 正类得分 - 负类得分
        scoreVec(i) = Cscore(1) - Cscore(2);
    end
end


function y = minmaxNorm(x)
% minmaxNorm - Min-Max归一化到 [0, 1]
    xmin = min(x);
    xmax = max(x);
    span = xmax - xmin;
    if span < 1e-12
        y = zeros(size(x));
    else
        y = (x - xmin) ./ span;
    end
end


function y = minmaxNormScore(x)
% minmaxNormScore - Min-Max归一化到 [0, 4]
% 乘以4是为了让得分范围与阈值3.9匹配
    y = minmaxNorm(x) .* 4;
end
