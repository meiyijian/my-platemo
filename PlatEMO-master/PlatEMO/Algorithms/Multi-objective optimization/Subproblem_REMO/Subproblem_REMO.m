classdef Subproblem_REMO < ALGORITHM
% <2024> <multi/many> <real> <expensive>
% Multi-objective optimization with multiple subproblem classifiers (MLP)
% Framework identical to REMO, but using multiple subproblem classifiers
% instead of a single global relation model.
    methods
        function main(Algorithm, Problem)
            %% Parameter setting
            [k, gmax] = Algorithm.ParameterSet(6, 3000);
            
            %% Initialize population
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower, N, 1) .* PopDec + repmat(Problem.lower, N, 1));
            Archive = Population;
            
            %% Define subproblems (weight vectors)
            % Here we use each original objective as a subproblem.
            % Additional weighted sums can be added.
            sub_weights = {};
            for i = 1:Problem.M
                w = zeros(1, Problem.M);
                w(i) = 1;
                sub_weights{end+1} = w;
            end
            % Optional: add pairwise equal weights for neighboring objectives
            for i = 1:Problem.M-1
                w = zeros(1, Problem.M);
                w(i) = 0.5;
                w(i+1) = 0.5;
                sub_weights{end+1} = w;
            end
            
            %% Optimization
            while Algorithm.NotTerminated(Archive)
                % Select reference solutions (same as REMO)
                Ref = RefSelect(Population, k);
                
                % Train subproblem classifiers using current population
                classifiers = TrainSubproblemClassifiers(Population, sub_weights);
                
                % Use surrogate-assisted selection (modified to use multi-model voting)
                Next = SubproblemSurrogateSelection(Problem, Ref, Population.decs, gmax, classifiers, sub_weights);
                
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)];
                end
                
                % Environmental selection (same as REMO)
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end