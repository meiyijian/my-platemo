classdef DAREMO_GPT < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Difficulty-aware relation-model expensive multi-objective optimization (DAREMO).
% This algorithm wraps the self-contained DAREMO_Infill selector into a PlatEMO ALGORITHM class.
% Main idea:
%   1) estimate per-objective online difficulty (progress / relation-error / conflict / sensitivity);
%   2) sort objectives from easy to hard and build prefix sub-objective relation models plus a full model;
%   3) fuse relation predictions with reliability, uncertainty, novelty and conflict penalty;
%   4) select diverse candidates greedily for real expensive evaluation.
%
% batchSize  ---    5 --- Number of candidates proposed and truly evaluated per iteration
% maxPairs   --- 5000 --- Maximum number of training pairs per relation model
% nCandidate --- 1000 --- Number of candidates generated for surrogate screening
% RFTrees    ---  160 --- Number of trees in the random-forest relation model
% useTree    ---    1 --- Use TreeBagger if available (1) or force the kNN fallback (0)
%
%------------------------------- Reference --------------------------------
% Difficulty-aware relation learning surrogate prototype generated for
% expensive multi/many-objective optimization research. Implementation in
% DAREMO_Infill.m is self-contained and intended for prototyping.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [batchSize,maxPairs,nCandidate,RFTrees,useTree] = Algorithm.ParameterSet(5,5000,1000,160,1);

            %% Initialize population by Latin hypercube sampling
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec + repmat(Problem.lower,N,1));
            Archive    = Population;

            % Track per-solution generation index for progress-based difficulty
            generations = ones(N,1);
            gen         = 1;

            % Build configuration struct forwarded to DAREMO_Infill
            cfg               = struct();
            cfg.MaxPairs      = maxPairs;
            cfg.NCandidates   = nCandidate;
            cfg.RFTrees       = RFTrees;
            cfg.UseTreeBagger = logical(useTree);

            %% Optimization
            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                % Respect the remaining real-evaluation budget
                remain = Problem.maxFE - Problem.FE;
                if remain <= 0
                    break;
                end
                bs = min(batchSize,remain);

                % Call the difficulty-aware infill selector
                try
                    DecNext = DAREMO_Infill(Archive.decs,Archive.objs,Problem.lower,Problem.upper,bs,cfg,generations);
                catch ME
                    warning('DAREMO_GPT:InfillFailed','DAREMO_Infill failed (%s), falling back to random sampling.',ME.message);
                    DecNext = repmat(Problem.lower,bs,1) + rand(bs,Problem.D).*repmat(Problem.upper-Problem.lower,bs,1);
                end

                if isempty(DecNext)
                    continue;
                end

                % Boundary clamp and deduplicate against the archive
                DecNext = min(max(DecNext,repmat(Problem.lower,size(DecNext,1),1)),repmat(Problem.upper,size(DecNext,1),1));
                DecNext = unique(DecNext,'rows','stable');
                if ~isempty(Archive)
                    old     = ismember(DecNext,Archive.decs,'rows');
                    DecNext = DecNext(~old,:);
                end
                if isempty(DecNext)
                    DecNext = repmat(Problem.lower,1,1) + rand(1,Problem.D).*(Problem.upper-Problem.lower);
                end
                if size(DecNext,1) > remain
                    DecNext = DecNext(1:remain,:);
                end

                % Expensive real evaluation
                NewPop      = Problem.Evaluation(DecNext);
                Archive     = [Archive,NewPop]; %#ok<AGROW>
                generations = [generations; gen*ones(size(DecNext,1),1)]; %#ok<AGROW>
            end
        end
    end
end
