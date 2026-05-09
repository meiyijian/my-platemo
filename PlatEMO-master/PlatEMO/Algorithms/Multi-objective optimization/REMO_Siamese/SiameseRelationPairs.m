function [Input1,Input2,Labels] = SiameseRelationPairs(Input,Catalog)
% Build relation pairs for Siamese network
% The Siamese network takes two inputs (one per branch) instead of concatenated pairs
%
% Input   - Decision variables of all solutions
% Catalog - Classification of each solution (1=good, ~1=bad)
% Input1  - First branch inputs (N x D)
% Input2  - Second branch inputs (N x D)
% Labels  - Relation labels (0=similar, 1=C1优于C2, -1=C2优于C1)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. All rights reserved.
%--------------------------------------------------------------------------

    C1_index = Catalog == 1;
    C2_index = Catalog ~= 1;

    % Generate all possible pairs
    C1C1 = combvec(Input(Catalog ==1,:)',Input(Catalog ==1,:)')';
    C1C2 = combvec(Input(Catalog ==1,:)',Input(Catalog ~=1,:)')';
    C2C1 = combvec(Input(Catalog ~=1,:)',Input(Catalog ==1,:)')';
    C2C2 = combvec(Input(Catalog ~=1,:)',Input(Catalog ~=1,:)')';

    % Remove self-pairs for C1C1
    t_ind     = combvec(1:sum(C1_index),1:sum(C1_index));
    t_equ_ind = t_ind(1,:) == t_ind(2,:);
    C1C1(t_equ_ind,:) = [];

    % Remove self-pairs for C2C2
    t_ind     = combvec(1:sum(C2_index),1:sum(C2_index));
    t_equ_ind = t_ind(1,:) == t_ind(2,:);
    C2C2(t_equ_ind,:) = [];

    % Balance sample counts
    t_num = ceil(size(C1C2,1)/2);

    if size(C1C1,1) > t_num && size(C2C2,1) > t_num
        C1C1 = C1C1(randperm(size(C1C1,1),t_num),:);
        C2C2 = C2C2(randperm(size(C2C2,1),t_num),:);
    elseif size(C1C1,1) < t_num
        C2C2 = C2C2(randperm(size(C2C2,1),t_num*2-size(C1C1,1)),:);
    elseif size(C2C2,1) < t_num
        C1C1 = C1C1(randperm(size(C1C1,1),t_num*2-size(C2C2,1)),:);
    end

    % Split concatenated pairs into two branches for Siamese network
    D = size(Input,2);

    % C1C1 pairs: similar (label=0)
    C1C1_1 = C1C1(:,1:D);
    C1C1_2 = C1C1(:,D+1:end);

    % C2C2 pairs: similar (label=0)
    C2C2_1 = C2C2(:,1:D);
    C2C2_2 = C2C2(:,D+1:end);

    % C1C2 pairs: C1优于C2 (label=1)
    C1C2_1 = C1C2(:,1:D);
    C1C2_2 = C1C2(:,D+1:end);

    % C2C1 pairs: C2劣于C1 (label=-1)
    C2C1_1 = C2C1(:,1:D);
    C2C1_2 = C2C1(:,D+1:end);

    % Combine all pairs
    Input1 = [C1C1_1; C2C2_1; C1C2_1; C2C1_1];
    Input2 = [C1C1_2; C2C2_2; C1C2_2; C2C1_2];

    % Generate labels
    Labels = [zeros(size(C1C1,1),1); zeros(size(C2C2,1),1); ...
              ones(size(C1C2,1),1); -1.*ones(size(C2C1,1),1)];

    % Shuffle the data
    rand_idx = randperm(size(Labels,1));
    Input1 = Input1(rand_idx,:);
    Input2 = Input2(rand_idx,:);
    Labels = Labels(rand_idx,:);
end
