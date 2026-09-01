function [Model,THETA] = Krigingmodel(A2,THETA)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao.zhang.cn@gmail.com)

    Dec     = A2.decs;
    Obj     = A2.objs;
    Len_dec = size(Dec,2);
    Len_obj = size(Obj,2);
    for i = 1 : Len_obj
        [~,distinct1] = unique(round(Dec*1e10)/1e10,'rows');
        [~,distinct2] = unique(round(Obj(:,i)*1e10)/1e10,'rows');
        distinct      = intersect(distinct1,distinct2);
        
        dmodel     = dacefit(Dec(distinct,:),Obj(distinct,i),'regpoly0','corrgauss',THETA(i,:),1e-5.*ones(1,Len_dec),100.*ones(1,Len_dec));
        Model{i}   = dmodel;
        THETA(i,:) = dmodel.theta;
    end
end