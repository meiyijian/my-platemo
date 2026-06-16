function Experts = TrainRelationExperts_SGDA(PairBank, cfg)
% TrainRelationExperts_SGDA - Train independent full/group relation experts.
%
% The last PairBank entry is treated as the full expert. Earlier entries are
% group experts and their labels/outputs are local to their objective group.

    if nargin < 2 || isempty(cfg), cfg = struct(); end
    cfg = setIfMissing(cfg, 'K_ens', 5);
    cfg = setIfMissing(cfg, 'epochs', 60);
    cfg = setIfMissing(cfg, 'trainRatio', 0.75);
    cfg = setIfMissing(cfg, 'useTransfer', true);
    cfg = setIfMissing(cfg, 'minTrainPairs', 60);
    cfg = setIfMissing(cfg, 'meta', []);

    K = numel(PairBank);
    Experts = repmat(emptyExpert(), 1, K);
    fullIdx = K;
    fullExpert = [];

    % Train full first so group experts can optionally reuse compatible
    % weights. Output order is unchanged: full still remains the last entry.
    order = [fullIdx, 1:max(0, fullIdx-1)];
    for kk = 1:numel(order)
        k = order(kk);
        pb = PairBank(k);
        e = emptyExpert();
        e.subset = pb.subset;
        e.expertType = ternary(k == fullIdx, 'full', 'group');
        e.groupIndex = k;

        if ~isempty(cfg.meta) && numel(cfg.meta) >= k
            e.groupDifficulty = cfg.meta(k).groupDifficulty;
            e.groupReliability = cfg.meta(k).groupReliability;
            e.isEasyGroup = cfg.meta(k).isEasyGroup;
            e.expertType = cfg.meta(k).expertType;
            e.groupIndex = cfg.meta(k).groupIndex;
        end

        if isempty(pb.X) || size(pb.X, 1) < cfg.minTrainPairs
            e.valid = false;
            e.labelStats = labelStats(pb.Y);
            Experts(k) = e;
            continue;
        end

        [Xtr, Ytr, Wtr, Xva, Yva] = stratifiedSplit(pb.X, pb.Y, pb.W, cfg.trainRatio);
        if isempty(Xtr) || isempty(Xva)
            e.valid = false;
            e.labelStats = labelStats(pb.Y);
            Experts(k) = e;
            continue;
        end

        [XtrN, mp] = mapminmax(Xtr');
        XtrN = XtrN';
        XvaN = mapminmax('apply', Xva', mp)';
        YtrOH = label2onehot(Ytr);

        xDim = size(XtrN, 2);
        hidden = chooseHidden(xDim);
        initFromNets = [];
        if cfg.useTransfer && k ~= fullIdx && ~isempty(fullExpert) && fullExpert.valid
            try
                if ~isempty(fullExpert.nets) && ~isempty(fullExpert.nets{1}) && ...
                   size(fullExpert.nets{1}.IW{1}, 2) == xDim
                    initFromNets = fullExpert.nets;
                end
            catch
                initFromNets = [];
            end
        end

        nets = trainBag(XtrN, YtrOH, Wtr, hidden, max(1, cfg.K_ens), initFromNets, cfg.epochs);
        [valError, brier] = evalEnsemble(nets, XvaN, Yva);

        e.valid = any(~cellfun(@isempty, nets));
        e.nets = nets;
        e.mp_struct = mp;
        e.valError = valError;
        e.brier = brier;
        e.labelStats = labelStats(pb.Y);
        Experts(k) = e;

        if k == fullIdx && e.valid
            fullExpert = e;
        end
    end
end

function e = emptyExpert()
    e = struct('subset', [], 'valid', false, 'nets', {{}}, ...
        'mp_struct', [], 'valError', 1, 'brier', 1, ...
        'labelStats', [0 0 0], 'modelType', 'pnn', ...
        'expertType', 'group', 'groupIndex', 0, ...
        'groupDifficulty', 1, 'groupReliability', 0, ...
        'isEasyGroup', false);
end

function h = chooseHidden(xDim)
    h = round(0.5 * xDim);
    h = max(8, min(24, h));
    h = double(h);
end

function [Xtr, Ytr, Wtr, Xva, Yva] = stratifiedSplit(X, Y, W, ratio)
    Y = Y(:);
    W = W(:);
    classes = [-1, 0, 1];
    trIdx = [];
    vaIdx = [];
    for c = classes
        idx = find(Y == c);
        if isempty(idx), continue; end
        idx = idx(randperm(numel(idx)));
        n = numel(idx);
        cut = max(1, round(ratio*n));
        if n == 1
            trIdx = [trIdx; idx]; %#ok<AGROW>
        else
            trIdx = [trIdx; idx(1:cut)]; %#ok<AGROW>
            vaIdx = [vaIdx; idx(cut+1:end)]; %#ok<AGROW>
        end
    end
    if isempty(trIdx) || isempty(vaIdx)
        Xtr = [];
        Ytr = [];
        Wtr = [];
        Xva = [];
        Yva = [];
        return;
    end
    trIdx = trIdx(randperm(numel(trIdx)));
    vaIdx = vaIdx(randperm(numel(vaIdx)));
    Xtr = X(trIdx, :);
    Ytr = Y(trIdx);
    Wtr = W(trIdx);
    Xva = X(vaIdx, :);
    Yva = Y(vaIdx);
end

function oh = label2onehot(Y)
    n = numel(Y);
    oh = zeros(n, 3);
    oh(Y == +1, 1) = 1;
    oh(Y ==  0, 2) = 1;
    oh(Y == -1, 3) = 1;
end

function nets = trainBag(X, Yoh, W, hidden, K, initFromNets, epochs)
    n = size(X, 1);
    if n < 5
        K = 1;
    end
    nets = cell(1, K);
    nBag = max(2, ceil(0.70*n));
    for i = 1:K
        if K == 1 || n <= nBag
            sel = 1:n;
        else
            sel = randperm(n, nBag);
        end
        Xi = X(sel, :);
        Yi = Yoh(sel, :);
        Wi = W(sel);

        try
            net = patternnet(hidden);
            net.trainParam.showWindow = 0;
            net.trainParam.showCommandLine = 0;
            net.trainParam.epochs = epochs;
            net.trainParam.max_fail = 6;
            net.trainParam.min_grad = 1e-6;
            net.divideParam.trainRatio = 0.8;
            net.divideParam.valRatio = 0.2;
            net.divideParam.testRatio = 0;
            net.performParam.regularization = 0.05;
            net = configure(net, Xi', Yi');
        catch
            nets{i} = [];
            continue;
        end

        if ~isempty(initFromNets) && i <= numel(initFromNets) && ~isempty(initFromNets{i})
            src = initFromNets{i};
            try
                if isequal(size(net.IW{1}), size(src.IW{1})) && ...
                   isequal(size(net.LW{2,1}), size(src.LW{2,1}))
                    net.IW{1} = src.IW{1};
                    net.b{1} = src.b{1};
                    net.LW{2,1} = src.LW{2,1};
                    net.b{2} = src.b{2};
                end
            catch
            end
        end

        try
            if any(Wi ~= 1)
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
    if isempty(Xva)
        errRate = 1;
        brier = 1;
        return;
    end
    valid = ~cellfun(@isempty, nets);
    if ~any(valid)
        errRate = 1;
        brier = 1;
        return;
    end
    netsV = nets(valid);
    avgOut = zeros(size(Xva, 1), 3);
    nGood = 0;
    for kk = 1:numel(netsV)
        try
            out = netsV{kk}(Xva')';
            out = normalizeProb(out);
            avgOut = avgOut + out;
            nGood = nGood + 1;
        catch
        end
    end
    if nGood == 0
        errRate = 1;
        brier = 1;
        return;
    end
    avgOut = avgOut / nGood;
    [~, pIdx] = max(avgOut, [], 2);
    pred = zeros(size(pIdx));
    pred(pIdx == 1) = +1;
    pred(pIdx == 2) =  0;
    pred(pIdx == 3) = -1;
    errRate = mean(pred ~= Yva);

    Yoh = label2onehot(Yva);
    brier = mean(sum((avgOut - Yoh).^2, 2));
end

function P = normalizeProb(P)
    P = max(P, 0);
    s = sum(P, 2);
    s(s < 1e-12) = 1;
    P = P ./ s;
end

function s = labelStats(Y)
    if isempty(Y)
        s = [0 0 0];
    else
        s = [sum(Y == +1), sum(Y == 0), sum(Y == -1)];
    end
end

function out = ternary(cond, a, b)
    if cond
        out = a;
    else
        out = b;
    end
end

function cfg = setIfMissing(cfg, name, val)
    if ~isfield(cfg, name) || isempty(cfg.(name))
        cfg.(name) = val;
    end
end
