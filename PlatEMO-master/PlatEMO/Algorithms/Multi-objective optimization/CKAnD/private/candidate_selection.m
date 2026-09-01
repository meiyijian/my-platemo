function PopNew = candidate_selection(PopDec,PopObj,PopCon,A2,mu,Problem)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao.zhang.cn@gmail.com)

    %% Preparing Data
    index = ismember(PopDec,A2.decs,'rows');
    if sum(index) == size(PopDec,1)
        PopNew = [];
        return;
    end
    
    PopDec = PopDec(~index,:);
    PopObj = PopObj(~index,:); 
    PopCon = PopCon(~index,:); 
    CV     = sum(max(0,PopCon),2);
    
    A2Obj  = A2.objs;
    A2Con  = A2.cons;
    zmin   = min([A2Obj;PopObj],[],1); zmax = max([A2Obj;PopObj],[],1);
    A2Obj  = (A2Obj - zmin )./max(zmax - zmin,10e-10);
    PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);
    
    %% Reference Set 
    num         = length(find(all(A2Con<=0,2)));
    [FrontNo,~] = NDSort(A2Obj,A2Con,inf);
    if num >= Problem.N
        A2Obj = A2Obj(FrontNo==1,:);
    else
        i    = 1;
        Next = FrontNo == i;
        while sum(Next) < Problem.N
            Next(FrontNo == i) = true;
            i = i + 1;
        end
        A2Obj = A2Obj(Next,:);
    end

    %% Select mu points
    fea_index   = find(CV==0);
    infea_index = find(CV~=0);
    if isempty(fea_index)
        [~,rank] = sort(CV(infea_index));
        PopNew   = PopDec(infea_index(rank(1:mu)),:);
    else
        I_SDE   = SDE_dist(PopObj(fea_index,:),A2Obj);
        I_Angle = Angle_dist(PopObj(fea_index,:),A2Obj);
        newObj  = [-I_SDE,-I_Angle];
        FrontNo = NDSort(newObj,1);
        PopNew  = PopDec(fea_index(FrontNo==1),:);
    end 
    PopNew = unique(PopNew,'rows');
end


function Distance = SDE_dist(PopObj,ALL_Obj)
    N1       = size(PopObj,1);
    N2       = size(ALL_Obj,1);
    Distance = zeros(N1,N2);

    %% Calculate the shifted distance between each two solutions
    for i = 1 : N1
        SPopObj = max(ALL_Obj,repmat(PopObj(i,:),N2,1));
        for j = 1 : N2
            Distance(i,j) = norm(PopObj(i,:)-SPopObj(j,:),2);    
        end
    end
    Distance = sort(Distance,2);
    Distance = Distance(:,1);
end

function Distance = Angle_dist(PopObj,OffObj)
    Distance = acos(1-pdist2(PopObj,OffObj,'cosine'));
    Distance = sort(Distance,2);
    Distance = Distance(:,1);
end