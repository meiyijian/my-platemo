function Solver = SparseEMTSolverMGCEA(Shared)
%SparseEMTSolverMGCEA - Adapter for embedding MGCEA in SparseEMT.

    Solver.Name                   = 'MGCEA';
    Solver.NewState               = @NewState;
    Solver.Initialize             = @Initialize;
    Solver.UpdateState            = @UpdateState;
    Solver.MatingSelection        = @MatingSelection;
    Solver.Operator               = @SolverOperator;
    Solver.TaskOperator           = Shared.TaskOperator;
    Solver.EnvironmentalSelection = @SolverEnvironmentalSelection;
    Solver.Ranking                = @Ranking;
    Solver.SelectTop              = @SelectTop;
    Solver.RandomSparseDecision   = Shared.RandomSparseDecision;

    function State = NewState(Problem,Framework)
        [State.sparseRate,State.fitness] = ClusterByScore(Framework.VarScore);
        State.pv = State.fitness;
        State.nearStage = ceil(Problem.FE/(Problem.maxFE/10));
        State.nearStage = min(10,max(1,State.nearStage));
        [State.fitnessLayer,State.layerMax] = UpdateLayer(State.sparseRate,State.nearStage,State.fitness,Problem,[]);
        State = RepairLayer(Problem,State);
        State.mainRefineGen = 1;
    end

    function [Population,Dec,Mask,Skill,State] = Initialize(Problem,Framework,State)
        Population = Framework.SamplePop;
        Dec        = Framework.SampleDec;
        Mask       = Framework.SampleMask;
        Skill      = ones(length(Population),1);
        [Population,Dec,Mask,Skill,State] = SolverEnvironmentalSelection(Problem,Population,Dec,Mask,Skill,Problem.N,State);
        if length(Population) < Problem.N
            miss = Problem.N - length(Population);
            [RandDec,RandMask] = Shared.RandomSparseDecision(Problem,miss,State);
            RandPop = Problem.Evaluation(RandDec.*RandMask,Shared.SparseAdd(RandDec,RandMask,ones(miss,1)));
            Population = [Population,RandPop];
            Dec        = [Dec;RandDec];
            Mask       = [Mask;RandMask];
            Skill      = [Skill;ones(miss,1)];
            [Population,Dec,Mask,Skill,State] = SolverEnvironmentalSelection(Problem,Population,Dec,Mask,Skill,Problem.N,State);
        end
    end

    function [State,Rank,CrowdDis] = UpdateState(Problem,~,Dec,Mask,~,Rank,CrowdDis,State)
        [State.nearStage,State.fitness,State.fitnessLayer,State.layerMax] = ...
            ControlStage(State.sparseRate,State.nearStage,Mask,Dec,State.fitness,State.fitnessLayer,State.layerMax,Problem);
        State = RepairLayer(Problem,State);
    end

    function MatingPool = MatingSelection(N,Fitness,~,~)
        MatingPool = TournamentSelection(2,2*N,Fitness);
    end

    function [OffDec,OffMask] = SolverOperator(Problem,ParentDec,ParentMask,State)
    % MGCEA embedded operator in the original search space.

        State = RepairLayer(Problem,State);
        [OffDec,OffMask] = Operator(Problem,ParentDec,ParentMask,State.fitnessLayer,State.layerMax);
    end

    function [Population,Dec,Mask,Skill,State] = SolverEnvironmentalSelection(Problem,Population,Dec,Mask,Skill,N,State)
    % Delegate survivor choice to MGCEA, then recover SparseEMT skill factors.

        Population            = Shared.AttachSparseAdd(Population,Dec,Mask,Skill);
        [Population,Dec,Mask] = EnvironmentalSelection(Population,Dec,Mask,N);
        [Dec,Mask,Skill]      = Shared.SparseStateFromAdd(Population,Problem.D,Dec,Mask);
        Population            = Shared.AttachSparseAdd(Population,Dec,Mask,Skill);
    end

    function [Fitness,CrowdDis] = Ranking(~,Population,~,~,~,~)
        if isempty(Population)
            Fitness  = [];
            CrowdDis = [];
        else
            Fitness  = CalFitness(Population.objs);
            CrowdDis = zeros(size(Fitness));
        end
    end

    function index = SelectTop(Population,N,~)
        N = min(N,length(Population));
        if N <= 0
            index = [];
        else
            Fitness  = CalFitness(Population.objs);
            [~,rank] = sort(Fitness);
            index    = rank(1:N);
        end
    end

    function [SparseRate,Fitness] = ClusterByScore(Score)
        Score = Score(:);
        D = length(Score);
        if D < 2 || all(abs(Score-Score(1)) < eps)
            Fitness = 11*ones(1,D);
            SparseRate = 1;
            return;
        end
        Fitness   = kmeans(Score,2,'Replicates',3,'MaxIter',100);
        Num1      = sum(Fitness == 1);
        Num2      = sum(Fitness == 2);
        Num1Value = sum(Score(Fitness == 1));
        Num2Value = sum(Score(Fitness == 2));
        if Num1Value < Num2Value
            SparseRate = Num1/(Num1 + Num2);
            Fitness(Fitness == 1) = 11;
            Fitness(Fitness == 2) = 12;
        else
            SparseRate = Num2/(Num1 + Num2);
            Fitness(Fitness == 1) = 12;
            Fitness(Fitness == 2) = 11;
        end
        SparseRate = min(1,max(1/D,SparseRate));
        Fitness    = Fitness';
    end

    function State = RepairLayer(Problem,State)
    % Guard MGCEA's layer schedule when FE slightly exceeds maxFE in PlatEMO.

        badLayer = isempty(State.fitnessLayer) || ~isfinite(State.layerMax) || State.layerMax < 1 || any(~isfinite(State.fitnessLayer));
        if badLayer
            State.nearStage = min(10,max(1,State.nearStage));
            [State.fitnessLayer,State.layerMax] = UpdateLayer(State.sparseRate,State.nearStage,State.fitness,Problem,[]);
        end
        if isempty(State.fitnessLayer) || ~isfinite(State.layerMax) || State.layerMax < 1 || any(~isfinite(State.fitnessLayer))
            State.fitnessLayer = ones(1,Problem.D);
            State.layerMax = 1;
        end
    end
end