function Solver = SparseEMTSolverMSKEA(Shared)
%SparseEMTSolverMSKEA - Adapter for embedding MSKEA in SparseEMT.

    Solver.Name                   = 'MSKEA';
    Solver.NewState               = @NewState;
    Solver.Initialize             = @Initialize;
    Solver.UpdateState            = @UpdateState;
    Solver.MatingSelection        = @MatingSelection;
    Solver.Operator               = @SolverOperator;
    Solver.TaskOperator           = Shared.TaskOperator;
    Solver.EnvironmentalSelection = @EnvironmentalSelection;
    Solver.Ranking                = Shared.Ranking;
    Solver.SelectTop              = Shared.SelectTop;
    Solver.RandomSparseDecision   = Shared.RandomSparseDecision;

    function State = NewState(Problem,Framework)
        State.pv            = Framework.VarScore;
        State.fv            = zeros(1,Problem.D);
        State.sv            = zeros(1,Problem.D);
        State.lastFrontNo   = 0;
        State.delta         = 0;
        State.mainRefineGen = 1;
    end

    function [Population,Dec,Mask,Skill,State] = Initialize(Problem,Framework,State)
        [Dec,Mask] = Shared.RandomSparseDecision(Problem,Problem.N,State);
        Population = [Problem.Evaluation(Dec.*Mask,Shared.SparseAdd(Dec,Mask,ones(Problem.N,1))),Framework.SamplePop];
        Dec        = [Dec;Framework.SampleDec];
        Mask       = [Mask;Framework.SampleMask];
        Skill      = ones(length(Population),1);
        [Population,Dec,Mask,Skill,State] = EnvironmentalSelection(Problem,Population,Dec,Mask,Skill,Problem.N,State);
        if length(Population) < Problem.N
            [Population,Dec,Mask,Skill,State] = FillPopulation(Problem,Population,Dec,Mask,Skill,Problem.N,State);
        end
    end

    function [State,FrontNo,CrowdDis] = UpdateState(Problem,Population,~,Mask,~,FrontNo,CrowdDis,State)
        State.delta = Problem.FE/Problem.maxFE;
        if any(FrontNo==1)
            FDec     = Population(FrontNo==1).decs;
            State.fv = std(FDec,0,1);
            if any(Problem.encoding==4)
                State.fv(:,Problem.encoding==4) = sum(Mask(FrontNo==1,Problem.encoding==4),1);
            end
            firstMask = Mask(FrontNo==1,:);
        else
            State.fv  = zeros(1,Problem.D);
            firstMask = Mask;
        end
        frontSize = size(firstMask,1);
        if frontSize > 0
            vote     = sum(firstMask,1);
            State.sv = (State.lastFrontNo/(State.lastFrontNo+frontSize))*State.sv + (frontSize/(State.lastFrontNo+frontSize))*(vote/frontSize);
            State.lastFrontNo = frontSize;
        end
        if State.delta < 0.618
            State.pv = State.pv.*(1-State.sv)*sqrt(State.delta) + State.pv;
        end
    end

    function MatingPool = MatingSelection(N,FrontNo,CrowdDis,~)
        MatingPool = TournamentSelection(2,2*N,FrontNo,-CrowdDis);
    end

    function [OffDec,OffMask] = SolverOperator(Problem,ParentDec,ParentMask,State)
    % MSKEA embedded operator.

        if (State.delta/0.618) < 0.618
            [OffDec,OffMask] = Operator_pvfv(Problem,ParentDec,ParentMask,State.pv,State.fv,State.delta);
        elseif State.delta < 0.618
            if rand < 0.5
                [OffDec,OffMask] = Operator_sv(Problem,ParentDec,ParentMask,State.sv);
            else
                [OffDec,OffMask] = Operator_pvfv(Problem,ParentDec,ParentMask,State.pv,State.fv,State.delta);
            end
        else
            [OffDec,OffMask] = Operator_sv(Problem,ParentDec,ParentMask,State.sv);
        end
        OffDec = RepairActiveDecByMask(Problem,ParentDec,ParentMask,OffDec,OffMask);
    end

    function [Population,Dec,Mask,Skill,State] = EnvironmentalSelection(~,Population,Dec,Mask,Skill,N,State)
    % MSKEA/SPEA2-style environmental selection without task quotas.

        uni        = Shared.SparseUnique(Population,Mask);
        Population = Population(uni);
        Dec        = Dec(uni,:);
        Mask       = Mask(uni,:);
        Skill      = Skill(uni,:);
        N          = min(N,length(Population));
        [FrontNo,MaxFNo] = NDSort(Population.objs,Population.cons,N);
        Next = FrontNo < MaxFNo;

        PopObj = Population.objs;
        if any(FrontNo==1)
            fmax = max(PopObj(FrontNo==1,:),[],1);
            fmin = min(PopObj(FrontNo==1,:),[],1);
        else
            fmax = max(PopObj,[],1);
            fmin = min(PopObj,[],1);
        end
        denom = fmax - fmin;
        denom(denom==0) = 1;
        PopObj = (PopObj-repmat(fmin,size(PopObj,1),1))./repmat(denom,size(PopObj,1),1);

        Last = find(FrontNo==MaxFNo);
        K    = length(Last) - N + sum(Next);
        if K > 0
            del = Truncation(PopObj(Last,:),K);
            Next(Last(~del)) = true;
        else
            Next(Last) = true;
        end
        Population = Population(Next);
        Dec        = Dec(Next,:);
        Mask       = Mask(Next,:);
        Skill      = Skill(Next,:);
        Population = Shared.AttachSparseAdd(Population,Dec,Mask,Skill);
    end

    function [Population,Dec,Mask,Skill,State] = FillPopulation(Problem,Population,Dec,Mask,Skill,N,State)
        miss = N - length(Population);
        if miss > 0
            [RandDec,RandMask] = Shared.RandomSparseDecision(Problem,miss,State);
            RandPop = Problem.Evaluation(RandDec.*RandMask,Shared.SparseAdd(RandDec,RandMask,ones(miss,1)));
            Population = [Population,RandPop];
            Dec        = [Dec;RandDec];
            Mask       = [Mask;RandMask];
            Skill      = [Skill;ones(miss,1)];
            [Population,Dec,Mask,Skill,State] = EnvironmentalSelection(Problem,Population,Dec,Mask,Skill,N,State);
        end
    end

    function OffDec = RepairActiveDecByMask(Problem,ParentDec,ParentMask,OffDec,OffMask)
    % Preserve SparseEMT latent values for dimensions activated by MSKEA masks.

        active = OffMask & Problem.encoding~=4;
        if any(active)
            OffDec(active) = GArealSubsetMasked(ParentDec(1,active),ParentDec(2,active),ParentMask(1,active),ParentMask(2,active), ...
                             Problem.lower(active),Problem.upper(active),Problem.encoding(active));
        end
    end

    function Offspring = GArealSubsetMasked(Parent1,Parent2,Mask1,Mask2,lower,upper,encoding)
    % SBX/PM in a task subspace while ignoring inactive latent values.

        D          = size(Parent1,2);
        Offspring  = zeros(1,D);
        bothActive = Mask1 & Mask2;
        onlyFirst  = Mask1 & ~Mask2;
        onlySecond = ~Mask1 & Mask2;
        bothSilent = ~Mask1 & ~Mask2;

        if any(bothActive)
            Offspring(bothActive) = Shared.GArealSubset(Parent1(bothActive),Parent2(bothActive),lower(bothActive),upper(bothActive),1,20,1,20,encoding(bothActive));
        end
        if any(onlyFirst)
            Offspring(onlyFirst) = Shared.GArealSubset(Parent1(onlyFirst),Parent1(onlyFirst),lower(onlyFirst),upper(onlyFirst),1,20,1,20,encoding(onlyFirst));
        end
        if any(onlySecond)
            Offspring(onlySecond) = Shared.GArealSubset(Parent2(onlySecond),Parent2(onlySecond),lower(onlySecond),upper(onlySecond),1,20,1,20,encoding(onlySecond));
        end
        if any(bothSilent)
            Offspring(bothSilent) = unifrnd(lower(bothSilent),upper(bothSilent));
            Offspring(bothSilent & ismember(encoding,2:4)) = round(Offspring(bothSilent & ismember(encoding,2:4)));
        end
    end

    function Del = Truncation(PopObj,K)
    % Select part of the solutions by SPEA2-style truncation.

        Distance = pdist2(PopObj,PopObj);
        Distance(logical(eye(length(Distance)))) = inf;
        Del = false(1,size(PopObj,1));
        while sum(Del) < K
            Remain = find(~Del);
            Temp   = sort(Distance(Remain,Remain),2);
            [~,Rank] = sortrows(Temp);
            Del(Remain(Rank(1))) = true;
        end
    end
end