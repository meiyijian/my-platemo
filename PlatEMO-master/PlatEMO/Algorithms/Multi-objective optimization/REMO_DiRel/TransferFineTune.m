function net = TransferFineTune(net, srcNet)
% TransferFineTune - 模块②辅助：把 srcNet 的权重复制到 net 上
%
% patternnet 不原生支持冻结指定层；用"权重初始化迁移"替代：
% 把 srcNet 的输入权重 IW、层间权重 LW、偏置 b 复制到 net 上，
% 让训练从 srcNet 的最优点附近出发而不是随机初始化。
%
% 当 net 与 srcNet 的拓扑（输入维度、层数、各层节点数）一致时，权重直接复制；
% 否则跳过该层（仅复制能匹配的层）。
%
% 输入：
%   net    : 目标 patternnet（已 configure 但未 train）
%   srcNet : 源 patternnet（已 train）
%
% 输出：
%   net    : 权重已初始化的 patternnet

    if isempty(srcNet)
        return;
    end

    try
        % ---- 复制输入权重 IW ----
        % IW{i,j} 是从输入 j 到隐藏层 i 的权重矩阵
        for i = 1:numel(net.IW)
            if ~isempty(net.IW{i}) && i <= numel(srcNet.IW) && ~isempty(srcNet.IW{i})
                if isequal(size(net.IW{i}), size(srcNet.IW{i}))
                    net.IW{i} = srcNet.IW{i};
                end
            end
        end

        % ---- 复制层间权重 LW ----
        % LW{i,j} 是从层 j 到层 i 的权重矩阵
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

        % ---- 复制偏置 b ----
        for i = 1:numel(net.b)
            if ~isempty(net.b{i}) && i <= numel(srcNet.b) && ~isempty(srcNet.b{i})
                if isequal(size(net.b{i}), size(srcNet.b{i}))
                    net.b{i} = srcNet.b{i};
                end
            end
        end
    catch
        % 权重复制失败：保留 net 的原始随机初始化（等价于无迁移）
    end
end
