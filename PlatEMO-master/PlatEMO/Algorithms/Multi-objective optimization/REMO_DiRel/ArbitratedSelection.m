function Next = ArbitratedSelection(Problem, Ref, Input, wmax, Smodel)
% ArbitratedSelection - 仲裁选择主循环（模块③）
%
% 功能概述：
%   使用遗传算子(GA)生成候选解，然后用仲裁器(ArbitratorScore)评分筛选
%   这是 REMO_DiRel 的第三个核心创新：逐候选逆方差仲裁
%
% 整体流程：
%   1. 用GA生成初始候选解
%   2. 循环：评分 → 选择优秀解 → GA交叉变异 → 生成新候选解
%   3. 最终筛选：只保留得分 > 3.9 的高质量解
%
% 为什么用GA生成候选解？
%   - 代理模型只能评分，不能直接生成解
%   - GA通过交叉变异探索决策空间，生成多样化的候选解
%   - 仲裁器从候选解中选出最有希望的
%
% 什么是"难度感知GA参数"？
%   - 易目标子集的难度低 → GA更局部搜索（exploit）
%   - 难目标子集的难度高 → GA更全局搜索（explore）
%   - 通过调整SBX和变异的分布指数来控制
%
% 输入：
%   Problem - 问题对象
%   Ref     - 参考解集（用于GA算子）
%   Input   - 当前种群决策变量，N×D 矩阵
%   wmax    - 代理模型评估预算（循环次数上限）
%   Smodel  - 代理模型结构体
%
% 输出：
%   Next    - 筛选后的候选解决策变量，n×D 矩阵

    % ===================================================================
    % 第一步：生成初始候选解
    % ===================================================================
    % difficultyAwareGAParam 根据易目标难度自适应调整GA参数
    gaParam = difficultyAwareGAParam(Smodel);

    % OperatorGA 是 PlatEMO 内置的遗传算子
    % 输入：[当前种群; 参考解]
    % 参数：{交叉概率, 交叉分布指数, 变异概率, 变异分布指数}
    Next = OperatorGA(Problem, [Input; Ref.decs], gaParam);

    i = 0;   % 已评估的候选解计数

    % ===================================================================
    % 第二步：迭代优化循环
    % ===================================================================
    % 每轮：评分 → 选优秀解 → GA交叉变异 → 生成新候选解
    while i < wmax
        % 对当前候选解评分并按得分降序排列
        [sorted_idx, ~] = scoreAndSort(Smodel, Next);

        % 保留得分最高的 nKeep 个解（nKeep = 参考解数量）
        nKeep = min(length(Ref), size(Next, 1));
        Selected = Next(sorted_idx(1:nKeep), :);

        % 用选出的优秀解 + 参考解做GA，生成新的候选解
        Next = OperatorGA(Problem, [Selected; Ref.decs], gaParam);

        % 更新计数
        i = i + size(Next, 1);
    end

    % ===================================================================
    % 第三步：最终筛选
    % ===================================================================
    % 对最终候选解评分
    [~, scores] = scoreAndSort(Smodel, Next);

    if sum(scores > 3.9) < 4
        % 如果得分 > 3.9 的解不足4个，取得分最高的4个
        [~, ind] = sort(scores, 'descend');
        Next = Next(ind(1:min(4, size(Next,1))), :);
    else
        % 否则，只保留得分 > 3.9 的解
        Next = Next(scores > 3.9, :);
    end
end


%% ========================================================================
%  局部辅助函数
%  ========================================================================

function [ind, scores] = scoreAndSort(Smodel, Candidates)
% scoreAndSort - 对候选解评分并按得分降序排列
%
% 输入：
%   Smodel    - 代理模型
%   Candidates - 候选解决策变量
%
% 输出：
%   ind    - 排序后的索引（得分最高的在前）
%   scores - 各候选解的得分

    % ArbitratorScore 用双尺度集成网络对候选解评分
    scores = ArbitratorScore(Smodel, Candidates);

    % 按得分降序排列
    [~, ind] = sort(scores, 'descend');
end


function param = difficultyAwareGAParam(Smodel)
% difficultyAwareGAParam - 根据易目标难度自适应调整GA参数
%
% 核心思想：
%   - 易目标子集的难度低 → 优化进展顺利 → 更局部搜索（exploit）
%   - 难目标子集的难度高 → 优化陷入困境 → 更全局搜索（explore）
%
% 参数调整策略：
%   disC (SBX分布指数)：越大 → 生成的子代越靠近父代 → 更局部
%   disM (变异分布指数)：越大 → 变异幅度越小 → 更局部
%   proM (变异概率)：越大 → 变异越频繁 → 更全局
%
% 输入：
%   Smodel - 代理模型结构体，包含 .easyDifficulty（易目标平均难度）
%
% 输出：
%   param - {交叉概率, 交叉分布指数, 变异概率, 变异分布指数}

    % 提取易目标平均难度
    diff = Smodel.easyDifficulty;

    % 处理异常情况
    if isempty(diff) || isnan(diff)
        diff = 0.5;   % 默认中等难度
    end
    diff = min(max(diff, 0), 1);   % 限制在 [0, 1]

    % 根据难度调整参数
    % (1-diff)：难度越低，值越大 → 更局部搜索
    disC = round(10 + 20*(1-diff));   % SBX分布指数：[10, 30]
    disM = round(5  + 20*(1-diff));   % 变异分布指数：[5, 25]
    proM = 1 + 0.5*diff;              % 变异概率：[1, 1.5]

    param = {1, disC, proM, disM};
end
