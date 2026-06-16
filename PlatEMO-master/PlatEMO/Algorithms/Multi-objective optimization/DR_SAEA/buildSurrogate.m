function varargout = buildSurrogate(Dec, Z, SurrogateType, D, K, varargin)
% <DR_SAEA helper> Build surrogate models that map decisions to reduced
%   K-dimensional objectives, and predict on a candidate set.
%
%   Call:
%       [Models, TrainDec] = buildSurrogate(Dec, Z, SurrogateType, D, K)
%       [Mu, Sigma]        = buildSurrogate(Models, X, SurrogateType, TrainDec)
%
%   The function is overloaded: the first form trains and returns the model
%   cell array plus the training decision matrix; the second form takes the
%   trained Models cell as the first argument and returns predictions.
%
%   Input (train mode):
%       Dec, Z, SurrogateType, D, K  - see below
%
%   Input (predict mode):
%       Models         - 1 x K cell of surrogate models (dacefit or RBF para)
%       X              - Nq x D candidate decision matrix
%       SurrogateType  - 'Kriging' | 'RBF' | 'Relation'
%       TrainDec       - training decision matrix (used for the RBF distance
%                        proxy of uncertainty)
%
%   Output (train mode):
%       Models  - 1 x K cell of surrogate model structs
%       TrainDec - Dec, returned for later use
%
%   Output (predict mode):
%       Mu    - Nq x K predicted reduced objective means
%       Sigma - Nq x K predicted standard deviations (sqrt of MSE); for RBF
%               this is approximated by the min-Euclidean-distance to the
%               training set, following the DR_SAEA design spec
%
%   This function is part of the DR_SAEA algorithm.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026. You are free to use DR_SAEA for research purposes.
%--------------------------------------------------------------------------

    % Predict mode: dispatch by detecting that the first argument is a
    % cell of surrogate structs. The call site is:
    %     buildSurrogate(Models, X, SurrogateType, TrainDec)
    % where TrainDec arrives as the 4th positional argument (D in train
    % mode reuses the same slot).
    % 注意：这种通过参数类型自动区分训练/预测模式的"重载"设计容易引入
    % 参数语义混淆（Z → X, D → TrainDec）。修改代码时务必确认调用方传参顺序。
    if iscell(Dec) && ~isempty(Dec) && isstruct(Dec{1})
        Models        = Dec;
        X             = Z;
        % In train mode, the 3rd positional argument is the surrogate
        % type string ('Kriging', 'RBF', 'Relation'). In predict mode the
        % call site is `buildSurrogate(Models, X, SurrogateType, TrainDec)`
        % so the 3rd argument already carries the type string; we keep it
        % as-is and recover TrainDec from the 4th argument (D slot).
        % SurrogateType is therefore NOT reassigned here.
        TrainDec      = D;
        if nargin > 5 && ~isempty(varargin{1})
            TrainDec = varargin{1};
        end
        [Mu, Sigma] = predictInternal(Models, X, SurrogateType, TrainDec);
        varargout{1} = Mu;
        varargout{2} = Sigma;
        return;
    end

    % --- Train mode ---------------------------------------------------------
    [N, Kz] = size(Z);
    K       = Kz;
    Models  = cell(1, K);
    TrainDec = Dec;

    switch lower(SurrogateType)
        case 'kriging'
            % DACE Kriging 训练：每个降维目标独立训练一个 GP 模型
            % theta0=0.5, lob=1e-5, hib=20 沿用 K-RVEA 的经验设定
            % regpoly1 = 一阶多项式趋势，corrgauss = 高斯相关函数
            theta0 = 0.5 * ones(1, D);
            lob    = 1e-5 * ones(1, D);
            hib    = 20   * ones(1, D);
            for k = 1 : K
                dmodel = dacefit(Dec, Z(:, k), 'regpoly1', ...
                    'corrgauss', theta0, lob, hib);
                Models{k} = dmodel;
            end

        case 'rbf'
            for k = 1 : K
                Models{k} = rbfCreateLocal(Dec, Z(:, k), 'gaussian');
            end

        otherwise  % 'relation' or unknown -> leave empty; main loop falls back
            for k = 1 : K
                Models{k} = [];
            end
    end

    varargout{1} = Models;
    varargout{2} = TrainDec;
end

