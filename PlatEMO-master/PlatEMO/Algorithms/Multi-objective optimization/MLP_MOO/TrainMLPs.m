function [surrogates, dec_min, dec_max, obj_min, obj_max] = TrainMLPs(Archive, D, M)
% Train one MLP per objective using the evaluated solutions in Archive.
    % Extract data
    X = [Archive.decs];
    Y = [Archive.objs];
    N = size(X,1);
    
    % Normalize inputs to [0,1] (per dimension)
    dec_min = min(X, [], 1);
    dec_max = max(X, [], 1);
    if any(dec_max == dec_min)
        constant = dec_max == dec_min;
        dec_min(constant) = 0;
        dec_max(constant) = 1;
    end
    X_norm = (X - dec_min) ./ (dec_max - dec_min);
    X_norm(isnan(X_norm)) = 0;
    
    % Normalize outputs to [0,1] per objective
    obj_min = min(Y, [], 1);
    obj_max = max(Y, [], 1);
    if any(obj_max == obj_min)
        constant = obj_max == obj_min;
        obj_min(constant) = 0;
        obj_max(constant) = 1;
    end
    Y_norm = (Y - obj_min) ./ (obj_max - obj_min);
    Y_norm(isnan(Y_norm)) = 0;
    
    % Train one MLP per objective
    surrogates = cell(M,1);
    for i = 1:M
        % Create a simple MLP with two hidden layers (size = D*1.5 and D)
        net = feedforwardnet([ceil(D*1.5), D]);
        net.trainFcn = 'trainlm';    % Levenberg-Marquardt
        net.trainParam.showWindow = 0;
        net.divideFcn = 'dividerand';
        net.divideParam.trainRatio = 0.8;
        net.divideParam.valRatio   = 0.2;
        net.divideParam.testRatio   = 0.0;
        % Train
        net = train(net, X_norm', Y_norm(:,i)');
        % Store model with normalization parameters
        surrogates{i} = struct(...
            'net', net, ...
            'dec_min', dec_min, ...
            'dec_max', dec_max, ...
            'obj_min', obj_min(i), ...
            'obj_max', obj_max(i));
        % Add predict method
        surrogates{i}.predict = @(x) predict_mlp(surrogates{i}, x);
    end
end

function y_pred = predict_mlp(surrogate, X)
% Predict objective values for new decision vectors X (matrix, rows = samples)
    % Normalize inputs
    dec_min = surrogate.dec_min;
    dec_max = surrogate.dec_max;
    X_norm = (X - dec_min) ./ (dec_max - dec_min);
    X_norm(isnan(X_norm)) = 0;
    % Predict normalized output
    y_norm = surrogate.net(X_norm')';
    % Denormalize
    y_pred = y_norm .* (surrogate.obj_max - surrogate.obj_min) + surrogate.obj_min;
end