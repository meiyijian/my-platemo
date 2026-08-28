function [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(Input,Output)
% DataProcess - 关系对数据集划分（原始版本，无权重）
%
% 按关系标签 (0, +1, -1) 分层抽样, 训练集 3/4, 测试集 1/4
% 注意：这是按关系对随机划分，不是按基础解划分；同一端点和反向关系可能跨越训练/测试集。
%
% 分层抽样的目的：
%   保持三类关系标签比例大致一致，避免某类关系完全缺失
%
% 输入:
%   Input  - n_pair x 2D 关系对样本
%   Output - n_pair x 1 关系标签 {-1, 0, +1}
% 输出:
%   TrainIn, TrainOut  - 关系对训练集（75%）
%   TestIn, TestOut    - 关系对留出集（25%）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 训练集占比 75%
    pha     = 3/4;

    %% ============ 按类别分层 ============
    % 找到三类样本的索引
    index0  = find(Output==0);    % 同类对
    indexp1 = find(Output == 1);  % 好-坏对
    indexn1 = find(Output == -1); % 坏-好对

    % 初始化逻辑索引（false 表示进入测试集）
    K0  = false(1,length(index0));
    Kp1 = false(1,length(indexp1));
    Kn1 = false(1,length(indexn1));

    %% ============ 分层抽样 ============
    % 对每个类别独立抽样 75% 进入训练集
    K0(randperm(length(index0),ceil(pha*length(index0))))    = true;
    Kp1(randperm(length(indexp1),ceil(pha*length(indexp1)))) = true;
    Kn1(randperm(length(indexn1),ceil(pha*length(indexn1)))) = true;

    %% ============ 划分训练集 ============
    % 合并所有类别的训练索引
    K        = [index0(K0);indexp1(Kp1);indexn1(Kn1)];
    TrainIn  = Input(K,:);
    TrainOut = Output(K);

    %% ============ 划分测试集 ============
    % 剩余样本进入测试集
    TestIn  = Input(setdiff(1:size(Input,1),K),:);
    TestOut = Output(setdiff(1:size(Input,1),K));

    %% ============ 打乱顺序 ============
    % 训练集打乱
    Train_randindex = randperm(size(TrainOut,1),size(TrainOut,1));
    TrainIn         = TrainIn(Train_randindex,:);
    TrainOut        = TrainOut(Train_randindex);

    % 测试集打乱
    Test_randindex = randperm(size(TestOut,1),size(TestOut,1));
    TestIn         = TestIn(Test_randindex,:);
    TestOut        = TestOut(Test_randindex);
end
