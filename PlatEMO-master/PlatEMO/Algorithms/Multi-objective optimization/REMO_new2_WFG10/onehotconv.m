function varargout = onehotconv(varargin)
% One-hot 编码/解码工具函数
% 模式 1（编码）: 标签 → one-hot 向量
% 模式 2（解码）: one-hot 向量 → 标签
%
% 用法:
%   encoded = onehotconv(labels, 1)   % 编码
%   decoded = onehotconv(encoded, 2)  % 解码
%
% 标签编码规则:
%   +1 → [1, 0, 0]
%    0 → [0, 1, 0]
%   -1 → [0, 0, 1]

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    if varargin{2}== 1
        %% ============ 模式 1：编码 ============
        % 将标签 {-1, 0, +1} 转为 one-hot 向量
        l        = varargin{1};
        l_onehot = zeros(size(l,1),3);

        % +1 → [1, 0, 0]（第一列为 1）
        l_onehot(l == 1 ,1) = 1;
        %  0 → [0, 1, 0]（第二列为 1）
        l_onehot(l == 0,2)  = 1;
        % -1 → [0, 0, 1]（第三列为 1）
        l_onehot(l == -1,3) = 1;

        varargout = {l_onehot};

    elseif varargin{2} == 2
        %% ============ 模式 2：解码 ============
        % 将 one-hot 向量转回标签 {-1, 0, +1}
        onehot_l = varargin{1};
        res_l    = zeros(size(onehot_l,1),1);  % 默认为 0

        % 找到每行最大值的列索引
        [~,maxind] = max(onehot_l,[],2);

        % 第 1 列最大 → +1
        res_l(maxind==1) = 1;
        % 第 2 列最大 → 0（默认值，无需显式赋值）
        % 第 3 列最大 → -1
        res_l(maxind==3) = -1;

        varargout = {res_l};
    end
end