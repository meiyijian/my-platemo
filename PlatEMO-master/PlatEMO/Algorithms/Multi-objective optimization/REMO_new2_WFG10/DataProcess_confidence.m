function [TrainIn,TrainOut,TrainW,TestIn,TestOut,TestW] = DataProcess_confidence(Input,Output,Weight)
% 在原 DataProcess 基础上, 同步划分关系对的样本权重
% 按类别 (0, +1, -1) 分层抽样, 训练集 3/4, 测试集 1/4
%
% 输入:
%   Input  - n_pair x 2D 关系对样本
%   Output - n_pair x 1 关系标签 {-1, 0, +1}
%   Weight - n_pair x 1 样本权重
% 输出:
%   TrainIn, TrainOut, TrainW  - 训练集（75%）
%   TestIn, TestOut, TestW     - 测试集（25%）

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
    Weight  = Weight(:);

    %% ============ 按类别分层 ============
    % 找到三类样本的索引
    index0  = find(Output == 0);   % 同类对（好-好 或 坏-坏）
    indexp1 = find(Output == 1);   % 好-坏对（前者优于后者）
    indexn1 = find(Output == -1);  % 坏-好对（前者劣于后者）

    % 初始化逻辑索引（false 表示进入测试集）
    K0  = false(1,length(index0));
    Kp1 = false(1,length(indexp1));
    Kn1 = false(1,length(indexn1));

    %% ============ 分层抽样 ============
    % 对每个类别独立抽样 75% 进入训练集
    if ~isempty(index0)
        K0(randperm(length(index0),ceil(pha*length(index0))))    = true;
    end
    if ~isempty(indexp1)
        Kp1(randperm(length(indexp1),ceil(pha*length(indexp1)))) = true;
    end
    if ~isempty(indexn1)
        Kn1(randperm(length(indexn1),ceil(pha*length(indexn1)))) = true;
    end

    %% ============ 划分训练集 ============
    % 合并所有类别的训练索引
    K        = [index0(K0); indexp1(Kp1); indexn1(Kn1)];
    TrainIn  = Input(K,:);
    TrainOut = Output(K);
    TrainW   = Weight(K);

    %% ============ 划分测试集 ============
    % 剩余样本进入测试集
    notK     = setdiff(1:size(Input,1),K);
    TestIn   = Input(notK,:);
    TestOut  = Output(notK);
    TestW    = Weight(notK);

    %% ============ 打乱顺序 ============
    % 训练集打乱（防止按类别顺序排列影响训练）
    Train_idx = randperm(size(TrainOut,1),size(TrainOut,1));
    TrainIn   = TrainIn(Train_idx,:);
    TrainOut  = TrainOut(Train_idx);
    TrainW    = TrainW(Train_idx);

    % 测试集打乱
    Test_idx = randperm(size(TestOut,1),size(TestOut,1));
    TestIn   = TestIn(Test_idx,:);
    TestOut  = TestOut(Test_idx);
    TestW    = TestW(Test_idx);
end