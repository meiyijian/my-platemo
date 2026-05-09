function Next = RSurrogateAssistedSelection_TrueSR(Problem, Ref, Input, wmax, Smodel)
% 代理辅助选择：用训练好的神经网络来"猜想"哪些候选解更好，避免昂贵的真实评估
%
% 核心思路：
%   真实评估目标函数很昂贵（每次评估可能耗时数小时），所以用神经网络作为
%   "廉价代理"来快速评估大量候选解的质量。只有被神经网络一致认可的候选解
%   才会被交给真实评估。
%
% 算法流程：
%   1. 用遗传算子生成初始候选解
%   2. 用神经网络对候选解打分 → 保留最好的 → 用它们作为父代继续生成新候选
%   3. 重复 wmax 次（限制总尝试次数）
%   4. 从最终生成的候选解中选出 top-4 作为最终输出
%
% 输入参数：
%   Problem: 优化问题对象，提供问题的边界和约束信息
%   Ref    : 参考解（种群对象），作为遗传算子的精英引导
%   Input  : 当前种群的决策变量矩阵
%   wmax   : 最大搜索次数（控制代理评估的总量）
%   Smodel : 代理模型结构体，包含：
%            .X          - 种群决策变量
%            .score      - 种群混合分数
%            .net        - 训练好的神经网络
%            .mp_struct  - 归一化映射参数
%            .anchorNum  - 锚点数量
%
% 输出参数：
%   Next: 选出的最优候选解决策变量矩阵（最多 4 个），用于下一步真实评估

    % ===== 步骤1：用遗传算子生成初始候选解 =====
    % OperatorGA 是 PlatEMO 的遗传算法算子（模拟二进制交叉 + 多项式变异）
    % {1, 15, 1, 5} 是遗传参数：
    %   1  = 交叉概率（这里不是传统概率，PlatEMO 中的特殊编码）
    %   15 = 分布指数（模拟二进制交叉的参数）
    %   1  = 变异概率的编码
    %   5  = 分布指数（多项式变异的参数）
    % [Input; Ref.decs] 把当前种群和参考解的决策变量一起作为父代
    Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});

    i = 0;  % 累计尝试次数的计数器

    % ===== 步骤2：迭代生成和筛选候选解 =====
    % 每次循环：
    %   ① 用神经网络对当前候选解打分
    %   ② 保留得分最高的 keepNum 个解作为下一轮的"父代"
    %   ③ 用遗传算子生成新的候选解
    %   ④ 累计尝试次数
    while i < wmax
        % 用代理模型对候选解打分并排序（分数高的排前面）
        [sortedIndex, ~] = model_select_true_sr(Smodel, Next);

        % keepNum：保留前几名？
        % min(参考解数量, 候选解数量)，保证不过多也不超出候选解范围
        keepNum = min(length(Ref), size(Next, 1));

        % 保留得分最高的 keepNum 个解作为新父代
        Input = Next(sortedIndex(1:keepNum), :);

        % 用遗传算子从新父代生成更多候选解
        Next = OperatorGA(Problem, [Input; Ref.decs], {1, 15, 1, 5});

        % 累加已尝试的次数（size(Next,1) = 本轮生成的新候选解数量）
        i = i + size(Next, 1);
    end

    % ===== 步骤3：从最终候选解中选出最优的几个 =====
    % 对最后一批候选解再次打分排序
    [~, scores] = model_select_true_sr(Smodel, Next);
    [~, index]  = sort(scores, 'descend');  % 按分数降序排列

    % 选分数最高的前 4 个（或全部，如果候选解不足 4 个）
    Next = Next(index(1:min(4, size(Next, 1))), :);
end

