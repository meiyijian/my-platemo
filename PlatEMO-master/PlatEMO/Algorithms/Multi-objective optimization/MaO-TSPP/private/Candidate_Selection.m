function PopNew = Candidate_Selection(PopDec,PopObj,PopCon,ObjMSE,ConMSE,A1,mu,Problem)

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
    index = ismember(PopDec,A1.decs,'rows');
    if sum(index) == size(PopDec,1)
        PopNew = [];
        return;
    elseif sum(~index) <= mu
        PopNew_ = PopDec(~index,:);
        PopNew  = [];
        for i = 1 : size(PopNew_,1)
            dist2 = pdist2(real(PopNew_(i,:)),real(A1.decs));
            if min(dist2) > 1e-20
                PopNew = [PopNew;PopNew_(i,:)];
            end
        end
        if isempty(PopNew) == 0
            PopNew = Problem.Evaluation(PopNew);
        end
        return;
    end
    
    PopDec = PopDec(~index,:);
    PopObj = PopObj(~index,:);
    ObjMSE = ObjMSE(~index,:);
    PopCon = PopCon(~index,:);
    ConMSE = ConMSE(~index,:);

    A2Obj  = A1.objs;
    A2Con  = A1.cons;
    zmin   = min([A2Obj;PopObj],[],1);
    zmax   = max([A2Obj;PopObj],[],1);
    A2Obj  = (A2Obj - zmin )./max(zmax - zmin,10e-10);
    PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);
    ObjMSE = ObjMSE./(max(zmax - zmin,10e-10).^2);
    
    %% Reference Set 
    num = length(find(all(A2Con<=0,2)));
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

    %% Selection
    [FrontNo,MaxFNo] = NDSort_TSPP(PopDec,PopObj,ObjMSE,PopCon,ConMSE,mu);
    Next = FrontNo < MaxFNo;
    Last = find(FrontNo == MaxFNo);

    if length(Last) == mu - sum(Next)
        Next(Last) = true;
        PopNew     = Problem.Evaluation(PopDec(Next,:));
    elseif length(Last) > mu - sum(Next)
        if sum(Next) >= 1
            PopNew = Problem.Evaluation(PopDec(Next,:));
            A2Obj  = [A2Obj; (PopNew.objs - zmin)./max(zmax - zmin,10e-10)];
        else
            PopNew = [];
        end
        while length(find(Next==1)) < mu
            Dis      = EucDistance(PopObj(Last,:),A2Obj);
            [~,Rank] = sort(Dis,'descend');
            PopNew   = [PopNew,Problem.Evaluation(PopDec(Last(Rank(1)),:))];
            A2Obj    = [A2Obj; (PopNew.objs - zmin)./max(zmax - zmin,10e-10)];
            A2Obj    = unique(A2Obj,'rows');
            Next(Last(Rank(1))) = true;
            Last(Rank(1))       = [];
        end
    end
end

function Distance = EucDistance(PopObj,ALL_Obj)
    N1 = size(PopObj,1);
    N2 = size(ALL_Obj,1);

    %% Calculate the distance between each two solutions
    Distance = acos(1-pdist2(PopObj,ALL_Obj,'cosine'));
    Distance = sort(Distance,2);
    Distance = Distance(:,1);
end