function out = ObjectiveSurrogate(mode, varargin)
% 轻量目标回归器（Lightweight Objective Surrogate, LOS）
% 创新点 2 的实现：用 Gaussian RBF 同时回归 M 维目标值
%
% 用途：
%   推理阶段 model_select_DO 需要 f̂(x_new) 作为关系网络的软先验输入。
%   archive 中的 (decs, objs) 用作训练数据，零额外评估代价。
%
% 接口：
%   LOS = ObjectiveSurrogate('train', X, F)
%       X : N×D 决策变量
%       F : N×M 目标值
%       LOS: 训练好的模型结构体（含 X_train, W, sigma）
%
%   F_hat = ObjectiveSurrogate('predict', LOS, X_new)
%       X_new: K×D 新候选解
%       F_hat: K×M 预测目标值
%
% 设计要点：
%   - 一个 RBF 模型同时输出 M 维（共享核矩阵，节省计算）
%   - sigma = mean(pdist(X)) 经验设置（常用启发式）
%   - 加 1e-6*I 正则化避免奇异
%   - archive 超过 500 时下采样到 500（控制 O(N³) 开销）

    switch mode
    case 'train'
        X = varargin{1};
        F = varargin{2};

        % 控制规模：超过 500 时随机下采样
        N = size(X, 1);
        if N > 500
            sel = randperm(N, 500);
            X = X(sel, :);
            F = F(sel, :);
            N = 500;
        end

        % 决策变量距离矩阵
        D_pair = pdist2(X, X);

        % sigma 启发式：所有点对距离均值（pdist 转 squareform 等价 mean(D_pair)/2 但稳定一些）
        sigma = mean(D_pair(D_pair > 0));
        if sigma <= 0 || isnan(sigma)
            sigma = 1.0;     % 兜底：所有点重合时
        end

        % 高斯核矩阵
        K = exp(-D_pair.^2 / (sigma^2));
        K = K + 1e-6 * eye(N);   % 正则化

        % M 维同时回归（共享核矩阵）
        W = K \ F;     % N×M

        out = struct('X_train', X, 'W', W, 'sigma', sigma);

    case 'predict'
        LOS    = varargin{1};
        X_new  = varargin{2};

        % 计算新点到训练点的距离
        D_new = pdist2(X_new, LOS.X_train);
        K_new = exp(-D_new.^2 / (LOS.sigma^2));

        % 预测：K_new (K×N) × W (N×M) = K×M
        out = K_new * LOS.W;

    otherwise
        error('ObjectiveSurrogate: unknown mode %s', mode);
    end
end
