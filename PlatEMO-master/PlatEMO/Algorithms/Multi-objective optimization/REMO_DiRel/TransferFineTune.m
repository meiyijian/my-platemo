function net = TransferFineTune(net, srcNet)
% TransferFineTune - 权重迁移初始化（模块②辅助函数）
%
% 功能概述：
%   将源网络 srcNet 的权重复制到目标网络 net 上
%   这样目标网络的训练从源网络的最优解附近出发，而不是随机初始化
%
% 为什么需要迁移初始化？
%   - 子目标关系对的样本量 ≈ 全目标关系对
%   - 但从零训练30 epochs可能不够收敛
%   - 全目标网络（net_F）已经训练了60 epochs，找到了较好的权重
%   - 用net_F的权重初始化net_S，相当于"热启动"，收敛更快
%
% 为什么不用"冻结层"？
%   - 理想的迁移学习会冻结前面的层，只微调后面的层
%   - 但MATLAB的patternnet不原生支持冻结层
%   - 所以用"权重初始化迁移"替代：复制所有权重，然后继续训练
%   - 效果类似：从源网络的最优解附近出发
%
% 什么时候权重能直接复制？
%   - 当net和srcNet的拓扑（输入维度、层数、各层节点数）一致时
%   - 如果拓扑不一致（例如输入维度不同），跳过不匹配的层
%
% 输入：
%   net    - 目标 patternnet（已 configure 但未 train）
%            configure 会初始化随机权重，但不训练
%   srcNet - 源 patternnet（已 train，权重是最优解）
%
% 输出：
%   net    - 权重已迁移的 patternnet
%            如果迁移失败，保留原始随机初始化（等价于无迁移）
%
% 调用示例：
%   net_S = patternnet(24);
%   net_S = configure(net_S, X', Y');
%   net_S = TransferFineTune(net_S, net_F);  % 用net_F的权重初始化

    % 如果源网络为空，直接返回（不做迁移）
    if isempty(srcNet)
        return;
    end

    try
        % ===============================================================
        % 复制输入权重 IW (Input Weights)
        % ===============================================================
        % IW{i,j} 是从输入 j 到隐藏层 i 的权重矩阵
        % 对于单隐藏层网络：IW{1,1} 是 输入→隐藏层 的权重
        % 尺寸：hidden_nodes × input_dim
        for i = 1:numel(net.IW)
            if ~isempty(net.IW{i}) && i <= numel(srcNet.IW) && ~isempty(srcNet.IW{i})
                % 只有当两个网络的权重矩阵尺寸相同时才复制
                if isequal(size(net.IW{i}), size(srcNet.IW{i}))
                    net.IW{i} = srcNet.IW{i};
                end
            end
        end

        % ===============================================================
        % 复制层间权重 LW (Layer Weights)
        % ===============================================================
        % LW{i,j} 是从层 j 到层 i 的权重矩阵
        % 对于单隐藏层网络：LW{2,1} 是 隐藏层→输出层 的权重
        % 尺寸：output_dim × hidden_nodes
        for i = 1:size(net.LW, 1)
            for j = 1:size(net.LW, 2)
                if ~isempty(net.LW{i,j}) ...
                        && i <= size(srcNet.LW, 1) && j <= size(srcNet.LW, 2) ...
                        && ~isempty(srcNet.LW{i,j})
                    if isequal(size(net.LW{i,j}), size(srcNet.LW{i,j}))
                        net.LW{i,j} = srcNet.LW{i,j};
                    end
                end
            end
        end

        % ===============================================================
        % 复制偏置 b (Biases)
        % ===============================================================
        % b{i} 是第 i 层的偏置向量
        % 对于单隐藏层网络：b{1} 是隐藏层偏置，b{2} 是输出层偏置
        for i = 1:numel(net.b)
            if ~isempty(net.b{i}) && i <= numel(srcNet.b) && ~isempty(srcNet.b{i})
                if isequal(size(net.b{i}), size(srcNet.b{i}))
                    net.b{i} = srcNet.b{i};
                end
            end
        end

    catch
        % 权重复制失败：保留 net 的原始随机初始化（等价于无迁移）
        % 这是一个安全的兜底策略，不会导致算法崩溃
    end
end
