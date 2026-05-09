function [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(Input, Output)
% DataProcess - 按 3:1 比例划分训练集和测试集
%
% 复制自 REMO_new2_clean/DataProcess.m，本版本针对二元标签 0/1 简化分层抽样。
% 保持各类别在训练/测试集中的比例与原始数据一致。

    pha     = 3 / 4;
    indexp1 = find(Output == 1);
    indexn0 = find(Output == 0);

    Kp1 = false(1, length(indexp1));
    Kn0 = false(1, length(indexn0));

    Kp1(randperm(length(indexp1), ceil(pha * length(indexp1)))) = true;
    Kn0(randperm(length(indexn0), ceil(pha * length(indexn0)))) = true;

    K = [indexp1(Kp1); indexn0(Kn0)];
    TrainIn  = Input(K, :);
    TrainOut = Output(K);

    rest = setdiff(1 : size(Input, 1), K);
    TestIn  = Input(rest, :);
    TestOut = Output(rest);

    % 训练集打乱
    rp = randperm(size(TrainIn, 1));
    TrainIn  = TrainIn(rp, :);
    TrainOut = TrainOut(rp);

    % 测试集打乱
    rp = randperm(size(TestIn, 1));
    TestIn  = TestIn(rp, :);
    TestOut = TestOut(rp);
end