function [ind, scores] = model_select_true_sr(Smodel, Next)
% 使用训练好的神经网络对候选解打分
%
% 打分机制（Borda-style 排序分数）：
%   1. 从训练种群中按分数均匀采样 anchorNum 个"锚点"
%      （锚点覆盖了从最好到最差的整个分数范围）
%   2. 对每个候选解，构建它与每个锚点的"正向对"(候选解, 锚点)
%      和"反向对"(锚点, 候选解)
%   3. 用神经网络预测这两种配对的概率
%   4. 综合正反向预测得到一个公平的分数
%
% 为什么需要正反向对？
%   神经网络可能对顺序敏感：预测 "A vs B" 和 "B vs A" 可能不一致
%   pairScore = 0.5 * (P(A赢B) + (1 - P(B赢A)))
%   这种对称化处理确保了公平性

    % 训练数据：种群中的决策变量
    modelX = Smodel.X;
    % 训练数据：每个解的混合分数（分数越高越好）
    score  = Smodel.score(:);
    % 训练好的神经网络
    net    = Smodel.net;

    % ===== 步骤1：选取锚点 =====
    % 按分数从高到低排序
    [~, rankIndex] = sort(score, 'descend');

    % 确定锚点数量（不能超过解的总数）
    anchorNum = min(Smodel.anchorNum, numel(rankIndex));

    % 从排序列表中均匀采样锚点索引
    % linspace(1, N, anchorNum) 生成从 1 到 N 均匀分布的 anchorNum 个位置
    % round 取整，unique 去重（防止重复索引）
    anchorRank = unique(round(linspace(1, numel(rankIndex), anchorNum)));

    % 提取锚点的决策变量（这些是"标杆解"，覆盖了从好到差的整个范围）
    anchors = modelX(rankIndex(anchorRank), :);

    % ===== 步骤2：构建测试配对 =====
    nextNum   = size(Next, 1);       % 候选解数量
    anchorNum = size(anchors, 1);    % 锚点数量（使用实际的锚点数）

    % 构建"正向对"：候选解 vs 锚点
    % repelem(Next, anchorNum, 1)：
    %   将 Next 的每行重复 anchorNum 次，使得每个候选解与每个锚点配对
    %   例如：Next = [A; B], anchors = [X; Y; Z]
    %   结果 = [A; A; A; B; B; B]
    nextBlock   = repelem(Next, anchorNum, 1);

    % repmat(anchors, nextNum, 1)：
    %   将整个 anchors 矩阵重复 nextNum 次
    %   例如：anchors = [X; Y; Z], nextNum = 2
    %   结果 = [X; Y; Z; X; Y; Z]
    anchorBlock = repmat(anchors, nextNum, 1);

    % 构建配对矩阵（将候选解和锚点的特征拼接起来）
    forwardPairs = [nextBlock, anchorBlock];  % 正向：候选解在左，锚点在右
    reversePairs = [anchorBlock, nextBlock];  % 反向：锚点在左，候选解在右
    testPairs    = [forwardPairs; reversePairs];  % 合并所有配对

    % ===== 步骤3：用神经网络预测配对概率 =====
    % 用训练时的归一化参数对测试数据做归一化
    testPairsNor = mapminmax('apply', testPairs', Smodel.mp_struct)';

    % 用神经网络计算每个配对中"左边的解更好"的概率
    prob = net(testPairsNor')';
    % 将概率钳制在 [0, 1] 范围内（防止数值误差）
    prob = min(max(prob(:), 0), 1);

    % ===== 步骤4：计算每个候选解的 Bordar-style 分数 =====
    % 分解正反向配对的预测结果
    pairNum     = nextNum * anchorNum;  % 正向配对数
    probForward = reshape(prob(1:pairNum),             anchorNum, nextNum)';  % 候选解对锚点的胜率
    probReverse = reshape(prob(pairNum+1:end), anchorNum, nextNum)';  % 锚点对候选解的胜率

    % 综合分数 = 0.5*(正向胜率 + (1 - 反向胜率))
    % 解释：
    %   probForward：神经网络认为"候选解比锚点好"的概率
    %   probReverse：神经网络认为"锚点比候选解好"的概率
    %   理想情况下 probForward + probReverse = 1（一致性），但实际会有偏差
    %   这个公式同时利用了两方面的信息，使分数更加可靠
    pairScore = 0.5 .* (probForward + 1 - probReverse);

    % 对每个候选解，取它与所有锚点的分数平均值作为最终得分
    % 分数越高说明候选解整体上比锚点更好
    scores = mean(pairScore, 2);

    % 按分数降序排列，返回排序后的索引
    [~, ind] = sort(scores, 'descend');
end
