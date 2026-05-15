function DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens)
%TrainDualScaleNet - Budgeted dual-scale ensemble training.
%
% Keeps the original idea:
%   - net_F learns the full-objective relation
%   - net_S learns the easy-subset relation and is warm-started from net_F
% But the ensemble size and epoch budget are reduced to prevent runtime blowup.

    [TrainIn_F, TrainOut_F, TestIn_F, TestOut_F] = DataProcess_DiRel(XX_F, YY_F);
    [TrainIn_F_nor, mp_struct_F] = mapminmax(TrainIn_F');
    TrainIn_F_nor = TrainIn_F_nor';
    TrainOut_F_oh  = onehotconv_DiRel(TrainOut_F, 1);

    xDim_F = size(TrainIn_F_nor, 2);
    nets_F = trainBagEnsemble(TrainIn_F_nor, TrainOut_F_oh, xDim_F, K_ens, [], 60);
    p_err_F = testEnsemble(nets_F, TestIn_F, TestOut_F, mp_struct_F);

    [TrainIn_S, TrainOut_S, TestIn_S, TestOut_S] = DataProcess_DiRel(XX_S, YY_S);
    [TrainIn_S_nor, mp_struct_S] = mapminmax(TrainIn_S');
    TrainIn_S_nor = TrainIn_S_nor';
    TrainOut_S_oh  = onehotconv_DiRel(TrainOut_S, 1);

    xDim_S = size(TrainIn_S_nor, 2);
    nets_S = trainBagEnsemble(TrainIn_S_nor, TrainOut_S_oh, xDim_S, K_ens, nets_F, 30);
    p_err_S = testEnsemble(nets_S, TestIn_S, TestOut_S, mp_struct_S);

    DualNet = struct();
    DualNet.nets_F      = nets_F;
    DualNet.nets_S      = nets_S;
    DualNet.mp_struct_F = mp_struct_F;
    DualNet.mp_struct_S = mp_struct_S;
    DualNet.p_err_F     = p_err_F;
    DualNet.p_err_S     = p_err_S;
end

function nets = trainBagEnsemble(X, Y_oh, xDim, K, initFromNets, epochs)
    nSample = size(X, 1);
    if nSample < 5
        K = 1;
    end
    K = max(1, K);
    hidden = max(4, min([ceil(xDim*1.25), xDim, ceil(xDim/2)], 24));
    if isempty(hidden)
        hidden = max(4, ceil(xDim/2));
    end
    nBag   = max(2, ceil(0.70 * nSample));
    nets   = cell(1, K);

    for i = 1:K
        if K == 1 || nSample <= nBag
            sel = 1:nSample;
        else
            sel = randperm(nSample, nBag);
        end
        Xi = X(sel, :);
        Yi = Y_oh(sel, :);

        net = patternnet(hidden);
        net.trainParam.showWindow      = 0;
        net.trainParam.showCommandLine = 0;
        net.trainParam.epochs          = epochs;
        net.trainParam.max_fail        = 6;
        net.trainParam.min_grad        = 1e-6;
        net.divideParam.trainRatio     = 0.8;
        net.divideParam.valRatio       = 0.2;
        net.divideParam.testRatio      = 0;

        net = configure(net, Xi', Yi');
        if ~isempty(initFromNets) && i <= numel(initFromNets) && ~isempty(initFromNets{i})
            net = TransferFineTune(net, initFromNets{i});
        end

        try
            net = train(net, Xi', Yi');
        catch
            net = patternnet(hidden);
            net.trainParam.showWindow      = 0;
            net.trainParam.showCommandLine = 0;
            net.trainParam.epochs          = max(20, floor(epochs/2));
            net.trainParam.max_fail        = 6;
            try
                net = train(net, Xi', Yi');
            catch
                net = [];
            end
        end
        nets{i} = net;
    end
end

function p_err = testEnsemble(nets, TestIn, TestOut, mp_struct)
    if isempty(TestIn)
        p_err = 1;
        return;
    end
    TestIn_nor = mapminmax('apply', TestIn', mp_struct)';
    pred = ensemblePredict(nets, TestIn_nor);
    p_err = sum(pred ~= TestOut) / max(size(pred, 1), 1);
end

function pred = ensemblePredict(nets, X)
    N = size(X, 1);
    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    if isempty(nets_v)
        pred = zeros(N, 1);
        return;
    end

    K = numel(nets_v);
    votes = zeros(N, K);
    for i = 1:K
        try
            out_oh = nets_v{i}(X')';
            votes(:, i) = onehotconv_DiRel(out_oh, 2);
        catch
            votes(:, i) = 0;
        end
    end
    pred = mode(votes, 2);
end

function [TrainIn,TrainOut,TestIn,TestOut] = DataProcess_DiRel(Input,Output)
    pha = 3/4;
    idx0 = find(Output == 0);
    idxp = find(Output == 1);
    idxn = find(Output == -1);

    trainIdx = [sampleIndex(idx0, pha); sampleIndex(idxp, pha); sampleIndex(idxn, pha)];
    if isempty(trainIdx)
        trainIdx = (1:size(Input,1))';
    end

    TrainIn  = Input(trainIdx,:);
    TrainOut = Output(trainIdx);
    testIdx  = setdiff((1:size(Input,1))', trainIdx, 'stable');
    TestIn   = Input(testIdx,:);
    TestOut  = Output(testIdx);

    if ~isempty(TrainOut)
        p = randperm(numel(TrainOut));
        TrainIn = TrainIn(p,:);
        TrainOut = TrainOut(p);
    end
    if ~isempty(TestOut)
        p = randperm(numel(TestOut));
        TestIn = TestIn(p,:);
        TestOut = TestOut(p);
    end
end

function idx = sampleIndex(pool, ratio)
    n = numel(pool);
    if n == 0
        idx = zeros(0,1);
        return;
    end
    k = max(1, ceil(ratio*n));
    idx = pool(randperm(n, k));
end

function out = onehotconv_DiRel(in, mode)
    if mode == 1
        out = zeros(size(in,1), 3);
        out(in == 1, 1)  = 1;
        out(in == 0, 2)  = 1;
        out(in == -1, 3) = 1;
    else
        out = zeros(size(in,1), 1);
        [~,maxind] = max(in, [], 2);
        out(maxind == 1) = 1;
        out(maxind == 3) = -1;
    end
end
