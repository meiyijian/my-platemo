function indicator = UpdateInformation(flag, score, indicator)
% UpdateInformation - 更新指标轮盘的 Win Record
%
% 本函数实现 PIEA 风格的指标轮盘记录更新：
%   根据本代抽中的指标编号和整批新解反馈，更新窗口记录并重新计算抽样概率。
%   当前主程序即使未用该指标选择候选也会更新，因此记录不能直接解释为指标因果成功率。
%
% 滑动窗口机制：
%   使用 tau 步的滑动窗口记录最近的选择和成功情况
%   这样可让抽样概率随近期批次反馈变化；是否反映指标自身性能取决于反馈归因是否成立
%
% 输入：
%   flag      : 上一代选了哪个指标（1=SDE, 2=I_eps+, 3=MD）
%   score     : 本代整批新解的评分（0/1/2，使用 any 判定）
%               0 = 新解被原始 NDSort 支配（不好）
%               1 = 新解在 NDSort 第一层但被 NDSort_SDR 第一层排除（一般）
%               2 = 新解同时在 NDSort 和 NDSort_SDR 第一层（很好）
%   indicator : struct 数组（3×1）
%
% 输出：
%   indicator : 更新后的 struct 数组
%
% 来源：PIEA/UpdateInformation.m
%
% 示例：
%   如果本代抽中了 SDE 指标（flag=1），且整批反馈 score=2
%   则 SDE 的 Win_record 增加 1.0（score/2），其他指标增加 0

    %% ============ 更新 Choose_record（滑动窗口） ============
    % Choose_record 记录每个指标被选中的情况
    % 滑动窗口：移除最旧的记录，添加新的记录
    a = indicator(1).Choose_record;  a(1) = [];
    b = indicator(2).Choose_record;  b(1) = [];
    c = indicator(3).Choose_record;  c(1) = [];
    if flag == 1
        a = [a 1]; b = [b 0]; c = [c 0];
    elseif flag == 2
        a = [a 0]; b = [b 1]; c = [c 0];
    else
        a = [a 0]; b = [b 0]; c = [c 1];
    end
    indicator(1).Choose_record = a;
    indicator(2).Choose_record = b;
    indicator(3).Choose_record = c;

    %% ============ 更新 Win_record（滑动窗口） ============
    % Win_record 记录每个指标的"成功次数"
    % 成功程度由 score 决定：
    %   score = 0 → win_val = 0（失败）
    %   score = 1 → win_val = 0.5（一般）
    %   score = 2 → win_val = 1.0（很好）
    a = indicator(1).Win_record;  a(1) = [];
    b = indicator(2).Win_record;  b(1) = [];
    c = indicator(3).Win_record;  c(1) = [];
    if score == 0
        a = [a 0]; b = [b 0]; c = [c 0];
    else
        win_val = score / 2;   % score=1 → 0.5；score=2 → 1.0
        if flag == 1
            a = [a win_val]; b = [b 0]; c = [c 0];
        elseif flag == 2
            a = [a 0]; b = [b win_val]; c = [c 0];
        else
            a = [a 0]; b = [b 0]; c = [c win_val];
        end
    end
    indicator(1).Win_record = a;
    indicator(2).Win_record = b;
    indicator(3).Win_record = c;

    %% ============ 重新归一化概率 ============
    % Pw 原始量 = (Win_record 之和 + eps) / (Choose_record 之和 + eps)
    % eps 防止除零；若窗口内某指标从未被选择，分子分母均为 eps，其原始比率会等于 1。
    p = [(eps + sum(indicator(1).Win_record)) / (eps + sum(indicator(1).Choose_record)), ...
         (eps + sum(indicator(2).Win_record)) / (eps + sum(indicator(2).Choose_record)), ...
         (eps + sum(indicator(3).Win_record)) / (eps + sum(indicator(3).Choose_record))];
    % 归一化使三个概率之和为 1
    p = p / sum(p);
    indicator(1).Pw = p(1);
    indicator(2).Pw = p(2);
    indicator(3).Pw = p(3);
end
