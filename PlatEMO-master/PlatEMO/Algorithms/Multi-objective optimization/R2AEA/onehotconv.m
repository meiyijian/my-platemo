function varargout = onehotconv(varargin)
% onehotconv：one-hot编码/解码工具函数
% 实现标签与one-hot编码之间的转换
%
% 输入参数（可变参数）：
%   varargin{1} - 输入数据
%   varargin{2} - 模式选择：
%                 1 = 标签 -> one-hot编码
%                 2 = one-hot编码 -> 标签
%
% 输出参数：
%   varargout - 转换后的数据

%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    if varargin{2} == 1
        %% ==================== 模式1：标签 -> one-hot编码 ====================
        % 将标签向量转换为one-hot矩阵
        % 标签映射规则：
        %   1  -> [1, 0, 0]（好解）
        %   0  -> [0, 1, 0]（同类对）
        %   -1 -> [0, 0, 1]（差解）

        % l：输入的标签向量
        l = varargin{1};

        % l_onehot：初始化one-hot矩阵，大小为 N x 3
        l_onehot = zeros(size(l,1),3);

        % 逻辑索引：找到标签为1的位置，在第1列设置为1
        l_onehot(l == 1 ,1) = 1;

        % 逻辑索引：找到标签为0的位置，在第2列设置为1
        l_onehot(l == 0,2) = 1;

        % 逻辑索引：找到标签为-1的位置，在第3列设置为1
        l_onehot(l == -1,3) = 1;

        % 返回one-hot编码结果
        varargout = {l_onehot};

    elseif varargin{2} == 2
        %% ==================== 模式2：one-hot编码 -> 标签 ====================
        % 将one-hot概率矩阵转换为标签向量
        % 找到每行最大值的索引，映射回标签

        % onehot_l：输入的one-hot概率矩阵
        onehot_l = varargin{1};

        % res_l：初始化结果标签向量
        res_l = zeros(size(onehot_l,1),1);

        % max(onehot_l,[],2)：对每行取最大值
        % ~：忽略最大值，maxind：最大值所在的列索引
        [~,maxind] = max(onehot_l,[],2);

        % 映射规则：
        % maxind==1（第1列最大）-> 标签1（好解）
        res_l(maxind==1) = 1;

        % maxind==3（第3列最大）-> 标签-1（差解）
        % maxind==2（第2列最大）-> 标签0（保持默认）
        res_l(maxind==3) = -1;

        % 返回标签结果
        varargout = {res_l};
    end
end