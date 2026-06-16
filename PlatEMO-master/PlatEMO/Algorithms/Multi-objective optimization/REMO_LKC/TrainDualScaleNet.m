function DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, K_ens)
% TrainDualScaleNet - 双尺度集成网络训练（模块②）
%
% 功能概述：
%   训练两组集成神经网络：
%   1. net_F：学习全目标（M个目标）的关系
%   2. net_S：学习 LKC 降维后聚合目标（可靠组）的关系，并用net_F的权重做迁移初始化
%
% 为什么需要双尺度？
%   - 全目标视角：看全局，信息完整，但目标维度高，建模复杂
%   - 降维视角：LKC 把相关目标聚合成更少的维度，建模更稳健
%   两个视角互补：全目标看大势，降维目标看稳健结构
%   注意：两个网络的输入维度相同（均为2×D决策变量拼接），区别仅在标签空间
%
% 为什么需要集成学习？
%   - 单个神经网络：随机初始化 → 训练结果不稳定
%   - 集成（bagging）：训练K个网络，取均值做预测，方差做不确定性
%   - 当K≥3时，才能计算预测方差，用于后续的逆方差仲裁
%
% 为什么需要迁移初始化？
%   - 子目标关系对的样本量 ≈ 全目标关系对
%   - 但从零训练30 epochs可能不够收敛
%   - 用net_F的权重做初始化：从最优解附近出发，收敛更快
%
% 网络拓扑：
%   Input(2D维) → hidden(最多24节点) → softmax(3类)
%   输入：关系对 [x_i, x_j] 的拼接
%   输出：3个概率 P(1), P(0, P(-1) 分别表示 x_i≻x_j, 相当, x_j≻x_i
%
% 输入：
%   XX_F - 全目标关系对输入，n×2M 矩阵
%          每行是 [x_i的决策变量, x_j的决策变量] 的拼接
%   YY_F - 全目标关系对标签，n×1 向量
%          取值 +1（x_i≻x_j）、0（相当）、-1（x_j≻x_i）
%   XX_S - 子目标关系对输入，n'×2M 矩阵（注意：决策变量维度相同，只是目标不同）
%   YY_S - 子目标关系对标签，n'×1 向量
%   K_ens - 集成规模，默认3（训练3个网络）
%
% 输出：
%   DualNet - 结构体，包含：
%     .nets_F      - 1×K_ens cell，全目标集成网络
%     .nets_S      - 1×K_ens cell，子目标集成网络
%     .mp_struct_F - 全目标输入归一化参数
%     .mp_struct_S - 子目标输入归一化参数
%     .p_err_F     - 全目标模型测试误差
%     .p_err_S     - 子目标模型测试误差
%
% 调用示例：
%   DualNet = TrainDualScaleNet(XX_F, YY_F, XX_S, YY_S, 3);

    % ===================================================================
    % 第一步：训练全目标集成网络 net_F
    % ===================================================================

    % DataProcessRel 将数据分为训练集（75%）和测试集（25%）
    % 并按类别分层采样，保证训练集和测试集的类别比例一致
    [TrainIn_F, TrainOut_F, TestIn_F, TestOut_F] = DataProcessRel(XX_F, YY_F);

    % mapminmax 是 MATLAB 的归一化函数
    % 将输入数据归一化到 [-1, 1] 范围
    % mp_struct_F 存储归一化参数（最小值、最大值），用于后续对新数据做同样的归一化
    [TrainIn_F_nor, mp_struct_F] = mapminmax(TrainIn_F');
    TrainIn_F_nor = TrainIn_F_nor';  % 转置回来

    % onehotconvRel 将标签转换为 one-hot 编码
    % +1 → [1,0,0], 0 → [0,1,0], -1 → [0,0,1]
    % 这是 softmax 输出层的标准格式
    TrainOut_F_oh = onehotconvRel(TrainOut_F, 1);

    % 训练全目标集成网络
    % initFromNets=[] 表示从随机权重开始训练（无迁移）
    % epochs=60 表示最多训练60轮
    xDim_F = size(TrainIn_F_nor, 2);   % 输入维度 = 2M
    nets_F = trainBagEnsemble(TrainIn_F_nor, TrainOut_F_oh, xDim_F, K_ens, [], 60);

    % 在测试集上评估集成网络的分类错误率
    p_err_F = testEnsemble(nets_F, TestIn_F, TestOut_F, mp_struct_F);

    % ===================================================================
    % 第二步：训练子目标集成网络 net_S（迁移初始化自 net_F）
    % ===================================================================

    % 同样的流程，但用子目标关系对
    [TrainIn_S, TrainOut_S, TestIn_S, TestOut_S] = DataProcessRel(XX_S, YY_S);
    [TrainIn_S_nor, mp_struct_S] = mapminmax(TrainIn_S');
    TrainIn_S_nor = TrainIn_S_nor';
    TrainOut_S_oh = onehotconvRel(TrainOut_S, 1);

    % 关键区别：initFromNets=nets_F，用全目标网络的权重做迁移初始化
    % epochs=30，因为有了好的初始化，不需要训练那么多轮
    xDim_S = size(TrainIn_S_nor, 2);   % 输入维度 = 2×D（决策变量，与net_F相同）
    nets_S = trainBagEnsemble(TrainIn_S_nor, TrainOut_S_oh, xDim_S, K_ens, nets_F, 30);

    p_err_S = testEnsemble(nets_S, TestIn_S, TestOut_S, mp_struct_S);

    % ===================================================================
    % 第三步：打包输出
    % ===================================================================
    DualNet = struct();
    DualNet.nets_F      = nets_F;       % 全目标集成网络
    DualNet.nets_S      = nets_S;       % 子目标集成网络
    DualNet.mp_struct_F = mp_struct_F;  % 全目标归一化参数
    DualNet.mp_struct_S = mp_struct_S;  % 子目标归一化参数
    DualNet.p_err_F     = p_err_F;      % 全目标测试误差
    DualNet.p_err_S     = p_err_S;      % 子目标测试误差
end


%% ========================================================================
%  局部辅助函数
%  ========================================================================

function nets = trainBagEnsemble(X, Y_oh, xDim, K, initFromNets, epochs)
% trainBagEnsemble - Bagging集成训练
%
% 功能：训练K个神经网络，每个网络用随机70%的样本训练
%       如果提供了 initFromNets，用迁移初始化
%
% Bagging原理：
%   1. 从训练集中随机有放回采样70%的样本
%   2. 用这个子集训练一个网络
%   3. 重复K次，得到K个网络
%   4. 预测时取K个网络的均值和方差
%
% 输入：
%   X            - 训练输入，n×D 矩阵（已归一化）
%   Y_oh         - 训练标签（one-hot），n×3 矩阵
%   xDim         - 输入维度 D
%   K            - 集成规模（网络数量）
%   initFromNets - 迁移源网络（cell数组），[]表示不迁移
%   epochs       - 训练轮数
%
% 输出：
%   nets         - 1×K cell，每个元素是一个训练好的 patternnet

    nSample = size(X, 1);   % 样本数量

    % 样本太少时只训练1个网络
    if nSample < 5
        K = 1;
    end
    K = max(1, K);

    % 确定隐藏层节点数
    % 规则：取 min(ceil(1.25×D), D, ceil(D/2))，但不超过24
    hidden = max(4, min([ceil(xDim*1.25), xDim, ceil(xDim/2)], 24));
    if isempty(hidden)
        hidden = max(4, ceil(xDim/2));
    end

    % 每次bagging采样的样本数 = 70%的总样本
    nBag = max(2, ceil(0.70 * nSample));

    nets = cell(1, K);   % 初始化输出

    for i = 1:K
        % -----------------------------------------------------------
        % 1. Bagging采样
        % -----------------------------------------------------------
        if K == 1 || nSample <= nBag
            % 样本太少，用全部样本
            sel = 1:nSample;
        else
            % 随机采样 nBag 个样本（有放回）
            sel = randperm(nSample, nBag);
        end
        Xi = X(sel, :);      % 采样后的输入
        Yi = Y_oh(sel, :);   % 采样后的标签

        % -----------------------------------------------------------
        % 2. 创建 patternnet
        % -----------------------------------------------------------
        % patternnet 是 MATLAB Neural Network Toolbox 的分类网络
        % hidden 是隐藏层节点数
        net = patternnet(hidden);

        % 训练参数设置
        net.trainParam.showWindow      = 0;      % 不显示训练窗口
        net.trainParam.showCommandLine = 0;      % 不在命令行显示
        net.trainParam.epochs          = epochs;  % 最大训练轮数
        net.trainParam.max_fail        = 6;       % 验证集连续失败6次停止
        net.trainParam.min_grad        = 1e-6;    % 最小梯度阈值
        net.divideParam.trainRatio     = 0.8;     % 80%用于训练
        net.divideParam.valRatio       = 0.2;     % 20%用于验证
        net.divideParam.testRatio      = 0;       % 不用测试集（我们自己分）

        % configure 初始化网络结构（不训练）
        net = configure(net, Xi', Yi');

        % -----------------------------------------------------------
        % 3. 迁移初始化（可选）
        % -----------------------------------------------------------
        if ~isempty(initFromNets) && i <= numel(initFromNets) && ~isempty(initFromNets{i})
            % TransferFineTune 将源网络的权重复制到目标网络
            % 这样训练从源网络的最优解附近出发，而不是随机初始化
            net = TransferFineTune(net, initFromNets{i});
        end

        % -----------------------------------------------------------
        % 4. 训练网络
        % -----------------------------------------------------------
        try
            % train 是 MATLAB 的网络训练函数
            % 输入输出需要转置（MATLAB惯例：样本按列排列）
            net = train(net, Xi', Yi');
        catch
            % 训练失败时的兜底策略：用默认参数重试一次
            net = patternnet(hidden);
            net.trainParam.showWindow      = 0;
            net.trainParam.showCommandLine = 0;
            net.trainParam.epochs          = max(20, floor(epochs/2));
            net.trainParam.max_fail        = 6;
            try
                net = train(net, Xi', Yi');
            catch
                % 仍然失败：返回空网络
                net = [];
            end
        end

        nets{i} = net;   % 存入集成
    end
end


function p_err = testEnsemble(nets, TestIn, TestOut, mp_struct)
% testEnsemble - 测试集成网络的分类错误率
%
% 输入：
%   nets      - 1×K cell，集成网络
%   TestIn    - 测试输入（未归一化）
%   TestOut   - 测试标签（+1/0/-1）
%   mp_struct - 归一化参数
%
% 输出：
%   p_err     - 错误率，范围 [0, 1]

    if isempty(TestIn)
        p_err = 1;   % 没有测试数据，返回最大错误率
        return;
    end

    % 用训练时的归一化参数对测试数据做同样的归一化
    TestIn_nor = mapminmax('apply', TestIn', mp_struct)';

    % 集成预测（投票法）
    pred = ensemblePredict(nets, TestIn_nor);

    % 计算错误率 = 预测错误的样本数 / 总样本数
    p_err = sum(pred ~= TestOut) / max(size(pred, 1), 1);
end


function pred = ensemblePredict(nets, X)
% ensemblePredict - 集成预测（投票法）
%
% 对每个测试样本，让K个网络分别预测，取众数（投票最多）作为最终预测
%
% 输入：
%   nets - 1×K cell，集成网络
%   X    - 测试输入（已归一化）
%
% 输出：
%   pred - n×1 预测标签（+1/0/-1）

    N = size(X, 1);

    % 过滤掉空网络（训练失败的）
    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    if isempty(nets_v)
        pred = zeros(N, 1);
        return;
    end

    K = numel(nets_v);
    votes = zeros(N, K);   % 存储每个网络的投票

    for i = 1:K
        try
            % nets_v{i}(X') 输出 3×N 矩阵（3类概率）
            % 转置后变成 N×3
            out_oh = nets_v{i}(X')';

            % onehotconvRel(..., 2) 将概率转换回标签
            % 取概率最大的类作为预测
            votes(:, i) = onehotconvRel(out_oh, 2);
        catch
            votes(:, i) = 0;  % 预测失败时投0票
        end
    end

    % mode 取每行的众数（出现最多的值）
    pred = mode(votes, 2);
end


function [TrainIn, TrainOut, TestIn, TestOut] = DataProcessRel(Input, Output)
% DataProcessRel - 训练/测试集划分
%
% 功能：将关系对数据按75%/25%分为训练集和测试集
%       分层采样：保证每个类别在训练集和测试集中的比例一致
%
% 输入：
%   Input  - n×2D 矩阵，关系对输入
%   Output - n×1 向量，关系对标签（+1/0/-1）
%
% 输出：
%   TrainIn, TrainOut - 训练集
%   TestIn, TestOut   - 测试集

    pha = 3/4;   % 训练集比例 75%

    % 按类别分组索引
    idx0 = find(Output == 0);    % 标签为0的样本索引
    idxp = find(Output == 1);    % 标签为+1的样本索引
    idxn = find(Output == -1);   % 标签为-1的样本索引

    % 对每个类别分别采样75%作为训练集
    trainIdx = [sampleIndex(idx0, pha); sampleIndex(idxp, pha); sampleIndex(idxn, pha)];
    if isempty(trainIdx)
        trainIdx = (1:size(Input,1))';   % 兜底：全用作训练集
    end

    % 划分训练集和测试集
    TrainIn  = Input(trainIdx, :);
    TrainOut = Output(trainIdx);
    testIdx  = setdiff((1:size(Input,1))', trainIdx, 'stable');  % 差集
    TestIn   = Input(testIdx, :);
    TestOut  = Output(testIdx);

    % 随机打乱训练集顺序（有助于SGD训练）
    if ~isempty(TrainOut)
        p = randperm(numel(TrainOut));
        TrainIn = TrainIn(p, :);
        TrainOut = TrainOut(p);
    end
    if ~isempty(TestOut)
        p = randperm(numel(TestOut));
        TestIn = TestIn(p, :);
        TestOut = TestOut(p);
    end
end


function idx = sampleIndex(pool, ratio)
% sampleIndex - 从索引池中随机采样指定比例
%
% 输入：
%   pool  - 可选索引列表
%   ratio - 采样比例，例如 0.75
%
% 输出：
%   idx   - 采样后的索引

    n = numel(pool);
    if n == 0
        idx = zeros(0, 1);
        return;
    end
    k = max(1, ceil(ratio * n));   % 至少采样1个
    idx = pool(randperm(n, k));     % 随机采样
end


function out = onehotconvRel(in, mode)
% onehotconvRel - One-hot编码转换
%
% 功能：
%   mode=1: 标签 → one-hot（用于训练）
%   mode=2: one-hot → 标签（用于预测）
%
% 标签编码：
%   +1 → [1, 0, 0] → 第1类
%    0 → [0, 1, 0] → 第2类
%   -1 → [0, 0, 1] → 第3类

    if mode == 1
        % 标签 → one-hot
        out = zeros(size(in, 1), 3);
        out(in == 1,  1) = 1;   % +1 → 第1列
        out(in == 0,  2) = 1;   %  0 → 第2列
        out(in == -1, 3) = 1;   % -1 → 第3列
    else
        % one-hot → 标签
        out = zeros(size(in, 1), 1);
        [~, maxind] = max(in, [], 2);   % 取概率最大的类
        out(maxind == 1) = 1;    % 第1类 → +1
        out(maxind == 3) = -1;   % 第3类 → -1
        % 第2类保持为0
    end
end
