classdef CMOCEADDAP < ALGORITHM
% <2026> <multi> <real/integer> <constrained>
% Constrained multi-objective co-evolutionary algorithm with a dynamic diversity-enhanced auxiliary population

%------------------------------- Reference --------------------------------
% Z. Zeng, Y. Tian, X. Yan, L. Zhang, J. Long, Q. Luo, and C. Chen. A
% constrained multi-objective co-evolutionary algorithm with a dynamic
% diversity-enhanced auxiliary population. Swarm and Evolutionary
% Computation, 2026, 106: 102426.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiqiang Zeng (email: zhiqiang.zeng@outlook.com)

    methods
        function main(Algorithm,Problem)
            %% Generate random population
            Population  = Problem.Initialization();
            Population1 = Problem.Initialization();

            min_p_num   = 4;
            max_p_num   = 50;
            con_num     = max_p_num;
            Population1 = Population1(randperm(Problem.N,con_num));

            rd    = 0.5;
            count = 1;
            len   = 5;

            rd_archive = ones(1,len)*0.5;
            CA         = [];
            zmin       = min(Population1.objs,[],1) - 1e-6;
            zmin       = min(zmin,min(Population.objs,[],1) - 1e-6);

            %% Optimization
            while Algorithm.NotTerminated(Population)
                %Control the auxiliary population size
                con_num = max_p_num-Problem.FE/Problem.maxFE*(max_p_num-min_p_num);
                con_num = con_num-mod(con_num,2);
                Ns      = con_num;
                zmin    = min(zmin, min(Population.objs, [], 1) - 1e-6);
                zmin    = min(zmin, min(Population1.objs, [], 1) - 1e-6);

                %The diversity enhancement method
                CA = DivEnhancement(CA, [Population,Population1], zmin, Ns);

                %Search algorithm for auxiliary population
                Population1 = operator_GA(Population1,Problem,con_num,CA);

                %Search algorithm for main population
                [Population,a_total,b_total,a_scuss,b_scuss] = operator_DE(Problem,Population,Population1,rd);

                %Control method of parameter ps
                a_total = a_total+0.0001;
                b_total = b_total+0.0001;
                if a_scuss~=0 && b_scuss~=0
                    rd_temp = (a_scuss/a_total)/((a_scuss/a_total)+(b_scuss/b_total));
                end
                if a_scuss~=0 && b_scuss==0
                    rd_temp = a_scuss/a_total;
                end
                if a_scuss==0 && b_scuss~=0
                    rd_temp = 0.1;
                end
                if a_scuss==0 && b_scuss==0
                    rd_temp = 0.1;
                end
                rd_archive(count) = rd_temp;
                count = mod(count,len) + 1;
                rd    = mean(rd_archive);
            end
        end
    end
end