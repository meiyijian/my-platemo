function [PopDec,PopObj] = evolutionary_search(A1,wmax,Kmodel,Problem)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao.zhang.cn@gmail.com)

    PopDec = A1.decs;
    PopObj = A1.objs;
    w      = 1;
    while w <= wmax
        OffDec     = OperatorGA(Problem,PopDec);
        [OffObj,~] = model_predict(OffDec,Kmodel);
        
        PopDec = [PopDec;OffDec];
        PopObj = [PopObj;OffObj];

        index  = EnvironmentalSelection(PopObj,length(A1));
      
        PopDec = PopDec(index,:);
        PopObj = PopObj(index,:);
        w      = w + 1;
    end
    [FrontNo,~] = NDSort(PopObj,1);
    PopDec      = PopDec(FrontNo==1,:);
    PopObj      = PopObj(FrontNo==1,:);
end

function [KOffObj,KMSE] = model_predict(OffDec,Kmodel)
    M = length(Kmodel); 
    N = size(OffDec,1);

    % Kriging model
    KOffObj = zeros(N,M);
    KMSE    = zeros(N,M);
    for i = 1 : N
        for j = 1 : M
            [KOffObj(i,j),~,KMSE(i,j)] = predictor(OffDec(i,:),Kmodel{j});
        end
    end
end