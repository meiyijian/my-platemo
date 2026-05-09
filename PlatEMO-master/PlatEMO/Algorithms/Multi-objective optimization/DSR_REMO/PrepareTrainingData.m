function [TrainIn, TrainOut, Elite, Poor] = PrepareTrainingData(Archive)
% PrepareTrainingData - Prepare training data using SDE screening and SDR labeling
%
% This function implements the core data preparation logic for DSR_REMO:
% 1. Calculate SDE scores for all solutions in Archive
% 2. Select top 25% as Elite pool, bottom 25% as Poor pool
% 3. Discard middle 50% samples
% 4. Generate ONLY EP and PE pairwise training samples with SDR-based labels
%
% Input:
%   Archive - SOLUTION array, containing evaluated solutions
%
% Output:
%   TrainIn  - P x 2D matrix, training input features (concatenated decs)
%   TrainOut - P x 1 vector, training labels (+1, 0, -1)
%   Elite    - SOLUTION array, elite solutions (top 25% by SDE)
%   Poor     - SOLUTION array, poor solutions (bottom 25% by SDE)
%
% Label convention:
%   +1 : x SDR-dominates y
%   -1 : y SDR-dominates x
%   0  : x and y are mutually non-dominated
%
% Note: Only EP (Elite-Poor) and PE (Poor-Elite) pairs are generated
%       to maximize feature difference and reduce computational cost.
%
% Copyright (c) 2025 BIMK Group.

    PopObj = Archive.objs;
    PopDec = Archive.decs;
    N = size(PopObj, 1);
    D = size(PopDec, 2);
    
    if N < 8
        Elite = Archive;
        Poor = Archive;
        TrainIn = [];
        TrainOut = [];
        return;
    end
    
    SDE = CalSDE(PopObj);
    
    [~, sortIndex] = sort(SDE, 'ascend');
    
    nElite = max(1, floor(N * 0.25));
    nPoor = max(1, floor(N * 0.25));
    
    eliteIndex = sortIndex(1:nElite);
    poorIndex = sortIndex(end-nPoor+1:end);
    
    Elite = Archive(eliteIndex);
    Poor = Archive(poorIndex);
    
    EliteDecs = Elite.decs;
    PoorDecs = Poor.decs;
    EliteObjs = Elite.objs;
    PoorObjs = Poor.objs;
    
    nE = size(EliteDecs, 1);
    nP = size(PoorDecs, 1);
    
    if nE < 1 || nP < 1
        TrainIn = [];
        TrainOut = [];
        return;
    end
    
    CombinedObj = [EliteObjs; PoorObjs];
    [dominate, ~, ~] = CalSDR(CombinedObj);
    
    EP_pairs = zeros(nE * nP, 2 * D);
    EP_labels = zeros(nE * nP, 1);
    idx = 0;
    for i = 1 : nE
        for j = 1 : nP
            idx = idx + 1;
            EP_pairs(idx, :) = [EliteDecs(i, :), PoorDecs(j, :)];
            idx_j = nE + j;
            if dominate(i, idx_j)
                EP_labels(idx) = 1;
            elseif dominate(idx_j, i)
                EP_labels(idx) = -1;
            else
                EP_labels(idx) = 0;
            end
        end
    end
    
    PE_pairs = zeros(nP * nE, 2 * D);
    PE_labels = zeros(nP * nE, 1);
    idx = 0;
    for i = 1 : nP
        for j = 1 : nE
            idx = idx + 1;
            PE_pairs(idx, :) = [PoorDecs(i, :), EliteDecs(j, :)];
            idx_i = nE + i;
            if dominate(idx_i, j)
                PE_labels(idx) = 1;
            elseif dominate(j, idx_i)
                PE_labels(idx) = -1;
            else
                PE_labels(idx) = 0;
            end
        end
    end
    
    TrainIn = [EP_pairs; PE_pairs];
    TrainOut = [EP_labels; PE_labels];
    
    if ~isempty(TrainIn)
        randIdx = randperm(size(TrainIn, 1));
        TrainIn = TrainIn(randIdx, :);
        TrainOut = TrainOut(randIdx);
    end
end
