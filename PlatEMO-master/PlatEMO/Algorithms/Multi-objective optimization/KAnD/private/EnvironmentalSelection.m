function index  = EnvironmentalSelection(PopObj,N)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao.zhang.cn@gmail.com)

    zmin = min(PopObj,[],1);zmax = max(PopObj,[],1);
    PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);
    [FrontNo,~] = NDSort(PopObj,1);
    index = find(FrontNo == 1);
    index_d = find(FrontNo ~= 1);
    % nondominated-solution-led strategy
    if size(PopObj,1) > N
        if length(index) > N
            PObj   = PopObj(index,:);
            Delete = LastSelection(PObj,length(index)-N);
            index  = index(~Delete);
        elseif length(index) < N
            PObj    = PopObj(index_d,:);
            Delete  = LastSelection(PObj,length(index_d)-(N-length(index)));
            index_d = index_d(~Delete);
            index   = [index,index_d];
        end
    end
end

function Delete = LastSelection(PopObj,K)
    % Select part of the solutions in the last front
    [N,~]  = size(PopObj);
    %% Associate each solution with one reference point
    % Calculate the distance of each solution to each reference vector
    Cosine   = 1 - pdist2(PopObj,PopObj,'cosine');
    Cosine   = Cosine.*(1-eye(size(PopObj,1)));
    SDE = zeros(1,N);
    for i=1:N
        SPopuObj = PopObj;
        Temp     = repmat(PopObj(i,:),N,1);
        Shifted  = PopObj < Temp;
        SPopuObj(Shifted) = Temp(Shifted);
        Distance = pdist2(PopObj(i,:),SPopuObj);
        [~,index] = sort(Distance,2);
        SDE(i) = Distance(index(1));
    end

    %% Environmental selection
    Delete  = false(1,N);
    % Select K solutions one by one
    while sum(Delete) < K
        [Jmin_row,Jmin_column] = find(Cosine==max(max(Cosine)));
        j = randi(length(Jmin_row));
        Temp_1 = Jmin_row(j);
        Temp_2 = Jmin_column(j);

        if  (SDE(Temp_1)<SDE(Temp_2)) ||(SDE(Temp_1)==SDE(Temp_2) && rand<0.5)
            Delete(Temp_1) = true;
            Cosine(:,Temp_1)=0;
            Cosine(Temp_1,:)=0;
        else
            Delete(Temp_2) = true;
            Cosine(:,Temp_2)=0;
            Cosine(Temp_2,:)=0;
        end
    end
end