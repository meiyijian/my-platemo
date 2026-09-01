classdef SparseEMT < ALGORITHM
% <2025> <multi> <real/integer/binary> <large/none> <constrained/none> <sparse>
% Sparse evolutionary multitasking
% nSample  ---    5 --- Number of sampling iterations for multitask construction
% auxRate  --- 0.25 --- Population ratio for each auxiliary task
% solverID ---    1 --- Embedded solver: 1 = MSKEA, 2 = MGCEA

%------------------------------- Reference --------------------------------
% J. Jiang, X. Fang, H. Wang, P. Tong, Z. Liu, B. Su, and F. Han. Turning
% sparse large-scale multiobjective optimization into evolutionary
% multitasking. IEEE Transactions on Evolutionary Computation, 2025.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2026 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Jing Jiang and Xiang Fang (email: jingj0608@126.com)

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            [nSample,auxRate,solverID] = Algorithm.ParameterSet(5,0.25,1);
            nSample = max(1,round(nSample));
            auxRate = min(1,max(0,auxRate));
            solverID = round(solverID);

            %% SparseEMT with a selected solver adapter
            Solver = CreateSolver(solverID);
            ValidateSolver(Solver);
            [Task,VarScore,SamplePop,SampleDec,SampleMask] = MultitaskConstruct(Problem,nSample);
            Framework  = struct('VarScore',VarScore,'SamplePop',SamplePop,'SampleDec',SampleDec,'SampleMask',SampleMask);
            State      = Solver.NewState(Problem,Framework);
            [Population,Dec,Mask,Skill,State] = Solver.Initialize(Problem,Framework,State);
            [Dec,Mask] = NormalizeSparseEncoding(Problem,Dec,Mask);
            Population = AttachSparseAdd(Population,Dec,Mask,Skill);
        
            %% Optimization
            while Algorithm.NotTerminated(Population)
                [Population,Dec,Mask,Skill,Rank,Crowd] = MultitaskUpdate(Problem,Task,Population,Dec,Mask,Skill,Problem.N,auxRate,Solver,State);
                [State,Rank,Crowd]                     = Solver.UpdateState(Problem,Population,Dec,Mask,Skill,Rank,Crowd,State);
                MatingPool                             = Solver.MatingSelection(Problem.N,Rank,Crowd,State);
                [OffDec,OffMask,OffSkill]              = SparseKT(Problem,Task,Dec(MatingPool,:),Mask(MatingPool,:),Skill(MatingPool),Solver,State);
                [OffDec,OffMask]                       = NormalizeSparseEncoding(Problem,OffDec,OffMask);
                Offspring                              = Problem.Evaluation(OffDec.*OffMask,SparseAdd(OffDec,OffMask,OffSkill));
                [Population,Dec,Mask,Skill,State]      = Solver.EnvironmentalSelection(Problem,[Population,Offspring],[Dec;OffDec],[Mask;OffMask],[Skill;OffSkill],Problem.N,State);
            end
        end
    end
end

function ValidateSolver(Solver)
% Check the adapter contract before a long experiment starts.

    required = {'NewState','Initialize','UpdateState','MatingSelection','Operator','TaskOperator', ...
                'EnvironmentalSelection','Ranking','SelectTop','RandomSparseDecision'};
    missing = required(~isfield(Solver,required));
    assert(isempty(missing),'SparseEMT:InvalidSolver','Solver adapter misses: %s',strjoin(missing,', '));
    for i = 1 : length(required)
        assert(isa(Solver.(required{i}),'function_handle'),'SparseEMT:InvalidSolver','Solver.%s must be a function handle.',required{i});
    end
end

