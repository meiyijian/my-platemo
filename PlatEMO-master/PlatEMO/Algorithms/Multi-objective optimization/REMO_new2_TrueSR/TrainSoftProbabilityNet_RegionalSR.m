function [net,mpStruct] = TrainSoftProbabilityNet_RegionalSR(TrainIn,TrainOut)
% Train a feedforward probability model with normalized pair features.

    xDim = size(TrainIn,2);
    [TrainInNor,mpStruct] = mapminmax(TrainIn');
    TrainInNor = TrainInNor';

    net = feedforwardnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.layers{end}.transferFcn = 'logsig';
    net.trainFcn = 'trainscg';
    net.performFcn = 'mse';
    net.divideFcn = 'dividetrain';
    net.trainParam.showWindow = 0;
    net = train(net,TrainInNor',TrainOut');
end
