classdef CKAnD < ALGORITHM
% <2027> <multi/many> <real> <expensive> <constrained>
% Constrained Kriging-assisted AnD
% wmax --- 20 --- Number of generations before updating Kriging models
% mu   ---  5 --- Number of re-evaluated solutions at each generation

%------------------------------- Reference --------------------------------
% Y. Jiang, B. Liu, Z. Zhang, Y. Wang, and W. Yuan. Surrogate-assisted
% many-objective evolutionary optimization with angle and shift-based
% density estimation. Expert Systems with Applications, 2027, 332: 133513.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao.zhang.cn@gmail.com)

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [wmax,mu] = Algorithm.ParameterSet(20,5);

            %% Generate the reference points and population
            NI        = Problem.N;
            P         = UniformPoint(NI,Problem.D,'Latin');
            A2        = Problem.Evaluation(repmat(Problem.upper-Problem.lower,NI,1).*P+repmat(Problem.lower,NI,1));
            A1        = A2; 
            THETA_obj = 5.*ones(Problem.M,Problem.D);
            THETA_con = 5.*ones(size(A2.cons,2),Problem.D);
            success   = 1;

            %% Optimization
            while Algorithm.NotTerminated(A2)
               % Surrogate Construction
                if success 
                    [Model_obj,Model_con,THETA_obj,THETA_con] = model_train(A2,THETA_obj,THETA_con);
                end
                
                % Evolutionary Search
                [PopDec,PopObj,PopCon] = evolutionary_search(A1,wmax,Model_obj,Model_con,Problem);
                 
                % Candidate Selection
                PopNew = candidate_selection(PopDec,PopObj,PopCon,A2,mu,Problem);
                
                % Population Update
                success = 0;
                if isempty(PopNew) == 0
                    PopNew  = Problem.Evaluation(PopNew);
                    A2      = [A2,PopNew];
                    index   = EnvironmentalSelection(A2.objs,A2.cons,NI);
                    A1      = A2(index);
                    success = 1;
                end
            end
        end
    end
end

function [Model_obj,Model_con,THETA_obj,THETA_con] = model_train(A2,THETA_obj,THETA_con)
    Dec     = A2.decs;
    Obj     = A2.objs;
    Con     = A2.cons;
    Len_dec = size(Dec,2);
    Len_obj = size(Obj,2);
    Len_con = size(Con,2);
    for i = 1 : Len_obj
        [~,distinct1]  = unique(round(Dec*1e10)/1e10,'rows');
        [~,distinct2]  = unique(round(Obj(:,i)*1e10)/1e10,'rows');
        distinct       = intersect(distinct1,distinct2);
        dmodel         = dacefit(Dec(distinct,:),Obj(distinct,i),'regpoly1','corrgauss',THETA_obj(i,:),1e-5.*ones(1,Len_dec),100.*ones(1,Len_dec));
        Model_obj{i}   = dmodel;
        THETA_obj(i,:) = dmodel.theta;
    end
    for i = 1 : Len_con
        [~,distinct1]  = unique(round(Dec*1e10)/1e10,'rows');
        [~,distinct2]  = unique(round(Con(:,i)*1e10)/1e10,'rows');
        distinct       = intersect(distinct1,distinct2);
        dmodel         = dacefit(Dec(distinct,:),Con(distinct,i),'regpoly1','corrgauss',THETA_con(i,:),1e-5.*ones(1,Len_dec),100.*ones(1,Len_dec));
        Model_con{i}   = dmodel;
        THETA_con(i,:) = dmodel.theta;
    end
end