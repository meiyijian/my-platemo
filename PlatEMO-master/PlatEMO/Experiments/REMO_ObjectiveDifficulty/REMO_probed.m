classdef REMO_probed < ALGORITHM
% <2022> <multi/many> <real> <expensive>
% REMO with per-objective separation gap probe.
% Records diagnostics after PBI classification at every generation.

    methods
        function main(Algorithm, Problem)
            [k, gmax, probe_out_path] = Algorithm.ParameterSet(6, 3000, '');

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end

            PopDec     = UniformPoint(N, Problem.D, 'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower, N, 1) .* PopDec + ...
                repmat(Problem.lower, N, 1));
            Archive    = Population;

            gen      = 0;
            gen_data = {};

            while Algorithm.NotTerminated(Archive)
                gen = gen + 1;

                %% Step 1: Reference selection
                Ref     = RefSelect(Population, k);
                Input   = Population.decs;
                PopObj  = Population.objs;
                Catalog = GetOutput_PBI(PopObj, Ref.objs);

                %% Probe: compute per-objective separation gap
                diag = compute_obj_separation(PopObj, Catalog, gen);
                gen_data{end+1} = diag; %#ok<AGROW>

                %% Incremental save
                if ~isempty(probe_out_path)
                    try
                        save(probe_out_path, 'gen_data', '-v7');
                    catch
                    end
                end

                %% Step 2: Build relation pairs & train
                [XXs, YYs]  = GetRelationPairs(Input, Catalog);
                [TrainIn, TrainOut, TestIn, TestOut] = DataProcess(XXs, YYs);
                xDim = size(TrainIn, 2);

                [TrainIn_nor, TrainIn_struct] = mapminmax(TrainIn');
                TrainIn_nor     = TrainIn_nor';
                TrainOut_onehot = onehotconv(TrainOut, 1);

                net = patternnet([ceil(xDim*1.5), xDim, ceil(xDim/2)]);
                net.trainParam.showWindow = 0;
                net        = train(net, TrainIn_nor', TrainOut_onehot');
                TestIn_nor = mapminmax('apply', TestIn', TrainIn_struct)';
                TestPre    = onehotconv(net(TestIn_nor')', 2);
                p_err      = sum(TestPre ~= TestOut) / size(TestPre, 1);

                Smodel.X         = Input;
                Smodel.Y         = Catalog;
                Smodel.mp_struct = TrainIn_struct;
                Smodel.net       = net;
                Smodel.p_err     = p_err;

                %% Step 3: Surrogate-assisted selection
                Next = RSurrogateAssistedSelection(Problem, Ref, Population.decs, gmax, Smodel);
                if ~isempty(Next)
                    Archive = [Archive, Problem.Evaluation(Next)]; %#ok<AGROW>
                end

                %% Step 4: Environmental selection
                Population = RefSelect(Archive, Problem.N);
            end
        end
    end
end
