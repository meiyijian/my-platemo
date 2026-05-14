function [TrainIn, TrainOut, TrainW, TestIn, TestOut] = SRMaO_DataProcess(Input, Output, Weight)
% Stratified 3:1 train/test split for binary relation samples.

    Output = Output(:);
    Weight = Weight(:);
    if isempty(Weight)
        Weight = ones(size(Output));
    end

    trainRatio = 3/4;
    idx1 = find(Output == 1);
    idx0 = find(Output == 0);

    sel1 = selectTrain(idx1,trainRatio);
    sel0 = selectTrain(idx0,trainRatio);
    trainIdx = [sel1;sel0];
    if isempty(trainIdx)
        trainIdx = (1:size(Input,1))';
    end

    TrainIn  = Input(trainIdx,:);
    TrainOut = Output(trainIdx);
    TrainW   = Weight(trainIdx);

    testIdx = setdiff((1:size(Input,1))',trainIdx);
    TestIn  = Input(testIdx,:);
    TestOut = Output(testIdx);

    if ~isempty(TrainIn)
        rp = randperm(size(TrainIn,1));
        TrainIn  = TrainIn(rp,:);
        TrainOut = TrainOut(rp);
        TrainW   = TrainW(rp);
    end
    if ~isempty(TestIn)
        rp = randperm(size(TestIn,1));
        TestIn  = TestIn(rp,:);
        TestOut = TestOut(rp);
    end
end

function selected = selectTrain(idx,trainRatio)
    idx = idx(:);
    if isempty(idx)
        selected = idx;
        return;
    end
    n = max(1,ceil(trainRatio*numel(idx)));
    selected = idx(randperm(numel(idx),n));
end
