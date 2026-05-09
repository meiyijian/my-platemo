function [TrainIn1,TrainIn2,TrainOut,TestIn1,TestIn2,TestOut] = SiameseDataProcess(Input1,Input2,Labels)
% Split Siamese network data into training and test sets with stratified sampling
%
% Input1   - First branch inputs
% Input2   - Second branch inputs
% Labels   - Relation labels
% TrainIn1 - Training set first branch
% TrainIn2 - Training set second branch
% TrainOut - Training set labels
% TestIn1  - Test set first branch
% TestIn2  - Test set second branch
% TestOut  - Test set labels

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. All rights reserved.
%--------------------------------------------------------------------------

    pha = 3/4;  % Training set ratio

    % Find indices for each class
    index0  = find(Labels == 0);
    indexp1 = find(Labels == 1);
    indexn1 = find(Labels == -1);

    % Initialize selection arrays
    K0  = false(1,length(index0));
    Kp1 = false(1,length(indexp1));
    Kn1 = false(1,length(indexn1));

    % Randomly select 3/4 from each class
    K0(randperm(length(index0),ceil(pha*length(index0))))    = true;
    Kp1(randperm(length(indexp1),ceil(pha*length(indexp1)))) = true;
    Kn1(randperm(length(indexn1),ceil(pha*length(indexn1)))) = true;

    % Combine selected indices
    K = [index0(K0);indexp1(Kp1);indexn1(Kn1)];

    % Extract training set
    TrainIn1 = Input1(K,:);
    TrainIn2 = Input2(K,:);
    TrainOut = Labels(K);

    % Extract test set
    TestIdx = setdiff(1:size(Input1,1),K);
    TestIn1 = Input1(TestIdx,:);
    TestIn2 = Input2(TestIdx,:);
    TestOut = Labels(TestIdx);

    % Shuffle training set
    Train_randindex = randperm(size(TrainOut,1),size(TrainOut,1));
    TrainIn1 = TrainIn1(Train_randindex,:);
    TrainIn2 = TrainIn2(Train_randindex,:);
    TrainOut = TrainOut(Train_randindex);

    % Shuffle test set
    Test_randindex = randperm(size(TestOut,1),size(TestOut,1));
    TestIn1 = TestIn1(Test_randindex,:);
    TestIn2 = TestIn2(Test_randindex,:);
    TestOut = TestOut(Test_randindex);
end
