function Offspring = Cauchy_II3(x,m,b,Problem)
% Generate offspring by Cauchy operator

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    [N,D] = size(x(1).decs);
    trial = zeros(1*length(x),D);
    for i = 1 : length(x)
        l = rand;
        if l <= 1/3
            CR = 0.1;
        elseif l <= 2/3
            CR = 0.2;
        else
            CR = 1.0;
        end
        Decs   = x(i).decs;
        u      = rand();
        y      = m - (b ./ tan(pi .* u));
        y_decs = Decs+y;
        Lower  = repmat(Problem.lower,N,1);
        Upper  = repmat(Problem.upper,N,1);
        indexset    = 1 : length(x);
        indexset(i) = [];
        r1  = floor(rand*(length(x)-1))+1;
        xr1 = indexset(r1);
        indexset(r1) = [];
        r2  = floor(rand*(length(x)-2))+1;
        xr2 = indexset(r2);
        if sum(y_decs<Lower)>0 || sum(y_decs>Upper)>0
            y_decs = x(i).decs+0.5*(x(xr1).decs-x(xr2).decs);
            for j = 1 : D
                if sum(y_decs(j)<Lower(j))>0 || sum(y_decs(j)>Upper(j))>0
                    u = rand();
                    y = m - (b ./ tan(pi .* u));
                    y_decs(j) = Decs(j)+y;
                end
            end
            y_decs = min(max(y_decs,Lower),Upper);
        end
        Site           = rand(N,D)<CR;
        d_rand         = floor(rand*D)+1;
        Site(1,d_rand) = 1;
        Site_          = 1-Site;
        trial(i, :)    = Site.*y_decs+Site_.*Decs;
    end
    Offspring = trial;
    Offspring = Problem.Evaluation(Offspring);
end