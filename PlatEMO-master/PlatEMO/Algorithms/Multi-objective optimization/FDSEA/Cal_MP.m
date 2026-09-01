function P0 = Cal_MP(P0,MN,type)
% Calculate model parameters in the frequency domain

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Wenxiang Wang (email: wwx_cmcc@qq.com)

    Dec      = P0.decs;
    D        = size(Dec,2);
    N        = size(Dec,1);
    Dec_adds = zeros(N,2*MN+2);

    T     = D;
    Omiga = 2*pi/T;

    for i = 1 : N
        P = Dec(i,:);
        Dec_adds(i,2*MN+2) = sum(P)/T; % A0
        Dec_adds(i,2*MN+1) = Omiga;    % Omiga
        for k = 1 : 2 : MN/2
            an = sum(P.*(cos(k*Omiga*T)))*2/T;
            bn = sum(P.*(sin(k*Omiga*T)))*2/T;
            Dec_adds(i,k)   = sqrt(an^2+bn^2); % An
            Dec_adds(i,k+1) = -atan(bn/an);  % fair_n 
        end 
    end
    P0.add = Dec_adds;
end