function [Task,VarScore,SamplePop,SampleDec,SampleMask] = MultitaskConstruct(Problem,nSample)
% Construct the original task and sparse reduced tasks.

    D               = Problem.D;
    isBinary        = IsBinaryProblem(Problem);
    constructRepeat = 2;
    sampleLoop      = nSample;
    if isBinary
        constructRepeat = 1;
        sampleLoop      = 1;
    end
    totalSample  = constructRepeat*sampleLoop;
    frequency    = zeros(1,D);
    VarScore     = zeros(1,D);
    baseDec      = min(max(zeros(1,D),Problem.lower),Problem.upper);
    maxSample    = totalSample*D;
    memorySaving = maxSample*D > 5e7;
    archiveSize  = maxSample;
    if memorySaving
        archiveSize = min(maxSample,max(Problem.N,min(1000,10*Problem.N)));
    end
    SamplePop  = SOLUTION.empty(1,0);
    SampleDec  = zeros(0,D);
    SampleMask = false(0,D);
    Base       = Problem.Evaluation(baseDec);
    Interval   = (Problem.upper-Problem.lower)./max(1,sampleLoop);
    Mask       = logical(eye(D));
    diagIndex  = 1 : D+1 : D*D;

    for i = 1 : sampleLoop
        lower = Problem.lower + Interval*(i-1);
        upper = Problem.lower + Interval*i;
        for r = 1 : constructRepeat
            if isBinary
                Dec = ones(D,D);
                Pop = Problem.Evaluation(Dec.*Mask,SparseAdd(Dec,Mask,ones(D,1)));
            elseif memorySaving
                diagValue = lower + rand(1,D).*(upper-lower);
                diagValue(Problem.encoding==4) = 1;
                Dec = zeros(D,D);
                Dec(diagIndex) = diagValue;
                Pop = Problem.Evaluation(Dec,SparseAdd(Dec,Mask,ones(D,1)));
            else
                Dec = unifrnd(repmat(lower,D,1),repmat(upper,D,1));
                Dec(:,Problem.encoding==4) = 1;
                Pop = Problem.Evaluation(Dec.*Mask,SparseAdd(Dec,Mask,ones(D,1)));
            end
            FrontNo  = NDSort([Base.objs;Pop.objs],[Base.cons;Pop.cons],inf);
            rankBase = FrontNo(1);
            rankVars = FrontNo(2:end);
            selected = rankVars <= rankBase;
            if ~any(selected)
                [~,rank] = sort(rankVars,'ascend');
                selected(rank(1:max(1,ceil(0.05*D)))) = true;
            end
            frequency = frequency + selected;
            rankVars(~isfinite(rankVars)) = D + 1;
            VarScore = VarScore + rankVars;
            [SamplePop,SampleDec,SampleMask] = UpdateSampleArchive(SamplePop,SampleDec,SampleMask,Pop,Dec,Mask,archiveSize);
        end
    end

    unionMask = frequency > 0;
    interMask = frequency >= totalSample;

    if ~any(unionMask)
        [~,rank] = sort(VarScore,'ascend');
        unionMask(rank(1:max(1,ceil(0.1*D)))) = true;
    end
    candidate = find(unionMask);
    if nnz(interMask) < max(1,ceil(0.5*length(candidate)))
        [~,rank] = sortrows([-frequency(candidate)',VarScore(candidate)']);
        interMask(candidate(rank(1:max(1,ceil(0.5*length(candidate)))))) = true;
    end

    Task(1).Dim = 1 : D;
    Task(2).Dim = find(unionMask);
    if ~isBinary
        Task(3).Dim = find(interMask);
    end
    VarScore = max(VarScore,eps);
end

function [ArchivePop,ArchiveDec,ArchiveMask] = UpdateSampleArchive(ArchivePop,ArchiveDec,ArchiveMask,Pop,Dec,Mask,archiveSize)
% Keep enough sampled individuals for initialization without storing all D^2 latent values.

    if isempty(ArchivePop)
        ArchivePop  = Pop;
        ArchiveDec  = Dec;
        ArchiveMask = Mask;
    else
        ArchivePop  = [ArchivePop,Pop];
        ArchiveDec  = [ArchiveDec;Dec];
        ArchiveMask = [ArchiveMask;Mask];
    end
    if length(ArchivePop) > archiveSize
        [FrontNo,MaxFNo] = NDSort(ArchivePop.objs,ArchivePop.cons,archiveSize);
        Next   = FrontNo < MaxFNo;
        Last   = find(FrontNo == MaxFNo);
        remain = archiveSize - sum(Next);
        if remain > 0
            CrowdDis = CrowdingDistance(ArchivePop.objs,FrontNo);
            [~,rank] = sort(CrowdDis(Last),'descend');
            Next(Last(rank(1:min(remain,length(rank))))) = true;
        end
        ArchivePop  = ArchivePop(Next);
        ArchiveDec  = ArchiveDec(Next,:);
        ArchiveMask = ArchiveMask(Next,:);
    end
