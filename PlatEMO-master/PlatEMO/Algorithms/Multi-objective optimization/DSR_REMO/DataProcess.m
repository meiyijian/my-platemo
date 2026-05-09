function [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(Input, Output)
% DataProcess - Divide the data into training and test sets robustly
% Copyright (c) 2025 BIMK Group.

    pha = 0.75;
    classes = unique(Output);
    train_idx = [];
    
    % [核心修复]: 使用循环安全地提取每一类的索引，防止垂直拼接不同维度矩阵崩溃
    for i = 1 : length(classes)
        idx = find(Output == classes(i));
        num_train = ceil(pha * length(idx));
        rp = randperm(length(idx));
        train_idx = [train_idx; idx(rp(1:num_train))]; 
    end
    
    if isempty(train_idx)
        TrainIn = []; 
        TrainOut =[]; 
        TestIn = Input; 
        TestOut = Output;
        return;
    end
    
    test_idx = setdiff(1:size(Input, 1), train_idx)';
    
    % Shuffle
    train_idx = train_idx(randperm(length(train_idx)));
    test_idx = test_idx(randperm(length(test_idx)));
    
    TrainIn = Input(train_idx, :);
    TrainOut = Output(train_idx);
    TestIn = Input(test_idx, :);
    TestOut = Output(test_idx);
end