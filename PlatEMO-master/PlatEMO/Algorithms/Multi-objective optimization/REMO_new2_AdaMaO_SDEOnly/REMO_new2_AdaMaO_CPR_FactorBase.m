classdef REMO_new2_AdaMaO_CPR_FactorBase < ALGORITHM
% Shared runtime for the continuous-preference 2-by-2 factorial variants.

    methods
        function bits = describeFactorialVariant(Algorithm)
        %describeFactorialVariant Return [scoreSource relationTarget].
            [sourceBit,relationBit] = Algorithm.factorBits();
            bits = [sourceBit,relationBit];
        end

        function main(Algorithm,Problem)
            %% Existing candidate-module constants (not new CPR parameters)
            [k,gmax,q_keep,lambda0,n_min,n_max,use_indicator,debug] = ...
                Algorithm.ParameterSet(6,3000,0.80,0.35,4,6,1,0);

            %% Initialization is locked to the SDEOnly UniformMix baseline
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            InitFE = Problem.FE;
            Archive = Population;

            % The global view is generated once and then remains fixed.
            Vglobal = UniformPoint(N,Problem.M,'ILD');
            directionNorm = vecnorm(Vglobal,2,2);
            Vglobal = Vglobal(directionNorm > 0,:)./directionNorm(directionNorm > 0);

            [sourceBit,relationBit] = Algorithm.factorBits();
            Algorithm.metric.cprBits = [sourceBit,relationBit];
            Algorithm.metric.cprTrace = struct( ...
                'sourceCalls',0,'relationCalls',0,'lastGeneration',0, ...
                'lastPError',NaN,'lastCandidateMode','');

            modeStream = CreateSDECandidateModeStream(Algorithm.run);
            Lp  = 1;
            gen = 0;

            %% Main optimization loop
            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                % Consume the paired UniformMix draw before any early exit.
                u = rand(modeStream,1);
                ratio = min(1,max(0,Problem.FE/Problem.maxFE));
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));

                [qualityScore,Ref] = ComputeSDEFactorialScoreSource( ...
                    Population,sourceBit,Vglobal,ratio,k_eff,5, ...
                    Algorithm.run,gen);
                Algorithm.metric.cprTrace.sourceCalls = ...
                    Algorithm.metric.cprTrace.sourceCalls + 1;

                Input = Population.decs;
                if strcmp(Algorithm.surrogateKind(),'regression')
                    [RelationModel,p_err] = TrainSDEFactorialRegression( ...
                        Input,qualityScore,Algorithm.run,gen);
                else
                    [RelationModel,p_err] = TrainSDEFactorialRelation( ...
                        Input,qualityScore,relationBit,Algorithm.run,gen);
                end
                Algorithm.metric.cprTrace.relationCalls = ...
                    Algorithm.metric.cprTrace.relationCalls + 1;

                %% The locked SDE indicator model is trained every generation
                IndicatorModel = [];
                if use_indicator
                    try
                        [Fitness,Lp] = IndicatorSelectorSDEOnly(Population,Lp);
                    catch
                        Fitness = [];
                    end
                    if ~isempty(Fitness)
                        try
                            IndicatorModel = fitrsvm(Population.decs,Fitness, ...
                                'KernelFunction','rbf', ...
                                'KernelScale','auto', ...
                                'Standardize',true);
                        catch
                            IndicatorModel = [];
                        end
                    end
                end

                [candidate_mode,~,~] = ResolveSDECandidateMode( ...
                    'uniform_mix',~isempty(IndicatorModel),Problem.FE, ...
                    InitFE,Problem.maxFE,u);

                Smodel = struct();
                Smodel.X                 = Input;
                Smodel.RelationModel     = RelationModel;
                Smodel.p_err             = p_err;
                Smodel.lambda0           = lambda0;
                Smodel.ratio             = ratio;
                Smodel.IndicatorModel    = IndicatorModel;
                Smodel.mode              = candidate_mode;
                Smodel.AggregationMode   = Algorithm.preferenceAggregation();

                Next = AdaMaOSelectionFactorial( ...
                    Problem,Ref,Input,gmax,Smodel,q_keep,n_min,n_max);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs], ...
                        {1,15,1,5});
                    Next = Next(1:min(n_min,size(Next,1)),:);
                end

                NewSols = [];
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols]; %#ok<AGROW>
                end

                Algorithm.metric.cprTrace.lastGeneration = gen;
                Algorithm.metric.cprTrace.lastPError = p_err;
                Algorithm.metric.cprTrace.lastCandidateMode = candidate_mode;
                if debug
                    fprintf(['[AdaMaO-CPR F%d%d Gen %3d | FE=%4d/%4d] ', ...
                        'cand=%s p_err=%.3f n=%d\n'],sourceBit,relationBit, ...
                        gen,Problem.FE,Problem.maxFE,candidate_mode,p_err, ...
                        length(NewSols));
                end

                Population = RefSelect(Archive,Problem.N);
            end
        end
    end

    methods (Access = protected)
        function [sourceBit,relationBit] = factorBits(~) %#ok<STOUT>
            error('AdaMaO:MissingFactorialBits', ...
                'A concrete CPR factorial variant is required.');
        end

        function kind = surrogateKind(~)
            kind = 'pairwise';
        end

        function mode = preferenceAggregation(~)
            mode = 'expected';
        end
    end
end
