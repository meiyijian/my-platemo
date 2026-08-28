function CMCWarmupLearningToolboxes()
%CMCWARMUPLEARNINGTOOLBOXES Remove first-call initialization from paired runs.

    saved = rng;
    cleanup = onCleanup(@()rng(saved));
    rng(20260824,'twister');
    inputs = rand(20,4);
    outputs = double(inputs(:,1)>0.5);
    network = patternnet(2);
    network.trainParam.showWindow = 0;
    train(network,inputs',outputs');
    try
        fitrsvm(inputs,outputs,'KernelFunction','rbf', ...
            'KernelScale','auto','Standardize',true);
    catch exception
        warning('CMC:SVMWarmupFailed', ...
            'SVM warm-up failed; HCV will use its frozen fallback: %s.', ...
            exception.message);
    end
end