end

function [Population,Dec,Mask,Skill,Rank,Crowd] = MultitaskUpdate(Problem,Task,Population,Dec,Mask,Skill,N,auxRate,Solver,State)
% Rebuild task populations while keeping task dimensions unchanged.

    [Pop1,Dec1,Mask1] = MainTaskPopulation(Problem,Population,Dec,Mask,Skill,N,Solver,State);
    Skill1 = ones(length(Pop1),1);

    auxN     = max(1,floor(N*auxRate));
    order    = Solver.SelectTop(Population,length(Population),State);
    take     = order(1:min(auxN,length(order)));
    nAux     = length(take);
    auxTaskN = max(0,length(Task)-1);
    totalN   = length(Pop1) + auxTaskN*nAux;
    PopAll(1,totalN) = SOLUTION;
    PopAll(1:length(Pop1)) = Pop1;
    DecAll   = zeros(totalN,Problem.D);
    MaskAll  = false(totalN,Problem.D);
    SkillAll = zeros(totalN,1);
    DecAll(1:length(Pop1),:)   = Dec1;
    MaskAll(1:length(Pop1),:)  = Mask1;
    SkillAll(1:length(Pop1),:) = Skill1;
    cursor = length(Pop1);
    for t = 2 : length(Task)
        DecT  = Dec(take,:);
        MaskT = Mask(take,:);
        PopT  = Population(take);    % Objectives are always from the original problem.
        if t == 3
            OldMaskT = MaskT;
            MaskT(:,Task(t).Dim) = true;
            if any(MaskT(:) ~= OldMaskT(:))
                PopT = Problem.Evaluation(DecT.*MaskT,SparseAdd(DecT,MaskT,zeros(size(DecT,1),1)+t));
            end
        end
        [DecT,MaskT] = NormalizeSparseEncoding(Problem,DecT,MaskT);
        next = cursor + (1:length(PopT));
        PopAll(next)      = PopT;
        DecAll(next,:)    = DecT;
        MaskAll(next,:)   = MaskT;
        SkillAll(next,:)  = t;
        cursor = cursor + length(PopT);
    end

    Population   = PopAll(1:cursor);
    Dec          = DecAll(1:cursor,:);
    Mask         = MaskAll(1:cursor,:);
    Skill        = SkillAll(1:cursor,:);
    [Rank,Crowd] = Solver.Ranking(Problem,Population,Dec,Mask,Skill,State);
end

function [Pop1,Dec1,Mask1] = MainTaskPopulation(Problem,Population,Dec,Mask,Skill,N,Solver,State)
% Keep the main task at N individuals, refilling it with transferred solutions.

    mainIndex  = find(Skill==1);
    needRefine = length(mainIndex) < N;
    if length(mainIndex) >= N
        sub       = Solver.SelectTop(Population(mainIndex),N,State);
        mainIndex = mainIndex(sub);
        Pop1      = Population(mainIndex);
        Dec1      = Dec(mainIndex,:);
        Mask1     = Mask(mainIndex,:);
    else
        fillNum = N - length(mainIndex);
        order   = Solver.SelectTop(Population,length(Population),State);
        order(ismember(order,mainIndex)) = [];
        fillIndex = order(1:min(fillNum,length(order)));
        PopFill   = Population(fillIndex);
        DecFill   = Dec(fillIndex,:);
        MaskFill  = Mask(fillIndex,:);
        if size(DecFill,1) < fillNum
            rest = fillNum - size(DecFill,1);
            [RandDec,RandMask] = Solver.RandomSparseDecision(Problem,rest,State);
            RandPop  = Problem.Evaluation(RandDec.*RandMask,SparseAdd(RandDec,RandMask,ones(rest,1)));
            PopFill  = [PopFill,RandPop];
            DecFill  = [DecFill;RandDec];
            MaskFill = [MaskFill;RandMask];
        end
        Pop1  = [Population(mainIndex),PopFill];
        Dec1  = [Dec(mainIndex,:);DecFill];
        Mask1 = [Mask(mainIndex,:);MaskFill];
    end
    if needRefine && isfield(State,'mainRefineGen') && State.mainRefineGen > 0
        [Pop1,Dec1,Mask1] = RefineMainPopulation(Problem,Pop1,Dec1,Mask1,N,Solver,State,State.mainRefineGen);
    end
