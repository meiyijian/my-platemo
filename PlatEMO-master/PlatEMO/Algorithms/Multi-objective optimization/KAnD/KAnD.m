classdef KAnD < ALGORITHM
% <2027> <multi/many> <real> <expensive>
% Kriging-assisted AnD
% wmax --- 20 --- Number of generations before updating Kriging models

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
            wmax = Algorithm.ParameterSet(20);

            %% Generate the reference points and population
            NI      = Problem.N;
            P       = UniformPoint(NI,Problem.D,'Latin');
            A2      = Problem.Evaluation(repmat(Problem.upper-Problem.lower,NI,1).*P+repmat(Problem.lower,NI,1));
            A1      = A2; 
            THETA   = 5.*ones(Problem.M,Problem.D);
            success = 1;

            %% Optimization
            while Algorithm.NotTerminated(A2)
                % Surrogate Construction
                if success 
                    [Kmodel,THETA] = Krigingmodel(A2,THETA);
                end
                
                % Evolutionary Search
                [PopDec,PopObj] = evolutionary_search(A1,wmax,Kmodel,Problem);
                 
                % Candidate Selection
                PopNew = candidate_selection(PopDec,PopObj,A2);
                
                % Population Update
                success = 0;
                if isempty(PopNew) == 0
                    PopNew  = Problem.Evaluation(PopNew);
                    A2      = [A2,PopNew];
                    index   = EnvironmentalSelection(A2.objs,NI);
                    A1      = A2(index);
                    success = 1;
                end
            end
        end
    end
end