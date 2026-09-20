function DiagHES_DTLZ2_M20()
%DiagHES_DTLZ2_M20  Replicate the first main-loop iteration of HES_EA_N100 on
%   DTLZ2 / M=20 stage by stage with tic-toc, to find which stage spins forever.
%   Read-only w.r.t. the algorithm folder: every stage is copied verbatim from
%   HES_EA_N100.m (lines 32-130) into this file.

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    warning('off','all');

    seed  = 22260912 + 1000*2 + 1;          % DTLZ2 = problem index 2, run 1
    M     = 20; D = 30; maxFE = 300; N = 100;
    wmax  = 20; WN = 190; KMeans = 4;

    rng(seed,'twister');
    Problem = feval('DTLZ2','M',M,'D',D,'maxFE',maxFE,'N',N);

    % --- initial design (verbatim) ---------------------------------------
    InitN = 100;
    P0 = UniformPoint(InitN,Problem.D,'Latin');
    PopDec = repmat(Problem.upper-Problem.lower,InitN,1).*P0+repmat(Problem.lower,InitN,1);
    Population = Problem.Evaluation(PopDec);
    fprintf('init done, FE=%d\n',Problem.FE);

    [W,~] = UniformPoint(WN,Problem.M);
    [ClW,~] = UniformPoint(KMeans,2);
    THETA_c = 5.*ones(KMeans+1,Problem.D);
    THETA_d = 5.*ones(KMeans+1,Problem.D);
    Model_c = cell(1,KMeans+1);
    Model_d = cell(1,KMeans+1);

    % --- one main-loop iteration, stage by stage -------------------------
    for round = 1:3
        fprintf('\n===== round %d =====\n',round);
        [~,index] = unique(Population.decs,'rows');
        Population = Population(index);
        PopDec = Population.decs;
        Zmin = min(Population.objs,[],1);
        [N,~] = size(PopDec);
        PopObj = Population.objs;
        NormObj = (Population.objs - Zmin);
        fprintf('  N=%d\n',N);

        t = tic;
        Cluster = zeros(N,1);
        ObjK = randperm(Problem.M,2);
        ClObj = NormObj(:,ObjK);
        temp = N;
        while temp > 0
            for i = 1:KMeans
                ang = acos(min(1,max(-1,1-pdist2(ClObj,ClW(i,:),'cosine'))));
                ang(isnan(ang) & ~isinf(ClObj(:,1))) = pi;
                [~,loc] = min(ang);
                Cluster(loc) = i;
                ClObj(loc,:) = inf;
                temp = temp - 1;
                if temp == 0, break; end
            end
        end
        fprintf('  clustering           %7.2f s  (temp=%d)\n',toc(t),temp);

        t = tic;
        Dis = pdist2(NormObj,W);
        [~,Loc] = min(Dis,[],2);
        Ic = sum(NormObj.*W(Loc,:),2);
        Id = DiversityIndi(PopObj);
        fprintf('  Ic/Id                %7.2f s\n',toc(t));

        t = tic;
        model_rg = fitcknn(PopDec,Cluster,'NumNeighbors',5);
        fprintf('  fitcknn              %7.2f s\n',toc(t));

        for i = 1:KMeans
            X_train_c = PopDec(Cluster==i,:); Y_train_c = Ic(Cluster==i);
            X_train_d = PopDec(Cluster==i,:); Y_train_d = Id(Cluster==i);
            t = tic;
            [X_train_c, Y_train_c] = dsmerge(X_train_c, Y_train_c);
            [X_train_d, Y_train_d] = dsmerge(X_train_d, Y_train_d);
            model_c = dacefit(X_train_c,Y_train_c,'regpoly0','corrgauss',THETA_c(i,:),1e-5.*ones(1,Problem.D),100.*ones(1,Problem.D));
            model_d = dacefit(X_train_d,Y_train_d,'regpoly0','corrgauss',THETA_d(i,:),1e-5.*ones(1,Problem.D),100.*ones(1,Problem.D));
            THETA_c(i,:) = model_c.theta; THETA_d(i,:) = model_d.theta;
            Model_c{i} = model_c; Model_d{i} = model_d;
            fprintf('  local dacefit %d      %7.2f s  (n=%d, n=%d)\n',i,toc(t),size(X_train_c,1),size(X_train_d,1));
        end
        t = tic;
        [X_train_c,Y_train_c] = dsmerge(PopDec,Ic);
        [X_train_d,Y_train_d] = dsmerge(PopDec,Id);
        model_c = dacefit(X_train_c,Y_train_c,'regpoly0','corrgauss',THETA_c(KMeans+1,:),1e-5.*ones(1,Problem.D),100.*ones(1,Problem.D));
        model_d = dacefit(X_train_d,Y_train_d,'regpoly0','corrgauss',THETA_d(KMeans+1,:),1e-5.*ones(1,Problem.D),100.*ones(1,Problem.D));
        THETA_c(KMeans+1,:) = model_c.theta; THETA_d(KMeans+1,:) = model_d.theta;
        Model_c{KMeans+1} = model_c; Model_d{KMeans+1} = model_d;
        fprintf('  global dacefit       %7.2f s\n',toc(t));

        t = tic;
        searchN = min(Problem.N,size(PopDec,1));
        % --- instrumented copy of CSS.m: dump state instead of spinning -----
        IcL = Ic; IdL = Id; PopL = PopDec; CluL = Cluster; MSEL = zeros(searchN,2);
        NewPop = []; NewIc = []; NewId = []; NewClus = []; NewMSE = [];
        counter = 0; passes = 0;
        fprintf('  CSS start: rows=%d target=%d Cluster==0 count=%d\n', ...
            size(PopL,1),searchN,sum(CluL==0));
        while counter < searchN
            passes = passes + 1;
            ave_c = zeros(1,KMeans);
            for i = 1:KMeans
                Loc = find(CluL==i);
                if ~isempty(Loc)
                    ave = sum(IcL(Loc))./length(Loc);
                    ave_c(i) = 1/(ave + 1.0);
                end
            end
            Pr = ave_c./(sum(ave_c));
            for i = 1:KMeans
                Loc = find(CluL==i);
                if rand(1) < Pr(i) && ~isempty(Loc)
                    F = [IcL(Loc),IdL(Loc)];
                    [front,~] = NDSort(F,inf);
                    optima = find(front==1);
                    choose = Loc(optima(randperm(numel(optima),1)));
                    NewPop = [NewPop;PopL(choose,:)];
                    NewIc = [NewIc;IcL(choose)]; NewId = [NewId;IdL(choose)];
                    NewClus = [NewClus;CluL(choose)]; NewMSE = [NewMSE;MSEL(choose,:)];
                    PopL(choose,:) = []; IcL(choose) = []; IdL(choose) = [];
                    CluL(choose) = []; MSEL(choose,:) = [];
                    counter = counter + 1;
                end
                if counter == searchN, break; end
            end
            if mod(passes,20000) == 0
                fprintf('  CSS pass %d: counter=%d/%d rows left=%d Cluster==0=%d Pr=[%s]\n', ...
                    passes,counter,searchN,size(PopL,1),sum(CluL==0),sprintf('%.3g ',Pr));
            end
            if passes >= 100000
                fprintf('  !! CSS still spinning: counter=%d/%d rows left=%d unassigned(Cluster==0)=%d Pr=[%s]\n', ...
                    counter,searchN,size(PopL,1),sum(CluL==0),sprintf('%.3g ',Pr));
                fprintf('  !! unassigned rows exist -> CSS can never reach counter=N\n');
                error('DiagHES:CSSHang','CSS cannot reach the target; state dumped above.');
            end
        end
        ArcDec = NewPop; ArcIc = NewIc; ArcId = NewId; ArcClus = NewClus;
        fprintf('  CSS                  %7.2f s  (passes=%d, searchN=%d)\n',toc(t),passes,searchN);

        w = 0;
        t = tic;
        while w < wmax
            OffDec = OperatorGA(Problem, ArcDec);
            w = w + 1;
            [n,~] = size(OffDec);
            OffClus = predict(model_rg,OffDec);
            OffIc = zeros(n,1); OffId = OffIc; OffMSE = zeros(n,2);
            for i = 1:n
                loc = double(OffClus(i));
                if ~(loc>=1 && loc<=KMeans && loc==floor(loc)), loc = KMeans+1; end
                [Yc_local,~,mse_local] = predictor(OffDec(i,:),Model_c{loc});
                [Yc_global,~,mse_global] = predictor(OffDec(i,:),Model_c{KMeans+1});
                if mse_local < mse_global, OffIc(i) = Yc_local; OffMSE(i,1) = mse_local;
                else, OffIc(i) = Yc_global; OffMSE(i,1) = mse_global; end
                [Yd_local,~,mse_local] = predictor(OffDec(i,:),Model_d{loc});
                [Yd_global,~,mse_global] = predictor(OffDec(i,:),Model_d{KMeans+1});
                if mse_local < mse_global, OffId(i) = Yd_local; OffMSE(i,2) = mse_local;
                else, OffId(i) = Yd_global; OffMSE(i,2) = mse_global; end
            end
            ArcDec = [ArcDec;OffDec]; ArcIc = [ArcIc;OffIc];
            ArcId = [ArcId;OffId]; ArcClus = [ArcClus;OffClus];
            ArcMSE = [ArcMSE;OffMSE];
            ArcIc = ArcIc-min(ArcIc);
            [ArcDec,ArcIc,ArcId,ArcClus,ArcMSE] = ModiCSS(ArcDec,ArcIc,ArcId,ArcClus,ArcMSE,KMeans,searchN);
        end
        fprintf('  GA+CSS x%d           %7.2f s  (ArcDec %d rows)\n',wmax,toc(t),size(ArcDec,1));

        t = tic;
        OldDec = Population.decs; Loc = [];
        for i = 1:size(ArcDec,1)
            for j = 1:N
                if isequal(ArcDec(i,:),OldDec(j,:)), Loc = [Loc,i]; break; end
            end
        end
        ArcDec(Loc,:) = []; ArcIc(Loc) = []; ArcId(Loc) = [];
        ArcClus(Loc) = []; ArcMSE(Loc,:) = [];
        fprintf('  dedup                %7.2f s  (removed %d of %d -> %d left)\n', ...
            toc(t),numel(Loc),numel(Loc)+size(ArcDec,1),size(ArcDec,1));

        [n,~] = size(ArcDec);
        if n <= 5
            NewArc = ArcDec;
        else
            NewArc = [];
            clus = kmeans(ArcDec,5,'EmptyAction','singleton');
            for i = 1:5
                Ci = find(clus==i);
                if isempty(Ci), continue; end
                [fr,~] = NDSort(-ArcMSE(Ci,:),inf);
                uncertain = find(fr==1);
                if isempty(uncertain), continue; end
                choose = Ci(uncertain(randperm(numel(uncertain),1)));
                NewArc = [NewArc;ArcDec(choose,:)];
            end
        end
        fprintf('  infill selection     %7.2f s  -> NewArc %d rows\n',toc(t),size(NewArc,1));

        if ~isempty(NewArc)
            NewArc = NewArc(1:min(size(NewArc,1),max(0,floor(Problem.maxFE-Problem.FE))),:);
            PopNew = Problem.Evaluation(NewArc);
            Population = [Population,PopNew];
        end
        fprintf('  FE now %d\n',Problem.FE);
        if isempty(NewArc)
            fprintf('  !! NewArc empty -> the original algorithm would loop forever\n');
        end
    end
    fprintf('\nDIAG DONE\n');
end