end

function [Population,Dec,Mask] = RefineMainPopulation(Problem,Population,Dec,Mask,N,Solver,State,nGen)
% Let a refilled main-task population self-evolve briefly on the original task.

    Skill = ones(length(Population),1);
    for g = 1 : nGen
        [Rank,Crowd] = Solver.Ranking(Problem,Population,Dec,Mask,Skill,State);
        MatingPool   = Solver.MatingSelection(N,Rank,Crowd,State);
        [OffDec,OffMask,OffSkill] = SparseKT(Problem,[],Dec(MatingPool,:),Mask(MatingPool,:),Skill(MatingPool),Solver,State);
        Offspring    = Problem.Evaluation(OffDec.*OffMask,SparseAdd(OffDec,OffMask,OffSkill));
        [Population,Dec,Mask,Skill] = Solver.EnvironmentalSelection(Problem,[Population,Offspring],[Dec;OffDec],[Mask;OffMask],[Skill;OffSkill],N,State);
    end
end

function [OffDec,OffMask,OffSkill] = SparseKT(Problem,Task,ParentDec,ParentMask,ParentSkill,Solver,State)
% Sparse knowledge transfer among the main task and two auxiliary tasks.

    pairNum     = floor(size(ParentDec,1)/2);
    order       = randperm(size(ParentDec,1),pairNum*2);
    ParentDec   = ParentDec(order,:);
    ParentMask  = ParentMask(order,:);
    ParentSkill = ParentSkill(order);
    OffDec      = zeros(pairNum,Problem.D);
    OffMask     = false(pairNum,Problem.D);
    OffSkill    = ones(pairNum,1);

    for i = 1 : pairNum
        p     = i;
        q     = i + pairNum;
        sp    = ParentSkill(p);
        sq    = ParentSkill(q);
        pDec  = ParentDec(p,:);
        qDec  = ParentDec(q,:);
        pMask = ParentMask(p,:);
        qMask = ParentMask(q,:);
        if sp == sq
            if sp == 1
                [OffDec(i,:),OffMask(i,:)] = Solver.Operator(Problem,[pDec;qDec],[pMask;qMask],State);
            else
                [OffDec(i,:),OffMask(i,:)] = Solver.TaskOperator(Problem,[pDec;qDec],[pMask;qMask],Task(sp),1,State,false);
            end
            OffSkill(i) = sp;
        else
            if sp > sq
                [sp,sq]       = deal(sq,sp);
                [pDec,qDec]   = deal(qDec,pDec);
                [pMask,qMask] = deal(qMask,pMask);
            end
            if sp ~= 1
                if rand > 0.5
                    [OffDec(i,:),OffMask(i,:)] = Solver.TaskOperator(Problem,[pDec;qDec],[pMask;qMask],Task(sp),1,State,true);
                    OffSkill(i) = sp;
                else
                    [OffDec(i,:),OffMask(i,:)] = Solver.TaskOperator(Problem,[pDec;qDec],[pMask;qMask],Task(sq),2,State,true);
                    OffSkill(i) = sq;
                end
            else
                if rand > 0.5
                    [OffDec(i,:),OffMask(i,:)] = Solver.Operator(Problem,[pDec;qDec],[pMask;qMask],State);
                    OffSkill(i) = sp;
                else
                    [OffDec(i,:),OffMask(i,:)] = Solver.TaskOperator(Problem,[pDec;qDec],[pMask;qMask],Task(sq),2,State,true);
                    OffSkill(i) = sq;
                end
            end
        end
    end
    [OffDec,OffMask] = NormalizeSparseEncoding(Problem,OffDec,OffMask);
