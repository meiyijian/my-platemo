function nets = SRMaO_DropoutEnsemble(TrainIn, TrainOut, xDim, K, TrainW)
% Lightweight bagging ensemble of patternnet classifiers.

    if nargin < 4 || isempty(K)
        K = 5;
    end
    if nargin < 5 || isempty(TrainW)
        TrainW = ones(size(TrainIn,1),1);
    end

    nSample = size(TrainIn,1);
    if nSample < 5
        K = 1;
    end
    K = max(1,K);

    hidden = [max(1,xDim),max(1,ceil(xDim/2))];
    nBag   = max(2,ceil(0.70*nSample));
    nets   = cell(1,K);

    for i = 1 : K
        if K == 1 || nSample <= nBag
            sel = 1:nSample;
        else
            sel = randperm(nSample,nBag);
        end
        Xi = TrainIn(sel,:);
        Yi = TrainOut(sel,:);
        Wi = TrainW(sel);
        if mean(Wi) > 1e-12
            Wi = Wi ./ mean(Wi);
        else
            Wi = ones(size(Wi));
        end
        Wi = max(Wi,0.20)';

        net = patternnet(hidden);
        net.trainParam.showWindow      = 0;
        net.trainParam.showCommandLine = 0;
        net.trainParam.epochs          = 200;
        net.divideParam.trainRatio     = 0.8;
        net.divideParam.valRatio       = 0.2;
        net.divideParam.testRatio      = 0;

        try
            net = train(net,Xi',Yi',[],[],Wi);
        catch
            net = train(net,Xi',Yi');
        end
        nets{i} = net;
    end
end
