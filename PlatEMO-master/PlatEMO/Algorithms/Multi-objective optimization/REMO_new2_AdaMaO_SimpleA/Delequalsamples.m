function [XXs,YYs] = Delequalsamples(XXs,YYs)
% Delequalsamples - 删除等价样本对（标签为 0 的同类对）
%
% 用于在需要时剔除"好-好"和"坏-坏"对，只保留有区分度的"好坏对"
%
% 输入:
%   XXs - n_pair x 2D 关系对样本
%   YYs - n_pair x 1 关系标签
% 输出:
%   XXs - 删除标签为 0 的样本后的输入
%   YYs - 删除标签为 0 的样本后的标签
%
% 注意：此函数在主流程中未被调用，是从原 REMO 保留的工具函数
%       可在需要时手工剔除标签为 0 的样本对

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 找到标签为 0 的样本索引
    zerosindex        = YYs == 0;
    % 删除这些样本
    XXs(zerosindex,:) = [];
    YYs(zerosindex)   = [];
end