end

function Solver = CreateSolver(solverID)
% Select an embedded optimizer adapter.

    AddEmbeddedSolverPath(solverID);
    Shared = SparseEMTShared();
    switch solverID
        case 1
            Solver = SparseEMTSolverMSKEA(Shared);
        case 2
            Solver = SparseEMTSolverMGCEA(Shared);
        otherwise
            error('SparseEMT:UnknownSolver','Unknown embedded solver ID: %d.',solverID);
    end
end

function AddEmbeddedSolverPath(solverID)
% Make the selected sibling solver visible when the framework is called directly.

    frameworkDir = fileparts(mfilename('fullpath'));
    addpath(frameworkDir);
    baseDir = fileparts(frameworkDir);
    switch solverID
        case 1
            solverName = 'MSKEA';
        case 2
            solverName = 'MGCEA';
        otherwise
            solverName = '';
    end
    solverDir = fullfile(baseDir,solverName);
    if ~isempty(solverName) && exist(solverDir,'dir')
        addpath(solverDir);
    end
end

function Shared = SparseEMTShared()
% Shared SparseEMT utilities used by embedded-solver adapters.

    Shared.SparseAdd               = @SparseAdd;
    Shared.AttachSparseAdd         = @AttachSparseAdd;
    Shared.SparseStateFromAdd      = @SparseStateFromAdd;
    Shared.TaskOperator            = @TaskOperator;
    Shared.SparseUnique            = @SparseUnique;
    Shared.Ranking                 = @Ranking;
    Shared.SelectTop               = @SelectTop;
    Shared.RandomSparseDecision    = @RandomSparseDecision;
    Shared.GArealSubset            = @GArealSubset;
    Shared.NormalizeSparseEncoding = @NormalizeSparseEncoding;
end

function Add = SparseAdd(Dec,Mask,Skill)
% Store SparseEMT latent state in SOLUTION.add.

    Add = [Dec,double(Mask),Skill(:)];
end

function Population = AttachSparseAdd(Population,Dec,Mask,Skill)
% Keep SOLUTION.add aligned after reusing or selecting existing solutions.

    Add = SparseAdd(Dec,Mask,Skill);
    for i = 1 : length(Population)
        Population(i).add = Add(i,:);
    end
end

function [Dec,Mask,Skill] = SparseStateFromAdd(Population,D,Dec,Mask)
% Recover SparseEMT state after selection performed by an embedded solver.

    if isempty(Population)
        Skill = zeros(0,1);
        return;
    end
    Add = Population.adds(SparseAdd(Dec,Mask,ones(length(Population),1)));
    if size(Add,2) >= 2*D+1
        Dec   = Add(:,1:D);
        Mask  = logical(Add(:,D+1:2*D));
        Skill = Add(:,2*D+1);
    else
        Skill = ones(length(Population),1);
    end
end

function [OffDec,OffMask] = TaskOperator(Problem,ParentDec,ParentMask,Task,anchor,~,transfer)
% SparseEMT auxiliary-task operator for two-layer sparse encodings.

    if nargin < 5
        anchor = 1;
    end
    dim = Task.Dim(:)';
    if isempty(dim)
        dim = 1 : Problem.D;
    end
    OffDec  = ParentDec(anchor,:);
    OffMask = ParentMask(anchor,:);
    other   = 3 - anchor;
    outside = true(1,Problem.D);
    outside(dim) = false;
    if nargin >= 7 && transfer
        OffDec(outside)  = ParentDec(other,outside);
        OffMask(outside) = ParentMask(other,outside);
    end

    if any(Problem.encoding(dim)~=4)
        OffDec(dim)    = GArealSubset(ParentDec(1,dim),ParentDec(2,dim),Problem.lower(dim),Problem.upper(dim),1,20,1,20,Problem.encoding(dim));
        binDim         = dim(Problem.encoding(dim)==4);
        OffDec(binDim) = 1;
    else
        OffDec(dim) = 1;
    end
    OffMask(dim)     = SparseEMTMaskOperator(ParentMask(1,dim),ParentMask(2,dim));
    [OffDec,OffMask] = NormalizeSparseEncoding(Problem,OffDec,OffMask);
