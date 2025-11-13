function Output = GetOutput(PopObj,RefPoint)
% GetOutput - 计算解决方案的分类标签（0或1）
% 输入参数：
%   PopObj: 种群的目标值矩阵
%   RefPoint: 参考点/解的目标值矩阵
% 输出参数：
%   Output: 分类标签向量，true(1)表示好解，false(0)表示差解

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He

    % 获取种群大小
    N = size(PopObj,1);
    
    % 初始化输出标签为true（假设所有解都是好解）
    Output = true(N,1);
    
    % 对每个参考点进行评估
    % 对于一个解，如果它在任何一个参考点的至少一个目标维度上优于该参考点，则认为该解是好解
    % 使用逻辑与操作，确保所有参考点条件都满足
    for i = 1 : size(RefPoint,1)
        % 创建参考点的重复矩阵，用于与所有种群解比较
        % 使用any(...,2)检查每行是否有至少一个元素满足条件（即解在至少一个目标上优于参考点）
        % 使用逻辑与操作符(&)更新Output
        Output = Output & any(PopObj<=repmat(RefPoint(i,:),N,1),2);
    end
    
    % 最终，Output中的每个元素为true表示该解在所有参考点的至少一个目标上都表现更好
end