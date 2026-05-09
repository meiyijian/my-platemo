function indicator = UpdateInformation(flag, score, indicator)
% UpdateInformation - 更新指标轮盘的 Win Record（来自 PIEA）
%
% 滑动窗口（tau 步）内统计每个指标"被选中次数"和"被选中后真实评估的成功度"
% 用 (Win+eps)/(Choose+eps) 作为下一代的概率
%
% 输入：
%   flag      : 上一代选了哪个指标（1=SDE, 2=I_eps+, 3=MD）
%   score     : 上一代结果的评分（0/1/2）
%               0 = 新解被原始 NDSort 支配
%               1 = 新解在 NDSort 第一层但被 NDSort_SDR 第一层排除
%               2 = 新解同时在 NDSort 和 NDSort_SDR 第一层
%   indicator : struct 数组（3×1）
%
% 输出：
%   indicator : 更新后的 struct 数组
%
% 来源：PIEA/UpdateInformation.m

    %% 滑动 Choose_record
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

    %% 滑动 Win_record
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

    %% 重新归一化概率
    p = [(eps + sum(indicator(1).Win_record)) / (eps + sum(indicator(1).Choose_record)), ...
         (eps + sum(indicator(2).Win_record)) / (eps + sum(indicator(2).Choose_record)), ...
         (eps + sum(indicator(3).Win_record)) / (eps + sum(indicator(3).Choose_record))];
    p = p / sum(p);
    indicator(1).Pw = p(1);
    indicator(2).Pw = p(2);
    indicator(3).Pw = p(3);
end
