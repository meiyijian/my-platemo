function [PopDec,PopObj,PopCon,ObjMSE,ConMSE] = Evolutionary_Search(A2,wmax,Model_obj,Model_con,Problem)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao.zhang.cn@gmail.com)

    index  = EnvironmentalSelection(A2.objs,A2.cons,Problem.N);
    PopDec = A2(index).decs;
    w      = 1;
    while w <= wmax
        OffDec = OperatorGA(Problem, PopDec);
        PopDec = [PopDec;OffDec];
        [PopObj,ObjMSE,PopCon,ConMSE] = model_predict(Model_obj,Model_con,PopDec);
        
        index  = SEnvironmentalSelection(PopDec,PopObj,ObjMSE,PopCon,ConMSE,Problem.N);
        PopDec = PopDec(index,:);
        PopObj = PopObj(index,:);
        PopCon = PopCon(index,:);
        ObjMSE = ObjMSE(index,:);
        ConMSE = ConMSE(index,:);
        w      = w + 1;
    end
end

function Next = EnvironmentalSelection(PopObj,PopCon,N)
    %% Non-dominated sorting
    zmin   = min(PopObj);
    zmax   = max(PopObj);
    PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);
    [FrontNo,MaxFNo] = NDSort(PopObj,PopCon,N);
    Next = FrontNo < MaxFNo;
    Last = find(FrontNo == MaxFNo);

    %% Select the solutions in the last front
    if MaxFNo == 1
        Del = Truncation(PopObj(Last,:),N);
        Next(Last(Del)) = true; 
    else
        Choose = Dist_Selection(PopObj(Next,:),PopObj(Last,:),N - sum(Next));
        Next(Last(Choose)) = true;
    end
end

function Next = SEnvironmentalSelection(PopDec,PopObj,ObjMSE,PopCon,ConMSE,N)
     %% Non-dominated sorting
    [FrontNo,MaxFNo] = NDSort_TSPP(PopDec,PopObj,ObjMSE,PopCon,ConMSE,N);
    Next   = FrontNo < MaxFNo;
    Last   = find(FrontNo == MaxFNo);
    zmin   = min(PopObj);zmax = max(PopObj);
    PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);

    %% Select the solutions in the last front
    if MaxFNo == 1
        Del = Truncation(PopObj(Last,:), N);
        Next(Last(Del)) = true; 
    else
        Choose = Dist_Selection(PopObj(Next,:), PopObj(Last,:), N-sum(Next));
        Next(Last(Choose)) = true;
    end
end

function Choose = Dist_Selection(PopObj1,PopObj2,mu)
    PopObj = [PopObj1;PopObj2];
    N      = size(PopObj,1);
    N1     = size(PopObj1,1);
    N2     = size(PopObj2,1);
    
    %% Calculate the distance between each two solutions
    for i = 1 : N
        for j = i+1 : N
            Distance(i,j) = norm(PopObj(i,:)-PopObj(j,:),2);
            Distance(j,i) = Distance(i,j);
        end
    end
    
    %% Calculate D
    Next1 = 1 : N1;
    Next2 = N1+1 : N;
    for i = 1 : mu
        Distance1    = sort(Distance(Next2,Next1),2);
        [~,index]    = max(Distance1(:,1));
        Next1        = [Next1,Next2(index)];
        Next2(index) = [];
    end
    Choose = Next1(N1+1:end) - N1;
end

function Del = Truncation(PopObj,K)
    %% Select part of the solutions by truncation
    [N,~]  = size(PopObj);

    %% Calculate the distance between each two solutions
    Distance = inf(N);
    for i = 1 : N
         for j = 1 : N
            Distance(i,j) = norm(PopObj(i,:) - PopObj(j,:),2);
        end
    end
    
    %% Truncation
    Distance(logical(eye(length(Distance)))) = inf;
    Del = true(1,N);
    while sum(Del) > K
        Remain   = find(Del);
        Temp     = sort(Distance(Remain,Remain),2);
        [~,Rank] = sortrows(Temp);
        Del(Remain(Rank(1))) = false;
    end
end

function [OffObj,Off_ObjMSE,OffCon,Off_ConMSE] = model_predict(Model_obj,Model_con,OffDec)
    N          = size(OffDec,1);
    Len_obj    = length(Model_obj);
    Len_con    = length(Model_con);
    OffObj     = zeros(N,Len_obj);
    OffCon     = zeros(N,Len_con);
    Off_ObjMSE = zeros(N,Len_obj);
    Off_ConMSE = zeros(N,Len_con);
      
    for i = 1 : N
        for j = 1 : Len_obj
            [OffObj(i,j),~,Off_ObjMSE(i,j)] = predictor(OffDec(i,:),Model_obj{j});
        end
        for j = 1 : Len_con
            [OffCon(i,j),~,Off_ConMSE(i,j)] = predictor(OffDec(i,:),Model_con{j});
        end
    end
    OffObj     = (OffObj);
    OffCon     = (OffCon);
    Off_ObjMSE = abs(Off_ObjMSE);
    Off_ConMSE = abs(Off_ConMSE);
end