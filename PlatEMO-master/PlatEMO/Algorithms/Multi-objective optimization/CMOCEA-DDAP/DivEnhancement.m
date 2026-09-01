function DA = DivEnhancement(DA, Offspring, zmin, Ns)
%The diversity enhancement method

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiqiang Zeng (email: zhiqiang.zeng@outlook.com)

    S  = [DA, Offspring];
    DA = [];
    
    NonDominated = DominationCal(S, 1);
    S   = S(NonDominated);
    Obj = S.objs;
    Con = S.cons;
    CV  = sum(max(0,Con),2);
    
    [~, M]       = size(Obj);
    [W, Ns]      = UniformPoint(Ns, M);
    Angle_W_to_W = acos(1 - pdist2(W,W,'cosine'));
    Angle_W_to_W(eye(Ns) == 1) = inf;
    zmax         = max(Obj, [], 1);
    Obj          = (Obj - zmin) ./ (zmax - zmin);
    Angle_S_to_W = acos(1 - pdist2(W,Obj,'cosine'));
    
    if length(S) < Ns
        DA = S;
    else
        for i = 1 : Ns
            Angle = Angle_S_to_W(i,:);
            if i == 1
                h = Angle_W_to_W(i,i+1);
            end
            if i == Ns
                h = Angle_W_to_W(i,Ns-1);
            end
            if i~=1 && i~=Ns
                h = min(Angle_W_to_W(i,i-1:i+1));
            end
            list = Angle <= h;
            if sum(list) == 0
                [~,index]   = min(Angle_S_to_W(i,:));
                list(index) = true;
            end
            T        = inf(length(CV), 1);
            T(list)  = CV(list);
            feasible = T <= 0;
            if sum(feasible) <= 0
                [~,index]             = min(T);
                Angle_S_to_W(:,index) = [];
                CV(index)             = [];
            else
                T           = inf(size(Angle));
                Fitness     = Angle_S_to_W(i,:);
                T(feasible) = Fitness(feasible);
                [~,index]   = min(T);
                Angle_S_to_W(:,index) = [];
                CV(index)   = [];
            end    
            DA       = [DA,S(index)];
            S(index) = [];
        end
    end
end