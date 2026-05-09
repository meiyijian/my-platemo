function DebugLog(gen, FE, maxFE, p_err, flag, score, indicator, Lp, n_eval)
% DebugLog - 打印 REMO_new2_PIEA3 主循环的调试信息
%
% 同时输出到：
%   1) 控制台（可能被 PlatEMO 的 clc 清掉，仅供观察）
%   2) 日志文件 REMO_new2_PIEA3_debug.log（永久保留，推荐看这个）
%      文件位置：与 REMO_new2_PIEA3.m 同目录
%
% 用于诊断关系网络是否在拖累整体性能、轮盘是否收敛、
% 各性能指标的胜率分布等。
%
% 输入：
%   gen       : 当前代数（从 1 开始）
%   FE        : 已使用的真实评估次数
%   maxFE     : 总评估预算
%   p_err     : 关系网络在测试集上的错误率（0~1，越低越好）
%                - p_err 持续 > 0.3 → 关系网络在 M 大时几乎是噪声
%                - p_err 早期高、后期低 → 关系网络逐渐学到信号
%   flag      : 当代轮盘选中的指标 (1=SDE, 2=I_eps+, 3=MD)
%   score     : NDSort_SDR 反馈分数
%                - 0 = 新解被支配（差）
%                - 1 = 进入 NDSort 第一层（中）
%                - 2 = 进入 NDSort_SDR 第一层（极优）
%   indicator : 轮盘状态结构体 (3×1)，含 Pw 字段
%   Lp        : 当代估计的 PF 形状参数
%   n_eval    : 本代真实评估的解数量

    indicator_names = {'SDE   ', 'I_eps+', 'MD    '};
    score_labels    = {'差  ', '中  ', '极优'};

    flag_name  = indicator_names{flag};
    score_name = score_labels{score + 1};

    Pw_SDE = indicator(1).Pw;
    Pw_eps = indicator(2).Pw;
    Pw_MD  = indicator(3).Pw;

    %% 拼接日志字符串
    msg = sprintf(['[Gen %3d | FE=%4d/%4d] p_err=%.3f | 指标=%s | score=%d(%s) | ', ...
                   'Pw=[SDE=%.3f I+=%.3f MD=%.3f] | Lp=%.2f | n_eval=%d\n'], ...
        gen, FE, maxFE, p_err, flag_name, score, score_name, ...
        Pw_SDE, Pw_eps, Pw_MD, Lp, n_eval);

    %% 1) 输出到控制台（PlatEMO 可能 clc 清掉，但还是打一份）
    fprintf('%s', msg);

    %% 2) 同时追加写入到日志文件（永久保留）
    log_path = fullfile(fileparts(mfilename('fullpath')), 'REMO_new2_PIEA3_debug.log');
    fid = fopen(log_path, 'a');
    if fid ~= -1
        fprintf(fid, '%s', msg);
        fclose(fid);
    end
end
