function [TrainIn,TrainOut,TestIn,TestOut] = DataProcessSoft(Input,Output,trainRatio)
% 将数据集随机划分为训练集和测试集（用于连续的软排序目标值）
%
% 输入参数：
%   Input     : 输入数据矩阵，每一行是一个样本的特征向量
%   Output    : 输出数据矩阵，每一行是一个样本对应的目标值（这里是软排序概率）
%   trainRatio: 训练集占比，默认 0.75（即 75% 用于训练，25% 用于测试）
%
% 输出参数：
%   TrainIn   : 训练集的输入数据（特征）
%   TrainOut  : 训练集的输出数据（目标值）
%   TestIn    : 测试集的输入数据（特征）
%   TestOut   : 测试集的输出数据（目标值）

    % 如果用户没有传入 trainRatio 参数，默认设为 0.75
    if nargin < 3
        trainRatio = 0.75;
    end

    % 获取样本总数（Input 的行数）
    sampleNum = size(Input,1);

    % 如果样本数为 0（空数据），直接返回空矩阵
    if sampleNum == 0
        TrainIn  = [];
        TrainOut = [];
        TestIn   = [];
        TestOut  = [];
        return;
    end

    % 生成 1 到 sampleNum 的随机排列，用于打乱数据顺序
    % 例如 sampleNum=10 时，可能得到 index = [3,7,1,9,5,2,8,4,6,10]
    index = randperm(sampleNum);

    % 确定训练集样本数量
    if sampleNum == 1
        % 只有一个样本时，训练集也用这 1 个样本
        trainNum = 1;
    else
        % 向上取整，例如 10 个样本 * 0.75 = 7.5 → 向上取整为 8 个训练样本
        trainNum = ceil(trainRatio * sampleNum);
        % 保证训练样本数至少为 1，最多为 sampleNum-1（至少要留一个测试样本）
        trainNum = min(max(trainNum,1),sampleNum-1);
    end

    % 取随机排列的前 trainNum 个作为训练索引
    trainIndex = index(1:trainNum);
    % 取随机排列的剩余部分作为测试索引
    testIndex  = index(trainNum+1:end);

    % 按索引提取对应的数据行
    TrainIn  = Input(trainIndex,:);
    TrainOut = Output(trainIndex,:);
    TestIn   = Input(testIndex,:);
    TestOut  = Output(testIndex,:);
end
