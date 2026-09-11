function [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(Input,Output)
%DataProcess 按关系标签分层划分训练集与留出集。
%   [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(Input,Output)
%   将有序解对 Input 按 Output 的三类标签分别随机划分，约 75% 用于训练，
%   其余用于计算关系对留出误差 e_r。每类的训练数量向上取整。
%   划分单位是有序解对，同一基础解可以出现在不同解对中。
%   最后分别打乱训练集和留出集的样本顺序。

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
    index0  = find(Output==0);    % 同组对
    indexp1 = find(Output == 1);  % 正组-非正组对
    indexn1 = find(Output == -1); % 非正组-正组对

    % 初始化逻辑索引（false 表示进入留出集）
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

    %% ============ 划分留出集 ============
    % 剩余样本进入留出集
    TestIn  = Input(setdiff(1:size(Input,1),K),:);
    TestOut = Output(setdiff(1:size(Input,1),K));

    %% ============ 打乱顺序 ============
    % 训练集打乱
    Train_randindex = randperm(size(TrainOut,1),size(TrainOut,1));
    TrainIn         = TrainIn(Train_randindex,:);
    TrainOut        = TrainOut(Train_randindex);

    % 留出集打乱
    Test_randindex = randperm(size(TestOut,1),size(TestOut,1));
    TestIn         = TestIn(Test_randindex,:);
    TestOut        = TestOut(Test_randindex);
end
