function PopDec = EGOSelect_CEI(Problem,Population,L1,L2,Ke,delta,nr)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao.zhang.cn@gmail.com)

    %% Fuzzy clustering the solutions
    [model,centers] = FCMmodel(Problem,Population,L1,L2);
    len_con         = size(Population.cons,2);
    index           = sum(Population.cons <= 0, 2) == len_con;
    if sum(index) > 0
        feasible = 1;
    else
        feasible = 0;
    end

    %% MOEA/D-DE optimization, where the popsize is set to N, the maximum evaluations is maxeva
	Z    = min(Population.objs,[],1);
    wmax = 20;

	%% Generate the weight vectors
    [W, N] = UniformPoint(Problem.N,Problem.M);
    T      = ceil(N/10);
    B      = pdist2(W,W);
    [~,B]  = sort(B,2);
    B      = B(:,1:T);
    for i = 1 : N
        if feasible
            gmin(i) = min(max(repmat(abs(Population(index).objs - Z),length(Population(index)),1).*W(i,:),[],2));
        else
            gmin(i) = max(0,min(min(Population.cons)));
        end
    end
    
    Next = true(1,length(Population));
    for i = 1 : N
        [~,index] = min(max(repmat(abs(Population(Next).objs - Z),sum(Next),1).*W(i,:),[],2));
        index_    = find(Next);
        Next(index_(index)) = false;
    end
    NewPop = Population(~Next);  % Sample N individuals from the initial population
    PopDec = NewPop.decs; 
    
    for i = 1 : N
        if rand < delta
            P = B(i,randperm(size(B,2)));
        else
            P = randperm(N);
        end
        OffDec(i,:) = OperatorDE(Problem,PopDec(i,:),PopDec(P(1),:),PopDec(P(2),:));
        [OffObj(i,:),OffObj_MSE(i,:),OffCon(i,:),OffCon_MSE(i,:)] = Evaluate(Problem,OffDec(i,:),model,centers);
    end
    PopDec = OffDec;
    PopObj = OffObj;PopObj_MSE = OffObj_MSE; 
    PopCon = OffCon;PopCon_MSE = OffCon_MSE; 
    
    w = 1;
    while w <= wmax
        for i = 1 : N
            if rand < delta
                P = B(i,randperm(size(B,2)));
            else
                P = randperm(N);
            end
            OffDec = OperatorDE(Problem, PopDec(i,:),PopDec(P(1),:),PopDec(P(2),:));
            [OffObj,OffObj_MSE,OffCon,OffCon_MSE] = Evaluate(Problem,OffDec,model,centers);
            EI_old = zeros(length(P),1);
            EI_new = zeros(length(P),1);
            for j = 1 : length(P)
                EI_old(j) = EICal(real(PopObj(P(j),:)),abs(PopObj_MSE(P(j),:)),real(PopCon(P(j),:)),abs(PopCon_MSE(P(j),:)),Z,W(P(j),:),gmin(P(j)),feasible);
                EI_new(j) = EICal(real(OffObj),abs(OffObj_MSE),real(OffCon),abs(OffCon_MSE),Z,W(P(j),:),gmin(P(j)),feasible);
            end
            offindex = P(find(EI_old < EI_new,nr));
            if ~isempty(offindex)
                PopDec(offindex,:)     = repmat(OffDec,length(offindex),1);
                PopObj(offindex,:)     = repmat(OffObj,length(offindex),1);
                PopObj_MSE(offindex,:) = repmat(OffObj_MSE,length(offindex),1);
                PopCon(offindex,:)     = repmat(OffCon,length(offindex),1);
                PopCon_MSE(offindex,:) = repmat(OffCon_MSE,length(offindex),1);
            end
        end
        w = w + 1;
    end

    %% Select the unsimilar candidate solutions
    Q    = [];
    temp = Population.decs;
    for i = 1 : N
        if min(pdist2(real(PopDec(i,:)),real(temp))) > 1e-20
            Q    = [Q,i];
            temp = [temp;PopDec(i,:)];
        end
    end
    PopDec     = PopDec(Q,:);
    PopObj     = PopObj(Q,:);
    PopObj_MSE = PopObj_MSE(Q,:);
    PopCon     = PopCon(Q,:);
    PopCon_MSE = PopCon_MSE(Q,:);
    
    %% Kmeans cluster the solutions into Ke clusters and select the solutions with the maximum EI in each cluster
    if size(PopDec,1) == 0
        cindex = [];
    elseif size(PopDec,1) <= Ke
        cindex = kmeans(real(PopDec),size(PopDec,1));
    else
        cindex = kmeans(real(PopDec),Ke);
    end
    Q = [];
    if ~isempty(cindex)
        for i = 1 : min(size(PopDec,1),Ke)
            index       = find(cindex == i);
            tempObj     = PopObj(index,:);
            tempObj_MSE = PopObj_MSE(index,:);
            tempCon     = PopCon(index,:);
            tempCon_MSE = PopCon_MSE(index,:);
            
            K  = length(index);
            EI = zeros(K,1);
            for j = 1 : K
                EI_ = zeros(N,1);
                for k = 1 : N
                    EI_(k) = EICal(real(tempObj(j,:)),abs(tempObj_MSE),real(tempCon),abs(tempCon_MSE),Z,W(k,:),gmin(k),feasible);
                end
                EI(j) = max(EI_(k));
            end
            [~,best] = max(EI);
            Q        = [Q,index(best)];
        end
    end
    PopDec = PopDec(Q,:);
