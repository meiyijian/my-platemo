function [TrainIn,TrainOut,TrainW,ValidIn,ValidOut,ValidW] = CADataProcess(Input,Output,Weight)
% Stratified relation-pair split. The validation subset is used only for
% relation model management, not for fitting the neural network.

    trainIndex = [];
    labels = [-1;0;1];
    for i = 1 : numel(labels)
        current = find(Output == labels(i));
        if isempty(current)
            continue;
        end
        n = numel(current);
        if n == 1
            chosen = current;
        else
            trainNum = min(n-1,max(1,ceil(0.75*n)));
            chosen = current(randperm(n,trainNum));
        end
        trainIndex = [trainIndex;chosen(:)]; %#ok<AGROW>
    end

    validIndex = setdiff((1:size(Input,1))',trainIndex);
    if isempty(validIndex)
        validIndex = trainIndex;
    end

    trainIndex = trainIndex(randperm(numel(trainIndex)));
    validIndex = validIndex(randperm(numel(validIndex)));

    TrainIn  = Input(trainIndex,:);
    TrainOut = Output(trainIndex);
    TrainW   = Weight(trainIndex);
    ValidIn  = Input(validIndex,:);
    ValidOut = Output(validIndex);
    ValidW   = Weight(validIndex);
end
