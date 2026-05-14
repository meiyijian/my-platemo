function nrmse = KrigingNRMSE(X, y)
% KrigingNRMSE - K-fold GP 留一 NRMSE
%
% 用 K-fold 交叉验证拟合 Kriging（DACE），返回该目标在该样本集上的归一化 RMSE。
% 这是一个粗略但稳定的"可建模度"指标 —— NRMSE 越大表示该目标对当前样本越难拟合。
%
% 注：直接调用 K-RVEA 目录下的 dacefit / predictor（PlatEMO path 已含）。
%
% 输入：
%   X : N × D 决策变量
%   y : N × 1 单目标值
%
% 输出：
%   nrmse : 标量，归一化 RMSE，∈ [0, +∞)，相同尺度下越大越难

    [N, D] = size(X);
    K = 5;
    if N < 10
        % 样本太少，跳过交叉验证，直接返回 0（视为可建模），避免误判
        nrmse = 0;
        return;
    end
    K = min(K, N);

    % 简易 K-fold：均分索引
    idx = mod(0:N-1, K) + 1;     % 1..K 循环分配
    perm = randperm(N);
    fold = idx(perm);

    yhat = nan(N,1);
    theta0 = 5 .* ones(1, D);
    lob    = 1e-5 .* ones(1, D);
    upb    = 100  .* ones(1, D);

    for f = 1:K
        test_mask = (fold == f);
        train_mask = ~test_mask;
        if sum(train_mask) < D+1
            continue;   % 训练样本太少跳过
        end
        try
            dmodel = dacefit(X(train_mask,:), y(train_mask), ...
                'regpoly1', 'corrgauss', theta0, lob, upb);
            yhat(test_mask) = predictor(X(test_mask,:), dmodel);
        catch
            % GP 数值不稳定时，跳过该 fold
            continue;
        end
    end

    % 仅在 yhat 有效的部分计算 RMSE
    valid = ~isnan(yhat);
    if sum(valid) < 2
        nrmse = 0;
        return;
    end
    rmse  = sqrt(mean((yhat(valid) - y(valid)).^2));
    span  = max(y) - min(y);
    if span < 1e-12
        nrmse = 0;
    else
        nrmse = rmse / span;
    end
end
