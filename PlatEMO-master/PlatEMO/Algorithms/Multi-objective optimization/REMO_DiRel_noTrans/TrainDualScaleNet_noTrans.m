function DualNet = TrainDualScaleNet_noTrans(XX_F, YY_F, XX_S, YY_S, K_ens)
% TrainDualScaleNet_noTrans - 消融变体辅助：net_S 不用 net_F 权重初始化
%
% 与 TrainDualScaleNet 唯一差异：第 3 个参数 initFromNets 传空，
% 让 net_S 从随机初始化训练。

    [TrainIn_F, TrainOut_F, TestIn_F, TestOut_F] = DataProcess(XX_F, YY_F);
    [TrainIn_F_nor, mp_struct_F] = mapminmax(TrainIn_F');
    TrainIn_F_nor = TrainIn_F_nor';
    TrainOut_F_oh = onehotconv(TrainOut_F, 1);

    xDim_F = size(TrainIn_F_nor, 2);
    nets_F = trainBagEnsembleLocal(TrainIn_F_nor, TrainOut_F_oh, xDim_F, K_ens, []);

    if isempty(TestIn_F)
        p_err_F = 1;
    else
        TestIn_F_nor = mapminmax('apply', TestIn_F', mp_struct_F)';
        pred_F = ensemblePredictLocal(nets_F, TestIn_F_nor);
        p_err_F = sum(pred_F ~= TestOut_F) / size(pred_F, 1);
    end

    [TrainIn_S, TrainOut_S, TestIn_S, TestOut_S] = DataProcess(XX_S, YY_S);
    [TrainIn_S_nor, mp_struct_S] = mapminmax(TrainIn_S');
    TrainIn_S_nor = TrainIn_S_nor';
    TrainOut_S_oh = onehotconv(TrainOut_S, 1);

    xDim_S = size(TrainIn_S_nor, 2);
    % 关键差异：第 5 个参数为空 → net_S 从随机初始化训练（不迁移）
    nets_S = trainBagEnsembleLocal(TrainIn_S_nor, TrainOut_S_oh, xDim_S, K_ens, []);

    if isempty(TestIn_S)
        p_err_S = 1;
    else
        TestIn_S_nor = mapminmax('apply', TestIn_S', mp_struct_S)';
        pred_S = ensemblePredictLocal(nets_S, TestIn_S_nor);
        p_err_S = sum(pred_S ~= TestOut_S) / size(pred_S, 1);
    end

    DualNet = struct();
    DualNet.nets_F      = nets_F;
    DualNet.nets_S      = nets_S;
    DualNet.mp_struct_F = mp_struct_F;
    DualNet.mp_struct_S = mp_struct_S;
    DualNet.p_err_F     = p_err_F;
    DualNet.p_err_S     = p_err_S;
end

function nets = trainBagEnsembleLocal(X, Y_oh, xDim, K, initFromNets)
    nSample = size(X, 1);
    if nSample < 5
        K = 1;
    end
    K = max(1, K);
    hidden = [ceil(xDim*1.5), xDim, ceil(xDim/2)];
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
        net.trainParam.epochs          = 200;
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
            try
                net = train(net, Xi', Yi');
            catch
                net = [];
            end
        end
        nets{i} = net;
    end
end

function pred = ensemblePredictLocal(nets, X)
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
            votes(:, i) = onehotconv(out_oh, 2);
        catch
            votes(:, i) = 0;
        end
    end
    pred = mode(votes, 2);
end
