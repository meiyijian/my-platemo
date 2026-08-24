function [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(Input,Output)
% 数据划分函数：将数据集按比例划分为训练集和测试集
% 采用分层采样（Stratified Sampling），保持各类别在训练/测试集中的比例一致
%
% Input  - 输入特征（配对的解数据），每行一个样本
% Output - 标签（1/0/-1 表示关系类别）
% TrainIn  - 训练集特征
% TrainOut - 训练集标签
% TestIn   - 测试集特征
% TestOut  - 测试集标签

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    pha     = 3/4;  % 训练集比例 = 75%，测试集 = 25%

    % 找出每种类别标签对应的样本索引
    % 标签有三种：0（同类/相等），1（好），-1（差）
    index0  = find(Output==0);    % 标签为0的样本位置
    indexp1 = find(Output == 1);  % 标签为1的样本位置
    indexn1 = find(Output == -1); % 标签为-1的样本位置

    % 初始化逻辑数组（false表示未选中，true表示选中作为训练集）
    K0  = false(1,length(index0));    % 类别0的选择标记
    Kp1 = false(1,length(indexp1));   % 类别1的选择标记
    Kn1 = false(1,length(indexn1));   % 类别-1的选择标记

    % 从每个类别中随机抽选 3/4 作为训练集
    % randperm(n, k) = 从1到n随机选k个不重复的数
    % 这里对每一类都按3/4比例随机抽取
    K0(randperm(length(index0),ceil(pha*length(index0))))    = true;
    Kp1(randperm(length(indexp1),ceil(pha*length(indexp1)))) = true;
    Kn1(randperm(length(indexn1),ceil(pha*length(indexn1)))) = true;

    % 拼接所有被选为训练集的样本索引
    K        = [index0(K0);indexp1(Kp1);indexn1(Kn1)];
    % 提取训练集的特征和标签
    TrainIn  = Input(K,:);
    TrainOut = Output(K);

    % setdiff = 找出不在训练集中的样本（即测试集）
    % 1:size(Input,1) = 所有样本的编号
    % K = 训练集样本编号
    % setdiff(全部, 训练集) = 测试集
    TestIn  = Input(setdiff(1:size(Input,1),K),:);
    TestOut = Output(setdiff(1:size(Input,1),K));

    % 打乱训练集的顺序（让神经网络训练时不会受样本顺序影响）
    Train_randindex = randperm(size(TrainOut,1),size(TrainOut,1));
    TrainIn         = TrainIn(Train_randindex,:);
    TrainOut        = TrainOut(Train_randindex);

    % 同样打乱测试集的顺序
    Test_randindex = randperm(size(TestOut,1),size(TestOut,1));
    TestIn         = TestIn(Test_randindex,:);
    TestOut        = TestOut(Test_randindex);
end
