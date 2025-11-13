function [Site,RLoc] = RadarGrid(P,div)
% RadarGrid - 计算每个解决方案的雷达网格索引
% 输入参数：
%   P: 目标值矩阵，每行一个解的目标向量
%   div: 网格划分数量，用于确定网格的精细程度
% 输出参数：
%   Site: 每个解所在的网格索引
%   RLoc: 每个解转换后的雷达坐标系坐标

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He

	% 获取输入矩阵的尺寸
	% N: 解的数量
	% M: 目标函数的数量
	[N,M] = size(P);
     
    %% 计算每个解的雷达坐标系坐标
    % 生成等间距的角度向量，用于雷达坐标系
    theta     = 0 : 2*pi/M : 2*pi/M*(M-1);
    
    % 将高维目标向量投影到雷达坐标系的x轴和y轴
    % 通过与方向向量的点积实现投影
    % 归一化处理确保坐标在[-1,1]范围内
    RLoc(:,1) = sum(P.*repmat(cos(theta),N,1),2)./sum(P,2);  % x坐标
    RLoc(:,2) = sum(P.*repmat(sin(theta),N,1),2)./sum(P,2);  % y坐标
    
    % 将坐标映射到[0,1]范围内
    RLoc      = (RLoc+1)/2;
    
    % 下面这行代码被注释掉，可能是一种替代的非线性映射方法
%   	RLoc      = RLoc.*sqrt(abs(RLoc));
    
    % 计算转换后点的边界
    YL        = min(RLoc,[],1);                             % 下边界
    YU        = max(RLoc,[],1);                             % 上边界  
    
    % 归一化到[0,1]范围内
    NRLoc     = (RLoc-repmat(YL,N,1))./repmat(YU-YL,N,1);	
    
    %% 确定每个解的网格索引
    % 将归一化的坐标映射到整数网格索引
    GLoc            = floor(NRLoc.*div);
    
    % 处理边界情况，确保所有索引都在有效范围内
    GLoc(GLoc>=div) = div - 1;
    
    % 获取所有唯一的网格位置并排序
    UniqueGLoc      = sortrows(unique(GLoc,'rows'));
    
    % 为每个解分配唯一的网格索引
    [~,Site]        = ismember(GLoc,UniqueGLoc,'rows');
end