end

function FP = Feasible_Probability(x,PopCon,ConMSE)
    [~,M] = size(PopCon);
    FP    = 1;
    for i = 1 : M
          FP = FP .* normcdf(real((x - PopCon(i))/sqrt(ConMSE(i))));
    end
end

function EI = EICal(Obj,Obj_MSE,Con,Con_MSE,Z,lamda,Gbest,feasible)
% Calculate the expected improvement

    if feasible
        FP     = Feasible_Probability(0,Con,Con_MSE);
        M      = size(Obj,2);
        u      = lamda.*(Obj - Z);
        sigma2 = lamda.^2.*Obj_MSE;
        lamda0 = lamda(1:2);
        mu0    = u(1:2);
        sig20  = sigma2(1:2);
        [y,x]  = GPcal(lamda0,mu0,abs(sig20));
        if M >= 3
            for i = 3 : M
                lamda0 = [1, lamda(i)]; mu0 = [y,u(i)]; sig20 = [x,sigma2(i)];
                [y,x]  = GPcal(lamda0,mu0,abs(sig20));
            end
        end
        EI = ((Gbest-y)*normcdf(real((Gbest-y)/sqrt(x))) + sqrt(x)*normpdf(real((Gbest-y)/sqrt(x)))) * FP;
    else
        n  = 100;
        w  = 1/n : 1/n : 1;
        L  = 0;
        U  = Gbest;
        x  = L + (U - L) * w;
        EI = sum(Feasible_Probability(x,Con,Con_MSE));
        EI = EI * (U - L)/n;
        EI = EI - Gbest * Feasible_Probability(0,Con,Con_MSE);
        if Gbest == 0
            EI = Feasible_Probability(0,Con,Con_MSE);
        end
    end  
end

function [y,x] = GPcal(lamda,mu,sig2)
% Calculate the mu (x) and sigma^2 (y) of the aggregation function

    tao   = sqrt(lamda(1)^2*sig2(1) + lamda(2)^2*sig2(2));
    alpha = (mu(1)-mu(2))/tao;
    y     = mu(1)*normcdf(real(alpha)) + mu(2)*normcdf(real(-alpha)) + tao*normpdf(real(alpha));
    x     = (lamda(1)^2 + sig2(1))*normcdf(real(alpha)) + ...
            (lamda(2)^2 + sig2(2))*normcdf(real(-alpha)) + sum(lamda)*tao*normpdf(real(alpha));
    x     = x - y^2;
end

function [PopObj,PopObj_MSE,PopCon,PopCon_MSE] = Evaluate(Problem,PopDec,model,centers)
% Predict the objective vector of the candidate solutions accodring to the
% Euclidean distance from each candidate solution to evaluated solutions

    D          = pdist2(real(PopDec),real(centers));
    [~,index]  = min(D,[],2);
    N          = size(PopDec,1);
    PopObj     = zeros(N,Problem.M);
    PopObj_MSE = zeros(N,Problem.M);
    Con_len    = size(model,2) - Problem.M;
    for i = 1 : N
        for j = 1 : Problem.M
            [PopObj(i,j),~,PopObj_MSE(i,j)] = predictor(PopDec(i,:),model{index(i),j});
        end
        for j = 1 : Con_len
            [PopCon(i,j),~,PopCon_MSE(i,j)] = predictor(PopDec(i,:),model{index(i),Problem.M + j});
        end
    end
end