end

function OffMask = SparseEMTMaskOperator(Parent1Mask,Parent2Mask)
% Algorithm 5 mask operator: uniform crossover, bit-flip, and consensus inheritance.

    D = size(Parent1Mask,2);
    OffMask = Parent1Mask;
    if D == 0
        return;
    end
    exchange = rand(1,D) < 0.5;
    OffMask(exchange) = Parent2Mask(exchange);
    mutation = rand(1,D) < 1/D;
    OffMask(mutation) = ~OffMask(mutation);
    OffMask(Parent1Mask & Parent2Mask)   = true;
    OffMask(~Parent1Mask & ~Parent2Mask) = false;
end

function uni = SparseUnique(Population,Mask)
% Delete duplicates while preserving sparse-mask diversity.

    key     = [round(Population.objs,12),round(Population.cons,12),double(Mask)];
    [~,uni] = unique(key,'rows','stable');
end

function [FrontNo,CrowdDis] = Ranking(~,Population,~,~,~,~)
    if isempty(Population)
        FrontNo  = [];
        CrowdDis = [];
    else
        [FrontNo,~] = NDSort(Population.objs,Population.cons,length(Population));
        CrowdDis    = CrowdingDistance(Population.objs,FrontNo);
    end
end

function index = SelectTop(Population,N,~)
    N = min(N,length(Population));
    if N <= 0
        index = [];
    else
        [FrontNo,~] = NDSort(Population.objs,Population.cons,N);
        CrowdDis    = CrowdingDistance(Population.objs,FrontNo);
        [~,rank]    = sortrows([FrontNo(:),-CrowdDis(:)]);
        index       = rank(1:N);
    end
end

function [Dec,Mask] = RandomSparseDecision(Problem,N,State)
    Dec  = unifrnd(repmat(Problem.lower,N,1),repmat(Problem.upper,N,1));
    Mask = false(N,Problem.D);
    for i = 1 : N
        nActive = ceil(rand*Problem.D);
        if isempty(State) || ~isfield(State,'pv')
            index = randperm(Problem.D,nActive);
        else
            index = TournamentSelection(2,nActive,State.pv);
        end
        Mask(i,index) = true;
    end
    [Dec,Mask] = NormalizeSparseEncoding(Problem,Dec,Mask);
end

function Offspring = GArealSubset(Parent1,Parent2,lower,upper,proC,disC,proM,disM,encoding)
% SBX and polynomial mutation in a selected subspace.

    if isempty(Parent1)
        Offspring = Parent1;
        return;
    end
    SubProblem.encoding = encoding;
    SubProblem.lower    = lower;
    SubProblem.upper    = upper;
    Offspring = OperatorGAhalf(SubProblem,[Parent1;Parent2],{proC,disC,proM,disM});
    Offspring(ismember(encoding,2:4)) = round(Offspring(ismember(encoding,2:4)));
end

function tf = IsBinaryProblem(Problem)
% True when the whole problem is binary-encoded in PlatEMO.

    tf = all(Problem.encoding == 4);
end

function [Dec,Mask] = NormalizeSparseEncoding(Problem,Dec,Mask)
% Keep binary variables represented by Mask, with latent Dec fixed to one.

    Mask = logical(Mask);
    if isempty(Dec)
        return;
    end
    binary = Problem.encoding == 4;
    if any(binary)
        Dec(:,binary) = 1;
    end
    integer = ismember(Problem.encoding,2:4);
    if any(integer)
        Dec(:,integer) = round(Dec(:,integer));
    end
end