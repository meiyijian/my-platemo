function DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens)
% TrainDualScaleNet - 模块②：训练双尺度关系网络（bagging 集成 + 迁移）
%
% net_F : 全目标关系网络（K_ens 个 bagging patternnet）
% net_S : 子目标关系网络（K_ens 个 patternnet, 每个 bag 用 net_F 对应 bag 的权重初始化）
%
% patternnet 不原生支持冻结+fine-tune；改用"权重初始化迁移"：把 net_F 的权重
% 作为 net_S 的训练起点，net_S 的 epochs 与 net_F 相同（不缩短），让数据决定
% 它最终是否偏离 net_F。这是 plan 中"transferFineTune 实现复杂"的退路方案。
%
% 输入：
%   XX_F, YY_F : 全目标样本对 (n × 2D, n × 1)
%   XX_S, YY_S : 子目标样本对 (n' × 2D, n' × 1)
%   K_ens      : 集成大小（典型 5）
%
% 输出：
%   DualNet : 结构体
%     .nets_F       : 1×K_ens cell 数组（net_F 的 patternnet 集成）
%     .nets_S       : 1×K_ens cell 数组（net_S 的 patternnet 集成）
%     .mp_struct_F  : 全目标归一化结构
%     .mp_struct_S  : 子目标归一化结构
%     .p_err_F      : net_F 平均测试误差（诊断用）
%     .p_err_S      : net_S 平均测试误差（诊断用）

    % ---- 全目标支线：标准 REMO 数据预处理 ----
    [TrainIn_F, TrainOut_F, TestIn_F, TestOut_F] = DataProcess(XX_F, YY_F);
    [TrainIn_F_nor, mp_struct_F] = mapminmax(TrainIn_F');
    TrainIn_F_nor = TrainIn_F_nor';
    TrainOut_F_oh = onehotconv(TrainOut_F, 1);

    % ---- 训练 net_F 集成 ----
    xDim_F = size(TrainIn_F_nor, 2);
    nets_F = trainBagEnsemble(TrainIn_F_nor, TrainOut_F_oh, xDim_F, K_ens, []);

    % 测试集误差（取集成多数投票）
    if isempty(TestIn_F)
        p_err_F = 1;
    else
        TestIn_F_nor = mapminmax('apply', TestIn_F', mp_struct_F)';
        pred_F = ensemblePredict(nets_F, TestIn_F_nor);
        p_err_F = sum(pred_F ~= TestOut_F) / size(pred_F, 1);
    end

    % ---- 子目标支线 ----
    [TrainIn_S, TrainOut_S, TestIn_S, TestOut_S] = DataProcess(XX_S, YY_S);
    [TrainIn_S_nor, mp_struct_S] = mapminmax(TrainIn_S');
    TrainIn_S_nor = TrainIn_S_nor';
    TrainOut_S_oh = onehotconv(TrainOut_S, 1);

    % ---- 训练 net_S 集成（迁移：用 nets_F{i} 权重初始化对应 nets_S{i}）----
    xDim_S = size(TrainIn_S_nor, 2);
    nets_S = trainBagEnsemble(TrainIn_S_nor, TrainOut_S_oh, xDim_S, K_ens, nets_F);

    if isempty(TestIn_S)
        p_err_S = 1;
    else
        TestIn_S_nor = mapminmax('apply', TestIn_S', mp_struct_S)';
        pred_S = ensemblePredict(nets_S, TestIn_S_nor);
        p_err_S = sum(pred_S ~= TestOut_S) / size(pred_S, 1);
    end

    % ---- 打包 ----
    DualNet = struct();
    DualNet.nets_F      = nets_F;
    DualNet.nets_S      = nets_S;
    DualNet.mp_struct_F = mp_struct_F;
    DualNet.mp_struct_S = mp_struct_S;
    DualNet.p_err_F     = p_err_F;
    DualNet.p_err_S     = p_err_S;
end

% ============================================================
function nets = trainBagEnsemble(X, Y_oh, xDim, K, initFromNets)
% 训 K 个 patternnet bagging 集成；若 initFromNets 非空则用其权重做迁移初始化
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

        % 必须先 configure 一次才能设置/读取权重
        net = configure(net, Xi', Yi');

        % 迁移初始化：若 initFromNets 提供且结构兼容，复制权重
        if ~isempty(initFromNets) && i <= numel(initFromNets) && ~isempty(initFromNets{i})
            net = TransferFineTune(net, initFromNets{i});
        end

        try
            net = train(net, Xi', Yi');
        catch
            % 训练失败兜底：重新随机初始化训练一次
            net = patternnet(hidden);
            net.trainParam.showWindow      = 0;
            net.trainParam.showCommandLine = 0;
            try
                net = train(net, Xi', Yi');
            catch
                % 仍然失败：保留空 net（预测时会被忽略）
                net = [];
            end
        end
        nets{i} = net;
    end
end

% ============================================================
function pred = ensemblePredict(nets, X)
% 集成预测：多数投票
% X 是 N × dim 已归一化输入
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
    % 多数投票（最频繁的标签）
    pred = mode(votes, 2);
end
