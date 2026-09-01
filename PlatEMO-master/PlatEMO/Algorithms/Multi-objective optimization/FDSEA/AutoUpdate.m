function gama = AutoUpdate(gama,Population)
% Auto update the mixing operator parameter

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Wenxiang Wang (email: wwx_cmcc@qq.com)

    N    = size(Population,2);
    N1   = round(gama*N);
    N2   = N - N1;
    Add  = Population.adds;
    k1   = sum(Add(:)==1);
    k2   = sum(Add(:)==-1);
    eta1 = (k1-k2)/N;
    eta2 = k1/N1-k2/N2;
    gama = gama + f1(gama)*eta1 + f2(gama)*f3(gama,eta2);
 
    if gama > 0.9
        gama = 0.9;
    elseif gama < 0.1
        gama = 0.1;
    end
end

function y = sigmoid(x)
    y = 1./(1+exp(-x));
end

function y = f1(x)
    y = (x - 0.5)^2 + 1;
end

function y = f2(x)
    y = 2*sigmoid((x-0.5)*8)-1;
end

function y = f3(gama,eta)
    y = sign(gama-0.5)*(-exp(-sign(gama-0.5)*eta) + 1);
end