function [FrontNo,MaxFNo] = NDSort_TSPP(PopDec,PopObj,ObjMSE,PopCon,ConMSE,nSort)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao.zhang.cn@gmail.com)

    global phase v K 

    [N,M] = size(PopObj);
    [~,D] = size(PopDec); 
    LFP   = Feasible_Probability(PopCon,ConMSE);
    sigma = sqrt(ObjMSE(reshape(ones(N,1)*(1:N),N*N,1),:) + repmat(ObjMSE,N,1));
    mean  = PopObj(reshape(ones(N,1)*(1:N),N*N,1),:) - repmat(PopObj,N,1);
    x_PD  = normcdf((0-mean)./sigma);
    y_PD  = 1 - x_PD;

    if phase == 1
        diff = sum(abs(x_PD-y_PD),2)/M;
        w    = diff/2;
        x_PD = - (w.*x_PD + (1-w).*LFP(reshape(ones(N,1)*(1:N),N*N,1),:));
        y_PD = - (w.*y_PD + (1-w).*repmat(LFP,N,1));
    elseif phase == 2 || phase == 3
        Ns   = size(x_PD,1);
        LFP1 = LFP(reshape(ones(N,1)*(1:N),N*N,1),:);
        LFP2 = repmat(LFP,N,1);
        for i = 1 : Ns
            if LFP1(i) < 0.5
                x_PD(i,:) = 0;
                x_PD(i,:) = (x_PD(i,:) + LFP1(i));
            else
                x_PD(i,:) = (x_PD(i,:) + 1);
            end

            if LFP2(i) < 0.5
                y_PD(i,:) = 0;
                y_PD(i,:) = (y_PD(i,:) + LFP2(i));
            else
                y_PD(i,:) = (y_PD(i,:) + 1);
            end
        end

        if phase == 3
            Pro   = zeros(N,1);
            gamma = 1/(det(K)^(1/2)*(2*pi)^(D/2));
            for j = 1 : N
                Pro(j,:) = gamma*exp(-0.5*(PopDec(j,:) - v)*(K^-1)*(PopDec(j,:) - v)');
            end
            x_PD = x_PD.*Pro(reshape(ones(N,1)*(1:N),N*N,1),:);
            y_PD = y_PD.*repmat(Pro,N,1);
        end
        x_PD = -x_PD;
        y_PD = -y_PD;
    end
        
    dominate = false(N);
    for i = 1 : N-1
        for j = i+1 : N
            if all(x_PD(N*(i-1)+j,:) <= y_PD(N*(i-1)+j,:)) && ~all(x_PD(N*(i-1)+j,:) == y_PD(N*(i-1)+j,:))
                dominate(i,j) = true;
            elseif all(x_PD(N*(i-1)+j,:) >= y_PD(N*(i-1)+j,:)) && ~all(x_PD(N*(i-1)+j,:) == y_PD(N*(i-1)+j,:))
                dominate(j,i) = true;
            end
        end
    end

    FrontNo = inf(1,N);
    MaxFNo  = 0;
    while sum(FrontNo~=inf) < min(nSort,N)
        MaxFNo                     = MaxFNo + 1;
        current                    = find(FrontNo==inf);
        dominate_                  = sum(dominate(current,current),1);
        index                      = find(dominate_==min(dominate_));
        FrontNo(current(index))    = MaxFNo;
        dominate(current(index),:) = false;
    end
end

function LFP = Feasible_Probability(PopCon,ConMSE)
    [N,M] = size(PopCon);
    LFP   = ones(N,1);
    for i = 1 : N
        for j = 1 : M
             LFP(i) = min([LFP(i),normcdf((0-(PopCon(i,j)+0*sqrt(ConMSE(i,j))))/sqrt(ConMSE(i,j)))]);
        end
    end
end