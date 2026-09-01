classdef TSPP < ALGORITHM
% <2026> <multi/many> <real> <expensive> <constrained>
% Two-stage probabilistic penalty
% wmax --- 20 --- Generations of evolutionary search
% mu   ---  5 --- Number of selected candidates

%------------------------------- Reference --------------------------------
% Z. Zhang, Y. Wang, G. Sun, and J. Luo. Two-stage probabilistic penalty 
% for expensive constrained multiobjective optimization problems. 
% IEEE Transactions on Evolutionary Computation, 2026.
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
            global phase v K 
            [wmax,mu] = Algorithm.ParameterSet(20,5);
            v         = 0;
            K         = 0;

            %% Initialization
            NI             = Problem.N;
            P              = UniformPoint(NI,Problem.D,'Latin');
            A2             = Problem.Evaluation(repmat(Problem.upper-Problem.lower,NI,1).*P+repmat(Problem.lower,NI,1));
            THETA_obj      = 5.*ones(Problem.M,Problem.D);
            THETA_con      = 5.*ones(size(A2.cons,2),Problem.D);
            sample_success = 1;
            phase          = 1;
            Mean_CV_old    = inf;
            Phase1_flag    = 0; 

            %% Optimization
            while Algorithm.NotTerminated(A2)
                % Surrogate Construction
                if sample_success
                    [Model_obj,Model_con,THETA_obj,THETA_con] = Surrogate_Construction(A2,THETA_obj,THETA_con);
                end

                % Evolutionary Search
                [PopDec,PopObj,PopCon,ObjMSE,ConMSE] = Evolutionary_Search(A2,wmax,Model_obj,Model_con,Problem);
                 
                % Candidate Selection
                PopNew = Candidate_Selection(PopDec,PopObj,PopCon,ObjMSE,ConMSE,A2,mu,Problem);
                sample_success = 0;
                if isempty(PopNew) == 0
                    A2             = [A2,PopNew];
                    sample_success = 1;
                end
               
                % Judgement for TSP
                if sample_success
                    if phase == 1
                        if Problem.FE >=  NI + (Problem.maxFE - NI)/2
                            phase = 2;
                        elseif Problem.FE >=  NI + (Problem.maxFE - NI)/4
                            Mean_CV_new = sum(sum(max(0,PopNew.cons),2))/length(PopNew);
                            if Mean_CV_new > Mean_CV_old && isempty(find(all(PopNew.cons<=0,2), 1))
                                if Phase1_flag == 0
                                    Phase1_flag = 1;
                                elseif Phase1_flag == 1
                                    phase = 2;
                                end
                            else
                                Phase1_flag = 0;
                            end
                            Mean_CV_old = Mean_CV_new;
                        end
                    elseif phase == 2
                        if Problem.FE >=  NI + (Problem.maxFE - NI)*3/4 && length(find(all(A2.cons<=0,2))) >= NI
                            phase = 3;
                        end
                    end
                    if phase == 3
                        PopDec = A2(all(A2.cons<=0,2)).decs;
                        v      = mean(PopDec,1);
                        K      = (PopDec-v)'*(PopDec-v)/(size(PopDec,1)-1);
                    end
                end
            end
        end
    end
end