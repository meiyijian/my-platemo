function pred = ensemblePredict_probe(nets, X)
% ensemblePredict_probe - Local copy of TrainDualScaleNet's private
% ensemblePredict, used by the AgreementProbe experiment.
%
% Inputs:
%   nets - 1xK cell of patternnet, may contain empty cells
%   X    - n x D normalized input (rows are samples)
%
% Output:
%   pred - n x 1 label vector in {+1, 0, -1}
%
% Algorithm: each valid net predicts onehot, label is argmax mapped back;
% final label is the mode across K nets.

    N = size(X, 1);

    valid = ~cellfun(@isempty, nets);
    nets_v = nets(valid);
    if isempty(nets_v)
        pred = zeros(N, 1);
        return;
    end

    K = numel(nets_v);
    votes = zeros(N, K);

    for i = 1:K
        try
            out_oh = nets_v{i}(X')';
            [~, maxind] = max(out_oh, [], 2);
            v = zeros(N, 1);
            v(maxind == 1) =  1;
            v(maxind == 3) = -1;
            votes(:, i) = v;
        catch
            votes(:, i) = 0;
        end
    end

    pred = mode(votes, 2);
end
