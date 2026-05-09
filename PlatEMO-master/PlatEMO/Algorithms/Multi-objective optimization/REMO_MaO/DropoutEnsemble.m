function nets = DropoutEnsemble(TrainIn_nor, TrainOut_onehot, xDim, K)
% DropoutEnsemble - 训练 K 个 patternnet 组成的 Bagging 集成
%
% 输入：
%   TrainIn_nor     : 归一化后的训练样本（行=样本，列=特征）
%   TrainOut_onehot : 二元 one-hot 标签（N×2）
%   xDim            : 输入特征维度（用于决定网络结构）
%   K               : 集成模型数量（默认 5）
%
% 输出：
%   nets : 1×K cell 数组，每个元素为训练好的 patternnet
%
% 设计要点：
%   1. 网络结构缩小到 [xDim, ⌈xDim/2⌉] 双层（原 REMO 三层 [1.5*xDim, xDim, 0.5*xDim]）
%      → 缓解 D=30 时参数量 13K vs 样本 1K 的过拟合
%   2. 每个网络用 70% 随机子样本训练（Bagging），引入多样性
%   3. 预测时取均值作为 score、方差作为不确定性 u（在 model_select 中实现）
%
% 借鉴源：
%   - EDN-ARMOEA：dropout 神经网络估计不确定性
%   - HeE-MOEA：异构集成思想

    if nargin < 4 || isempty(K)
        K = 5;
    end

    nSample = size(TrainIn_nor, 1);
    if nSample < 5
        % 训练样本太少，单独一次训练即可
        K = 1;
    end

    nets = cell(1, K);

    % 网络结构：双隐藏层
    hidden = [xDim, max(1, ceil(xDim / 2))];

    % Bagging 子样本比例
    bag_ratio = 0.7;
    nBag = max(2, ceil(bag_ratio * nSample));

    for i = 1 : K
        % 随机选择子样本（有放回 / 无放回均可，这里用无放回保留多样性）
        if K == 1
            sel = 1 : nSample;
        else
            sel = randperm(nSample, nBag);
        end

        Xi = TrainIn_nor(sel, :);
        Yi = TrainOut_onehot(sel, :);

        net = patternnet(hidden);
        net.trainParam.showWindow      = 0;
        net.trainParam.showCommandLine = 0;
        % 提前停止（避免过拟合）：缩短最大轮数，启用 validation
        net.trainParam.epochs = 200;
        net.divideParam.trainRatio = 0.8;
        net.divideParam.valRatio   = 0.2;
        net.divideParam.testRatio  = 0;

        % 训练
        net = train(net, Xi', Yi');

        nets{i} = net;
    end
end
