function Dec = Cal_Dec(ModelParemeters,N,D)
% Calculate decision variables based on model parameters

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Wenxiang Wang (email: wwx_cmcc@qq.com)

    L   = size(ModelParemeters,2);
    Dec = zeros(N,D);
    for i = 1 : N
        P = ModelParemeters(i,:);
        for j = 1 : D
            Dec(i,j) = P(end)/2;
            for k = 1 : ((L-2)/2)
                Dec(i,j) = Dec(i,j) + P(2*k+1)*cos(k*P(end-1)*j+P(2*k+2));
            end
        end
    end
end