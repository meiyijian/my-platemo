function varargout = onehotconv(varargin)
% 独热编码(One-hot)转换器：在类别标签和独热编码之间相互转换
%
% 为什么需要独热编码？
% 类别标签 1/0/-1 看起来是数字，但神经网络会误以为它们有大小关系（1 > 0 > -1）。
% 实际上这三个类别是平等的，用独热编码 [1,0,0]、[0,1,0]、[0,0,1] 可以避免这个问题。
%
% 用法：
%   onehotconv(labels, 1)  → 将类别标签(1/0/-1)转为独热编码(3列)
%   onehotconv(onehot, 2)  → 将独热编码转回类别标签(1/0/-1)
%
% varargin{1} - 输入数据（标签列向量 或 独热编码矩阵）
% varargin{2} - 转换模式：1=编码(标签→独热)，2=解码(独热→标签)
% varargout   - 转换后的数据

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    if varargin{2}== 1
        %% 模式1：编码（conv onehot）- 将类别标签转为独热编码
        % 类别1 → [1, 0, 0]
        % 类别0 → [0, 1, 0]
        % 类别-1 → [0, 0, 1]
        l        = varargin{1};      % 输入的标签列向量
        l_onehot = zeros(size(l,1),3);  % 初始化全零矩阵，每行3列

        l_onehot(l == 1 ,1) = 1;   % 标签=1 的行，第1列置1
        l_onehot(l == 0,2)  = 1;   % 标签=0 的行，第2列置1
        l_onehot(l == -1,3) = 1;   % 标签=-1 的行，第3列置1

        varargout = {l_onehot};    % 返回独热编码矩阵

    elseif varargin{2} == 2
        %% 模式2：解码（deconv onehot）- 将独热编码转回类别标签
        onehot_l = varargin{1};    % 输入的独热编码矩阵
        res_l    = zeros(size(onehot_l,1),1);  % 初始化标签列向量

        % max 的第二个返回值：每行最大值所在的列索引
        [~,maxind] = max(onehot_l,[],2);
        % maxind=1 表示第1列最大 → 原标签为1
        % maxind=2 表示第2列最大 → 原标签为0
        % maxind=3 表示第3列最大 → 原标签为-1

        res_l(maxind==1) = 1;
        res_l(maxind==3) = -1;
        % 注意：maxind==2 时 res_l 保持为0，已经正确

        varargout = {res_l};       % 返回标签列向量
    end
end
