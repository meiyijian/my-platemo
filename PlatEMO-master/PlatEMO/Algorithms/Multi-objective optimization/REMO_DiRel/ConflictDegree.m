function conf = ConflictDegree(PopObj)
% ConflictDegree - 模块①辅助：Spearman 冲突度
%
% 对每个目标计算 (1 - |ρ|) 在其它目标上的平均。
%   - 与其它目标负相关或低相关的目标，冲突度高（向"对立"方向走）
%   - 与其它目标高度正相关的目标，冲突度低（信息冗余）
%
% 不归一化目标值——Spearman 秩相关本身对单调变换不敏感，所以无需预处理。
%
% 输入：
%   PopObj : N × M 目标值矩阵
%
% 输出：
%   conf : M × 1 冲突度，∈ [0,1]

    M = size(PopObj, 2);
    conf = zeros(M, 1);

    if M < 2
        return;
    end

    % Spearman 秩相关；MATLAB 内置 corr 支持 'type','Spearman'
    rho = corr(PopObj, 'type', 'Spearman');
    rho(isnan(rho)) = 0;     % 退化常数列时置 0
    rho_abs = abs(rho);

    for j = 1:M
        others = setdiff(1:M, j);
        conf(j) = mean(1 - rho_abs(j, others));
    end
end