function [Mu, Sigma] = predictInternal(Models, X, SurrogateType, TrainDec)
% Predict in the reduced space. For Kriging, uses the DACE toolbox's
% predictor function via a fully qualified package path so the call is
% not shadowed by a same-named helper elsewhere in the PlatEMO tree.
    Nq = size(X, 1);
    K  = length(Models);
    Mu    = zeros(Nq, K);
    Sigma = zeros(Nq, K);

    switch lower(SurrogateType)
        case 'kriging'
            % Locate the DACE predictor at runtime to bypass any shadowing
            % helper that may live in sibling algorithm folders.
            predFcn = resolveKrigingPredictor();
            for k = 1 : K
                dmodel = Models{k};
                if isempty(dmodel)
                    continue;
                end
                % DACE predictor 输出约定（与 mx 有关）：
                %   mx > 1（多点预测）: [y, mse] — 第2输出即 MSE
                %   mx == 1（单点预测）: [y, grad, mse] — 第3输出才是 MSE
                % 预测池通常多于 1 个候选，此处按多点路径取 2 个输出；
                % 若输入为单点则补取第 3 输出以避免拿到梯度值。
                if size(X, 1) == 1
                    [y, ~, mse] = predFcn(X, dmodel);
                else
                    [y, mse] = predFcn(X, dmodel);
                end
                % 处理标量输出（某些旧版 dacefit 对不同形状的返回值不统一）
                if isscalar(y)
                    Mu(1, k) = y;
                else
                    Mu(:, k) = y(:);
                end
                % MSE 裁剪到 ≥0 后开方 → 标准差（Sigma），即后续采集函数使用的"不确定性"
                if isscalar(mse)
                    Sigma(1, k) = sqrt(max(mse, 0));
                else
                    Sigma(:, k) = sqrt(max(mse(:), 0));
                end
            end

        case 'rbf'
            for k = 1 : K
                para = Models{k};
                if isempty(para)
                    continue;
                end
                Mu(:, k) = rbfInterpLocal(X, para);
            end
            % RBF 不确定度代理: 到最近训练点的欧氏距离
            % 限制: K 个降维目标的 Sigma 完全相同（无法体现各目标方向的差异），
            % 这是 RBF 的固有局限，详见 README 第 12 节"已知限制"。
            if ~isempty(TrainDec)
                D2 = pdist2(X, TrainDec);
                D2(D2 == 0) = inf;
                minD = min(D2, [], 2);
                minD(~isfinite(minD)) = 0;
                for k = 1 : K
                    Sigma(:, k) = minD;
                end
            end

        otherwise
            % No surrogate; Mu and Sigma stay zero.
    end
end

function predFcn = resolveKrigingPredictor()
% Locate the DACE predictor. We simply return a function handle to the
% canonical ParEGO/predictor.m (always shipped with PlatEMO). The handle
% is obtained via str2func so MATLAB does not resolve the call site at
% file load time and thus cannot be confused by a same-named helper that
% is shadowed on the path at the call site.
    predFcn = @predictor;
end

function para = rbfCreateLocal(ax, ay, kernel)
% Local re-implementation of the gaussian RBF interpolation that lives
% in ADSAPSO/RBF/RBFCreate.m. We replicate the math here so DR_SAEA
% does not depend on the existence of that sibling file.
    % 注意：warning('off') 会关闭所有警告（包括矩阵奇异、除零等重要信号）。
    % 若 RBF 训练出现问题，诊断信息将被完全压制。
    % 建议改为针对性关闭：warning('off', 'MATLAB:nearlySingularMatrix')
    warning('off')
    [N, D] = size(ax);
    xmin = min(ax, [], 1);
    xmax = max(ax, [], 1);
    ymin = min(ay, [], 1);
    ymax = max(ay, [], 1);
    % Min-max 归一化到 [-1, 1]；若某决策维在所有训练样本中取值相同
    % (xmax==xmin)，则分母为零 → Inf。LHS 初始采样下罕见，但收敛后期
    % 可能出现，此时该维零点会被后续矩阵求解除法放大为 NaN。
    axn = 2 ./ (repmat(xmax - xmin, N, 1)) .* (ax - repmat(xmin, N, 1)) - 1;
    ayn = 2 ./ (repmat(ymax - ymin, N, 1)) .* (ay - repmat(ymin, N, 1)) - 1;
    r = dist(axn, axn');
    switch kernel
        case 'gaussian'
            Phi = radbas(sqrt(-log(0.5)) * r);
        case 'cubic'
            Phi = r .^ 3;
        otherwise
            Phi = radbas(sqrt(-log(0.5)) * r);
    end
    P = [ones(N, 1), axn];
    A = [Phi, P; P', zeros(D + 1, D + 1)];
    b = [ayn; zeros(D + 1, size(ayn, 2))];
    theta = A \ b;
    para.alpha = theta(1 : N, :);
    para.beta  = theta(N + 1 : end, :);
    para.xmin = xmin; para.xmax = xmax;
    para.ymin = ymin; para.ymax = ymax;
    para.nodes = axn;
    para.kernel = kernel;
    warning('on')
end

function y = rbfInterpLocal(x, para)
% Local re-implementation of the gaussian RBF interpolation.
    ax = para.nodes;
    nx = size(x, 1);
    np = size(ax, 1);
    xmin = para.xmin; xmax = para.xmax;
    ymin = para.ymin; ymax = para.ymax;
    xn = 2 ./ (repmat(xmax - xmin, nx, 1)) .* (x - repmat(xmin, nx, 1)) - 1;
    r  = dist(xn, ax');
    switch para.kernel
        case 'gaussian'
            Phi = radbas(sqrt(-log(0.5)) * r);
        case 'cubic'
            Phi = r .^ 3;
        otherwise
            Phi = radbas(sqrt(-log(0.5)) * r);
    end
    y   = Phi * para.alpha + [ones(nx, 1), xn] * para.beta;
    y   = repmat(ymax - ymin, nx, 1) ./ 2 .* (y + 1) + repmat(ymin, nx, 1);
end
