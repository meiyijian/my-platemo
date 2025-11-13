function [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(Input,Output)
% DataProcess - 将数据按比例分为训练集和测试集
% 输入参数：
%   Input: 输入特征数据，即决策变量矩阵
%   Output: 输出标签数据，即分类结果
% 输出参数：
%   TrainIn: 训练集输入特征
%   TrainOut: 训练集输出标签
%   TestIn: 测试集输入特征
%   TestOut: 测试集输出标签

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He

        % 分离正样本和负样本的索引
        % index1: 标签为1的样本索引（正样本）
        % index0: 标签为0的样本索引（负样本）
        index1 = find(Output>0.5);
        index0 = find(Output<=0.5);
        
        % 初始化选择标记数组
        K1     = false(1,length(index1));
        K0     = false(1,length(index0));
        
        % 对正样本和负样本分别进行随机选择，各选择75%作为训练集
        % 这种分层采样方法确保训练集和测试集中正样本和负样本的比例一致
        K1(randperm(length(index1),ceil(3/4*length(index1)))) = true;
        K0(randperm(length(index0),ceil(3/4*length(index0)))) = true;
        
        % 合并训练集索引
        K        = [index1(K1);index0(K0)];
        
        % 构建训练集和测试集
        TrainIn  = Input(K,:);          % 训练集输入特征
        TrainOut = Output(K);           % 训练集输出标签
        TestIn   = Input(setdiff(1:size(Input,1),K),:);  % 测试集输入特征（使用setdiff获取不在训练集中的索引）
        TestOut  = Output(setdiff(1:size(Input,1),K));   % 测试集输出标签
end