function classifiers = TrainSubproblemClassifiers(Population, sub_weights)
% Train one MLP binary classifier per subproblem using current population.
% Input:
%   Population   - INDIVIDUAL array
%   sub_weights  - cell array of weight vectors (each row sums to 1)
% Output:
%   classifiers  - cell array of structs with .net, .dec_min, .dec_max

    X = [Population.decs];
    Y = [Population.objs];
    N = size(X,1);
    
    % Normalize decision variables to [0,1]
    dec_min = min(X, [], 1);
    dec_max = max(X, [], 1);
    constant = (dec_max == dec_min);
    dec_min(constant) = 0;
    dec_max(constant) = 1;
    X_norm = (X - dec_min) ./ (dec_max - dec_min);
    X_norm(isnan(X_norm)) = 0;
    
    classifiers = cell(length(sub_weights), 1);
    
    for s = 1:length(sub_weights)
        w = sub_weights{s};
        % Scalarized objective value for each solution (minimization)
        scalar = Y * w';  % smaller is better
        
        % Construct pairwise training data (i,j) for all i≠j
        % Use all pairs if N <= 200, else sample up to 20000 pairs
        max_pairs = min(20000, N*(N-1));
        pair_idx = randperm(N*(N-1), max_pairs);
        input_pairs = zeros(max_pairs, 2*size(X,2));
        labels = zeros(max_pairs, 1);
        for k = 1:max_pairs
            [i,j] = ind2sub([N,N], pair_idx(k));
            if i == j
                continue;
            end
            input_pairs(k,:) = [X_norm(i,:), X_norm(j,:)];
            if scalar(i) < scalar(j)
                labels(k) = 1;  % i is better than j
            else
                labels(k) = 0;
            end
        end
        % Remove invalid rows (if i=j)
        valid = any(input_pairs,2);
        input_pairs = input_pairs(valid,:);
        labels = labels(valid);
        
        % Train MLP classifier (binary)
        net = patternnet([ceil(size(X,2)*1.5), size(X,2)]);
        net.trainFcn = 'trainlm';
        net.trainParam.showWindow = 0;
        net.divideFcn = 'dividerand';
        net.divideParam.trainRatio = 0.8;
        net.divideParam.valRatio = 0.2;
        net.divideParam.testRatio = 0.0;
        target = ind2vec(labels' + 1);  % labels 0/1 -> class 1/2
        net = train(net, input_pairs', target);
        
        % Store classifier with normalization parameters
        classifiers{s} = struct(...
            'net', net, ...
            'dec_min', dec_min, ...
            'dec_max', dec_max);
        classifiers{s}.predict = @(x) predict_subproblem(classifiers{s}, x);
    end
end

function prob = predict_subproblem(classifier, x_pair)
% x_pair: matrix of concatenated decision vectors (rows = pairs)
    dec_min = classifier.dec_min;
    dec_max = classifier.dec_max;
    % Normalize each pair's decision variables
    x_pair_norm = (x_pair - [dec_min, dec_min]) ./ ([dec_max, dec_max] - [dec_min, dec_min]);
    x_pair_norm(isnan(x_pair_norm)) = 0;
    % Predict
    y = classifier.net(x_pair_norm')';
    % y is 2-column softmax; probability of class 2 (label=1) is y(:,2)
    prob = y(:,2);
end