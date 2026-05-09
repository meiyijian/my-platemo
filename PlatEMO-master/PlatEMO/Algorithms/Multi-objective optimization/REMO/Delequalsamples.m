function [XXs,YYs] = Delequalsamples(XXs,YYs)
% 删除标签为0的样本——即删除"相等关系"的配对
%
% 在关系学习中，标签0表示"两个解质量相等"。
% 有时我们只关心"谁比谁好"这种明确的关系（1和-1），
% 删除相等关系的样本可以简化学习任务。
%
% 注意：这个函数在当前的REMO主流程中其实没有被调用，
% 可能是为某些变体或实验准备的辅助函数。
%
% XXs - 配对数据（每行两个解的拼接）
% YYs - 关系标签（1/0/-1）
% 返回删除标签为0的样本后的数据

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 找出标签为0的行的索引
    zerosindex        = YYs == 0;
    % 删除标签为0的行（XXs中删除对应的行，YYs中删除对应的标签）
    XXs(zerosindex,:) = [];  % [] = 空矩阵，赋值为空就相当于删除
    YYs(zerosindex)   = [];
end
