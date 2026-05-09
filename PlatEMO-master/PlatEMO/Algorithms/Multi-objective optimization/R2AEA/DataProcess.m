function [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(Input,Output)
% DataProcess：数据集划分函数
% 将关系对数据按比例划分为训练集和测试集
% 保证各类别在训练集和测试集中的比例一致
%
% 输入参数：
%   Input  - 关系对的决策变量，大小为 N x (2*D)
%   Output - 关系对的标签（0, 1, -1）
%
% 输出参数：
%   TrainIn  - 训练集输入
%   TrainOut - 训练集输出
%   TestIn   - 测试集输入
%   TestOut  - 测试集输出

%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ==================== 步骤1：定义划分比例 ====================
    % pha：训练集比例（1/4 = 25%用于训练，75%用于测试）
    pha = 1/4;

    %% ==================== 步骤2：按标签分类 ====================
    % find()：找到满足条件的索引
    index0 = find(Output==0);    % 标签=0（同类对）的索引
    indexp1 = find(Output == 1); % 标签=1（好-差对）的索引
    indexn1 = find(Output == -1);% 标签=-1（差-好对）的索引

    %% ==================== 步骤3：为每类生成训练集标记 ====================
    % 初始化逻辑数组，标记哪些样本用于训练
    K0 = false(1,length(index0));
    Kp1 = false(1,length(indexp1));
    Kn1 = false(1,length(indexn1));

    % randperm(n,k)：生成1到n的随机排列，取前k个
    % ceil()：向上取整
    % 将随机选择的样本标记为true（用于训练）
    K0(randperm(length(index0),ceil(pha*length(index0)))) = true;
    Kp1(randperm(length(indexp1),ceil(pha*length(indexp1)))) = true;
    Kn1(randperm(length(indexn1),ceil(pha*length(indexn1)))) = true;

    %% ==================== 步骤4：划分训练集 ====================
    % 将三类的训练样本索引合并
    K = [index0(K0);indexp1(Kp1);indexn1(Kn1)];

    % 提取训练集数据
    TrainIn = Input(K,:);    % 训练集输入
    TrainOut = Output(K);    % 训练集输出

    %% ==================== 步骤5：划分测试集 ====================
    % setdiff：集合差运算，找到不在K中的索引
    % 1:size(Input,1)：所有样本的索引
    TestIn = Input(setdiff(1:size(Input,1),K),:);   % 测试集输入
    TestOut = Output(setdiff(1:size(Input,1),K));    % 测试集输出

    %% ==================== 步骤6：随机打乱数据顺序 ====================
    % 随机打乱训练集顺序
    Train_randindex = randperm(size(TrainOut,1),size(TrainOut,1));
    TrainIn = TrainIn(Train_randindex,:);
    TrainOut = TrainOut(Train_randindex);

    % 随机打乱测试集顺序
    Test_randindex = randperm(size(TestOut,1),size(TestOut,1));
    TestIn = TestIn(Test_randindex,:);
    TestOut = TestOut(Test_randindex);
end