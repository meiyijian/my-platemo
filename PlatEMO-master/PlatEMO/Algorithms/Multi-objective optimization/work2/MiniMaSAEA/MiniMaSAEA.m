classdef MiniMaSAEA < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Minimal surrogate-assisted algorithm for comparing objective handlers
% Mode --- 'PBI' --- PBI, TCH, SDE, or OBJ (one GP per objective)

    methods
        function main(Algorithm,Problem)
            mode = Algorithm.ParameterSet('PBI');
            if ~(ischar(mode) || (isstring(mode) && isscalar(mode)))
                error('MiniMaSAEA:InvalidMode','Mode must be PBI, TCH, SDE, or OBJ.');
            end
            mode = upper(char(mode));
            if ~ismember(mode,{'PBI','TCH','SDE','OBJ'})
                error('MiniMaSAEA:InvalidMode','Mode must be PBI, TCH, SDE, or OBJ.');
            end
            if any(Problem.encoding ~= 1) || any(~isfinite(Problem.lower)) || ...
                    any(~isfinite(Problem.upper)) || any(Problem.upper <= Problem.lower)
                error('MiniMaSAEA:Domain','This first version requires finite, non-degenerate real variables.');
            end

            % Use a local stream so every mode draws the same reference-vector
            % sequence when runs start from the same MATLAB RNG state.
            W = UniformPoint(Problem.N,Problem.M);
            weightStream = RandStream('mt19937ar','Seed',randi(2^31-1));

            % ParEGO's 11*D-1 samples can exceed an expensive FE budget.
            % Keep at least half the budget for sequential infill.
            NI = min([11*Problem.D-1,Problem.N,floor(Problem.maxFE/2)]);
            if NI < Problem.D+2
                error('MiniMaSAEA:Budget', ...
                    'Need at least D+2 initial samples and as many remaining FEs for linear-trend GP fitting.');
            end
            U = UniformPoint(NI,Problem.D,'Latin');
            X = Problem.lower + (Problem.upper-Problem.lower).*U;
            Archive = Problem.Evaluation(X);

            while Algorithm.NotTerminated(Archive)
                % These operators and the one-point infill rule are shared.
                C = OperatorGA(Problem,Archive.decs);
                C = Problem.CalDec(C);
                C = unique(C,'rows','stable');
                C(ismember(C,Archive.decs,'rows'),:) = [];
                if isempty(C)
                    U = UniformPoint(max(2,Problem.N),Problem.D,'Latin');
                    C = Problem.CalDec(Problem.lower + (Problem.upper-Problem.lower).*U);
                    C(ismember(C,Archive.decs,'rows'),:) = [];
                end
                if isempty(C)
                    error('MiniMaSAEA:NoCandidate','No unevaluated candidate could be generated.');
                end

                w = W(randi(weightStream,size(W,1)),:);
                Obj = Archive.objs;
                zmin = min(Obj,[],1);
                span = max(Obj,[],1)-zmin;
                span(span < 1e-12) = 1;
                F = (Obj-zmin)./span;

                if strcmp(mode,'OBJ')
                    % One independent GP for each normalized objective.
                    PredObj = zeros(size(C,1),Problem.M);
                    for j = 1:Problem.M
                        model = MiniDaceFit(Archive.decs,F(:,j), ...
                            'regpoly1','corrgauss',10*ones(1,Problem.D), ...
                            1e-5*ones(1,Problem.D),20*ones(1,Problem.D));
                        PredObj(:,j) = MiniDacePredictor(C,model);
                    end
                    Pred = MiniMaSAEAHandler(PredObj,w,'PBI');
                else
                    Y = MiniMaSAEAHandler(F,w,mode);
                    model = MiniDaceFit(Archive.decs,Y, ...
                        'regpoly1','corrgauss',10*ones(1,Problem.D), ...
                        1e-5*ones(1,Problem.D),20*ones(1,Problem.D));
                    Pred = MiniDacePredictor(C,model);
                end

                [~,best] = min(Pred);
                New = Problem.Evaluation(C(best,:));
                Archive = [Archive,New];
            end
        end
    end
end
