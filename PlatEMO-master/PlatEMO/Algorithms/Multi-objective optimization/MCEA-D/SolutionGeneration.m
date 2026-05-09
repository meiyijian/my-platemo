function y_i = SolutionGeneration(Problem, Population, P, c_i, R_max, i)
% MCEA/D 的解生成函数（SVM 辅助筛选核心）
%
% ==== 功能说明 ====
% 使用差分进化（DE）算子生成候选解，然后调用子问题 i 的 SVM 分类器判断该解是否为"好解"。
% 如果是好解（正类），直接返回该解；否则重新生成，最多尝试 R_max 次。
% 超过重试次数仍未找到好解时，返回判别分数最高的候选解（即"最不差"的那个）。
%
% ==== 为什么这样做？ ====
% 如果在生成阶段就能用廉价的 SVM 预判新解的好坏，就可以避免将大量坏解浪费在
% 昂贵的目标函数评估上。SVM 的评估开销远小于真实目标函数。
%
% ==== 输入参数 ====
% Problem    : 优化问题对象（包含维度、边界等信息）
% Population : 当前种群（结构体数组，每个元素有 .dec 和 .obj 等字段）
% P          : 父代候选索引列表
% c_i        : 子问题 i 的 SVM 对象（包含训练好的模型）
% R_max      : 最大重试次数
% i          : 当前子问题编号
%
% ==== 输出参数 ====
% y_i : 决策变量向量（即通过SVM筛选的候选解）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Masaya Nakata

    % 循环尝试，最多 R_max 次
    for r = 1 : R_max
        % ----- 生成候选解 -----
        % OperatorDE: 差分进化算子（DE/rand/1 策略）
        % 输入三个父代解：子问题 i 的当前解、P(1) 的解、P(2) 的解
        % 公式: candidate = x_i + F * (x_a - x_b)
        %   其中 x_i 是目标父代，x_a 和 x_b 是随机选择的辅助父代
        candidate = OperatorDE(Problem, Population(i).dec, Population(P(1)).dec, Population(P(2)).dec);

        % ----- 打乱父代列表 -----
        % 让下一轮的辅助父代和之前不同，增加候选解多样性
        rnd = randperm(length(P));   % 生成一个随机排列
        P   = P(rnd);                 % 按随机顺序重排父代列表

        % ----- 用 SVM 预测候选解类别 -----
        % c：预测类别  →  1 = 正类（好解 / 可改善子问题）
        %                  -1 = 负类（差解 / 无法改善）
        % d_i：决策函数得分 → 分数越高，越可能是好解
        [c, d_i] = c_i.PredictClass(candidate);

        if c == 1
            %% 情况A：预测为正类（好解）
            % 直接返回该候选解，终止循环
            % 这个解将在主循环中被真实目标函数评估
            y_i = candidate;
            return
        else
            %% 情况B：预测为负类（差解）
            % 不直接丢弃，而是记录判别分数最高的候选解作为"备用"
            if r == 1
                % 第一次尝试：无论好坏先记录下来
                d_i_max = d_i;    % 记录当前最高分数
                y_i     = candidate; % 记录当前最佳候选解
            elseif d_i_max < d_i
                % 后续尝试：如果新候选解的分数更高（更"不差"），则更新
                d_i_max = d_i;
                y_i     = candidate;
            end
        end
    end
    % 循环结束：R_max 次尝试都没有找到正类解，返回判别分数最高的候选解
end