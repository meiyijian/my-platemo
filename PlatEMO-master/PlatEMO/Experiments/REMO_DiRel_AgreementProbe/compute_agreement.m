function rec = compute_agreement(Population, Catalog_F, Catalog_S, DualNet, S_easy, anchorMax, gen, FE)
% compute_agreement - Compute L1/L2/L3 agreement between full-objective and
% sub-objective networks for one snapshot.
%
% Inputs:
%   Population - PlatEMO population at this generation (N solutions)
%   Catalog_F  - N x 1 PBI label vector from full-objective (+1 / non+1)
%   Catalog_S  - N x 1 PBI label vector from sub-objective  (+1 / non+1)
%   DualNet    - struct from TrainDualScaleNet
%   S_easy     - easy-objective subset index (row vector)
%   anchorMax  - max anchor count for scoreAllByEnsemble_probe
%   gen        - current generation number
%   FE         - current Problem.FE
%
% Output:
%   rec - struct containing all metrics for this snapshot. Caller saves it.

    Input  = Population.decs;
    PopObj = Population.objs;
    N      = size(Input, 1);
    nPairsCap = 2000;

    rec = struct();
    rec.gen    = gen;
    rec.FE     = FE;
    rec.N      = N;
    rec.PopObj = PopObj;
    rec.S_easy = S_easy;

    % ----------------------------------------------------------------
    % L1: PBI label agreement
    % ----------------------------------------------------------------
    cf = Catalog_F(:);
    cs = Catalog_S(:);
    rec.label_F = cf;
    rec.label_S = cs;
    rec.agree_L1 = mean(cf == cs);
    % Binary confusion matrix on "is +1?"
    rec.confmat_L1 = confusionmat_binary(cf == 1, cs == 1);

    % ----------------------------------------------------------------
    % L2: ArbitratorScore mu sign agreement (population as candidates)
    % ----------------------------------------------------------------
    [mu_F, ~] = scoreAllByEnsemble_probe(Input, cf, DualNet.nets_F, DualNet.mp_struct_F, Input, anchorMax);

    % Sub-network input is decisions in full D (decision space) — the
    % network was trained on [x_i, x_j] of full D-dim decision vectors;
    % only the *label space* used sub-objectives. So candidates fed to
    % nets_S are the same Input matrix (full D), normalized by mp_struct_S.
    [mu_S, ~] = scoreAllByEnsemble_probe(Input, cs, DualNet.nets_S, DualNet.mp_struct_S, Input, anchorMax);

    rec.mu_F = mu_F;
    rec.mu_S = mu_S;
    sf = sign(mu_F);
    ss = sign(mu_S);
    rec.agree_L2 = mean(sf == ss);
    rec.confmat_L2 = confusionmat_binary(sf >= 0, ss >= 0);

    % ----------------------------------------------------------------
    % L3: relation-pair prediction agreement on a shared pair set
    % ----------------------------------------------------------------
    if N >= 2
        allPairs = nchoosek(1:N, 2);
        if size(allPairs, 1) > nPairsCap
            sel = randperm(size(allPairs, 1), nPairsCap);
            allPairs = allPairs(sel, :);
        end
        XX_shared = [Input(allPairs(:,1), :), Input(allPairs(:,2), :)];

        XF_nor = mapminmax('apply', XX_shared', DualNet.mp_struct_F)';
        XS_nor = mapminmax('apply', XX_shared', DualNet.mp_struct_S)';
        yhat_F = ensemblePredict_probe(DualNet.nets_F, XF_nor);
        yhat_S = ensemblePredict_probe(DualNet.nets_S, XS_nor);

        rec.yhat_F = yhat_F;
        rec.yhat_S = yhat_S;
        rec.agree_L3 = mean(yhat_F == yhat_S);
        rec.confmat_L3 = confusionmat3(yhat_F, yhat_S);
    else
        rec.yhat_F = [];
        rec.yhat_S = [];
        rec.agree_L3 = NaN;
        rec.confmat_L3 = zeros(3, 3);
    end
end


function C = confusionmat_binary(a, b)
% Rows = a (true), cols = b (predicted). Both logical.
    a = logical(a); b = logical(b);
    C = zeros(2, 2);
    C(1, 1) = sum(~a & ~b);
    C(1, 2) = sum(~a &  b);
    C(2, 1) = sum( a & ~b);
    C(2, 2) = sum( a &  b);
end


function C = confusionmat3(a, b)
% 3x3 confusion for labels in {+1, 0, -1}, row = a, col = b.
    classes = [1, 0, -1];
    C = zeros(3, 3);
    for i = 1:3
        for j = 1:3
            C(i, j) = sum(a == classes(i) & b == classes(j));
        end
    end
end
