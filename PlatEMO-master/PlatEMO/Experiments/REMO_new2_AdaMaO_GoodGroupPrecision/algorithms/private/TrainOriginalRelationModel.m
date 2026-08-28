function [net,TrainIn_struct,p_err] = TrainOriginalRelationModel(XXs,YYs)
%TrainOriginalRelationModel Copy of the frozen local function from
%   REMO_new2_AdaMaO_SDEOnly_UniformMix_Original.m (statement-for-statement,
%   including random-number consumption via DataProcess and patternnet
%   training). Used by the audit base class and the equivalence diagnoses.

    [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,TrainIn_nor',TrainOut_onehot');

    if isempty(TestIn)
        p_err = 1;
    else
        TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
        TestPre = onehotconv(net(TestIn_nor')',2);
        p_err = sum(TestPre ~= TestOut) / size(TestPre,1);
    end
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
end
