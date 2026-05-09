function varargout = onehotconv2(varargin)
% onehotconv2 - 二元 one-hot 编码 / 解码
%
% 用法：
%   l_onehot = onehotconv2(l, 1)    % 编码：将 0/1 标签转为 one-hot
%   l        = onehotconv2(onehot, 2) % 解码：将 one-hot 转回 0/1 标签
%
% 编码规则（修复原 onehotconv 三类与训练数据 ±1 不一致的 bug）：
%   l == 1 → [1, 0]   表示 "好优于差"
%   l == 0 → [0, 1]   表示 "差劣于好"
%
% 注意：与原 onehotconv 不同，本版本是纯二分类，与 BinaryRelationPairs
% 输出的 0/1 标签语义完全一致；网络输出层只有 2 个神经元。

    if varargin{2} == 1
        % 编码
        l        = varargin{1};
        l_onehot = zeros(size(l, 1), 2);
        l_onehot(l == 1, 1) = 1;
        l_onehot(l == 0, 2) = 1;
        varargout = {l_onehot};

    elseif varargin{2} == 2
        % 解码
        onehot_l = varargin{1};
        res_l    = zeros(size(onehot_l, 1), 1);
        [~, maxind] = max(onehot_l, [], 2);
        res_l(maxind == 1) = 1;
        res_l(maxind == 2) = 0;
        varargout = {res_l};
    end
end
