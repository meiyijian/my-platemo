function Experts = TrainRelationExperts(PairBank, cfg)
% TrainRelationExperts - 为每个 PairBank 训练一个独立的 relation expert
%
% 与旧 TrainDualScaleNet 的根本区别：
%   旧版：硬编码两个网络 nets_F / nets_S，并且 hidden 用向量初始化 patternnet
%         实际产生了三隐藏层网络的 bug
%   本版：
%     1. 支持任意数量 PairBank，每个独立训练成一个 expert
%     2. hidden 强制 SCALAR
%     3. 每个 expert 报告 validation error, brier score, label stats
%     4. 若 pair 数过少 / 训练失败，该 expert.valid = false，主循环跳过
%     5. K_ens 默认 5，提高方差估计稳定性
%     6. 可选迁移初始化（cfg.useTransfer），但仅在 full→subset 维度匹配时使用
%
% 输入：
%   PairBank - 1×K 结构体数组，由 BuildPairBank_ParetoPBI 产生
%   cfg      - 训练配置：
%       .K_ens             集成大小，默认 5
%       .epochs            每个网络最大 epoch，默认 60
%       .trainRatio        训练集比例，默认 0.75
%       .useTransfer       是否做迁移初始化（同维度下），默认 true
%       .minTrainPairs     训练 pair 数下限，少于则跳过，默认 60
%
% 输出：
%   Experts - 1×K 结构体数组，每个元素：
%       .subset    目标索引
%       .valid     bool, 是否成功训练
%       .nets      1×K_ens cell，每个是 patternnet
%       .mp_struct mapminmax 归一化参数
%       .valError  验证集 0/1 错误率
%       .brier     验证集 brier score
%       .labelStats 三类标签数
%       .modelType 'pnn' (patternnet)

    if nargin < 2 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'K_ens', 5);
    cfg = setIfMissing(cfg, 'epochs', 60);
    cfg = setIfMissing(cfg, 'trainRatio', 0.75);
    cfg = setIfMissing(cfg, 'useTransfer', true);
    cfg = setIfMissing(cfg, 'minTrainPairs', 60);

    K = numel(PairBank);
    Experts = repmat(struct('subset', [], 'valid', false, 'nets', {{}}, ...
        'mp_struct', [], 'valError', 1, 'brier', 1, 'labelStats', [0 0 0], ...
        'modelType', 'pnn'), 1, K);

    % --- full expert 索引：默认认为最后一个 PairBank 是 full ---
    fullIdx = K;

    fullExpert = [];
    for k = 1:K
        pb = PairBank(k);
        Experts(k).subset = pb.subset;
        if isempty(pb.X) || size(pb.X, 1) < cfg.minTrainPairs
            Experts(k).valid = false;
            Experts(k).labelStats = [0 0 0];
            continue;
        end

        % 训练/验证集划分 + one-hot
        [Xtr, Ytr, Wtr, Xva, Yva] = stratifiedSplit(pb.X, pb.Y, pb.W, cfg.trainRatio);
        if isempty(Xtr) || isempty(Xva)
            Experts(k).valid = false;
            continue;
        end

        % 归一化
        [Xtr_n, mp] = mapminmax(Xtr');  Xtr_n = Xtr_n';
        Xva_n       = mapminmax('apply', Xva', mp)';

        Ytr_oh = label2onehot(Ytr);

        xDim   = size(Xtr_n, 2);
        hidden = chooseHidden(xDim);     % 强制 scalar
        K_ens  = max(1, cfg.K_ens);

        % 迁移源（如果存在且维度匹配）
        initFromNets = [];
        if cfg.useTransfer && k ~= fullIdx && ~isempty(fullExpert) && fullExpert.valid
            % 维度必须完全匹配，否则放弃迁移
            if size(fullExpert.nets{1}.IW{1}, 2) == xDim
                initFromNets = fullExpert.nets;
            end
        end

        nets = trainBag(Xtr_n, Ytr_oh, Wtr, hidden, K_ens, initFromNets, cfg.epochs);

        % 验证
        [valError, brier] = evalEnsemble(nets, Xva_n, Yva);

        Experts(k).valid     = any(~cellfun(@isempty, nets));
        Experts(k).nets      = nets;
        Experts(k).mp_struct = mp;
        Experts(k).valError  = valError;
        Experts(k).brier     = brier;
        Experts(k).labelStats = [sum(pb.Y==+1), sum(pb.Y==0), sum(pb.Y==-1)];

        % 记录 full expert 用于后续 subset 的迁移
        if k == fullIdx && Experts(k).valid
            fullExpert = Experts(k);
        end
    end
end

% =========================================================
%  局部工具
% =========================================================

function h = chooseHidden(xDim)
% 强制 scalar 隐藏层节点数
    h = round(0.5 * xDim);
    if h < 8,  h = 8;  end
    if h > 24, h = 24; end
    h = double(h);  % patternnet 要求 numeric scalar
end

function [Xtr, Ytr, Wtr, Xva, Yva] = stratifiedSplit(X, Y, W, ratio)
% 分层采样训练 / 验证集
    Y = Y(:); W = W(:);
    classes = [-1, 0, 1];
    trIdx = []; vaIdx = [];
    for c = classes
        idx = find(Y == c);
        if isempty(idx), continue; end
        idx = idx(randperm(numel(idx)));
        n = numel(idx);
        cut = max(1, round(ratio * n));
        if n == 1
            % 太少：全放训练
            trIdx = [trIdx; idx]; %#ok<AGROW>
        else
            trIdx = [trIdx; idx(1:cut)]; %#ok<AGROW>
            vaIdx = [vaIdx; idx(cut+1:end)]; %#ok<AGROW>
        end
    end
    if isempty(trIdx) || isempty(vaIdx)
        Xtr = []; Ytr = []; Wtr = []; Xva = []; Yva = []; return;
    end
    trIdx = trIdx(randperm(numel(trIdx)));
    vaIdx = vaIdx(randperm(numel(vaIdx)));
    Xtr = X(trIdx, :); Ytr = Y(trIdx); Wtr = W(trIdx);
    Xva = X(vaIdx, :); Yva = Y(vaIdx);
end

function oh = label2onehot(Y)
% +1 -> [1,0,0]; 0 -> [0,1,0]; -1 -> [0,0,1]
    n = numel(Y);
    oh = zeros(n, 3);
    oh(Y == +1, 1) = 1;
    oh(Y ==  0, 2) = 1;
    oh(Y == -1, 3) = 1;
end

function nets = trainBag(X, Yoh, W, hidden, K, initFromNets, epochs)
    n = size(X, 1);
    nets = cell(1, K);
    if n < 5
        K = 1;
    end
    nBag = max(2, ceil(0.70 * n));
    for i = 1:K
        if K == 1 || n <= nBag
            sel = 1:n;
        else
            sel = randperm(n, nBag);
        end
        Xi  = X(sel, :);
        Yi  = Yoh(sel, :);
        Wi  = W(sel);

        net = patternnet(hidden);   % hidden 是 scalar，确保单隐藏层
        net.trainParam.showWindow      = 0;
        net.trainParam.showCommandLine = 0;
        net.trainParam.epochs          = epochs;
        net.trainParam.max_fail        = 6;
        net.trainParam.min_grad        = 1e-6;
        net.divideParam.trainRatio     = 0.8;
        net.divideParam.valRatio       = 0.2;
        net.divideParam.testRatio      = 0;
        net.performParam.regularization = 0.05;  % 轻度 L2 正则化

        net = configure(net, Xi', Yi');

        % 迁移初始化（仅在维度匹配时）
        if ~isempty(initFromNets) && i <= numel(initFromNets) && ~isempty(initFromNets{i})
            src = initFromNets{i};
            try
                if isequal(size(net.IW{1}), size(src.IW{1})) ...
                    && isequal(size(net.LW{2,1}), size(src.LW{2,1}))
                    net.IW{1}   = src.IW{1};
                    net.b{1}    = src.b{1};
                    net.LW{2,1} = src.LW{2,1};
                    net.b{2}    = src.b{2};
                end
            catch
                % skip
            end
        end

        try
            if any(Wi ~= 1)
                % 加权训练
                net.performFcn = 'mse';
                net = train(net, Xi', Yi', [], [], Wi');
            else
                net = train(net, Xi', Yi');
            end
        catch
            try
                net = patternnet(hidden);
                net.trainParam.showWindow = 0;
                net.trainParam.showCommandLine = 0;
                net.trainParam.epochs = max(20, floor(epochs/2));
                net = train(net, Xi', Yi');
            catch
                net = [];
            end
        end

        nets{i} = net;
    end
end

function [errRate, brier] = evalEnsemble(nets, Xva, Yva)
    if isempty(Xva), errRate = 1; brier = 1; return; end
    valid = ~cellfun(@isempty, nets);
    if ~any(valid), errRate = 1; brier = 1; return; end
    nets_v = nets(valid);
    K = numel(nets_v);

    % 平均输出概率
    avgOut = zeros(size(Xva, 1), 3);
    for kk = 1:K
        try
            out = nets_v{kk}(Xva')';   % n×3
            % 防止负数，做 softmax-like 修正
            out = max(out, 0);
            sumOut = sum(out, 2);
            sumOut(sumOut < 1e-12) = 1;
            out = out ./ sumOut;
            avgOut = avgOut + out;
        catch
            % skip this net
        end
    end
    avgOut = avgOut / K;

    [~, pIdx] = max(avgOut, [], 2);
    pred = zeros(size(pIdx));
    pred(pIdx == 1) = +1;
    pred(pIdx == 2) =  0;
    pred(pIdx == 3) = -1;
    errRate = mean(pred ~= Yva);

    % Brier score: mean ||p - one_hot(y)||^2
    Y_oh = zeros(numel(Yva), 3);
    Y_oh(Yva == +1, 1) = 1;
    Y_oh(Yva ==  0, 2) = 1;
    Y_oh(Yva == -1, 3) = 1;
    brier = mean(sum((avgOut - Y_oh).^2, 2));
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
