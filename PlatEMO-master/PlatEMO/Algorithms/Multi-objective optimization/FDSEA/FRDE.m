function Offspring = FRDE(Problem,Parent1,Parent2,Parent3,Parameter)
% FRDE - The operator of differential evolution for FREA.

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Wenxiang Wang (email: wwx_cmcc@qq.com)

    %% Parameter setting
    if nargin > 4
        [CR,F,proM,disM] = deal(Parameter{:});
    else
        [CR,F,proM,disM] = deal(1,0.5,1,20);
    end
    if isa(Parent1(1),'SOLUTION')
        Parent1 = Parent1.adds;
        Parent2 = Parent2.adds;
        Parent3 = Parent3.adds;
    end
    [N,D] = size(Parent1);

    %% Differental evolution
    Site = rand(N,D) < CR;
    Offspring       = Parent1;
    Offspring(Site) = Offspring(Site) + F*(Parent2(Site)-Parent3(Site));

    %% Polynomial mutation
    Lower = zeros(N, D);
    Upper = ones(N, D);
    Site  = rand(N,D) < proM/D;
    mu    = rand(N,D);
    temp  = Site & mu<=0.5;
    Offspring       = min(max(Offspring,Lower),Upper);
    Offspring(temp) = Offspring(temp)+(Upper(temp)-Lower(temp)).*((2.*mu(temp)+(1-2.*mu(temp)).*...
                      (1-(Offspring(temp)-Lower(temp))./(Upper(temp)-Lower(temp))).^(disM+1)).^(1/(disM+1))-1);
    temp = Site & mu>0.5; 
    Offspring(temp) = Offspring(temp)+(Upper(temp)-Lower(temp)).*(1-(2.*(1-mu(temp))+2.*(mu(temp)-0.5).*...
                      (1-(Upper(temp)-Offspring(temp))./(Upper(temp)-Lower(temp))).^(disM+1)).^(1/(disM+1)));
end