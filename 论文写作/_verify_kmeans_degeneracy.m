function verify_kmeans_degeneracy()
% Verify that AdaptiveReferenceVectors' k-means is an identity map on the
% nondominated front under the paper's experimental setting (D=30 -> Nref=Np=100).

rng(20260901,'twister');
fid = fopen(fullfile(tempdir,'kmeans_degen_out.txt'),'w');
logf(fid,'== k-means degeneracy check ==');

for M = [5 10 20]
    N = 100; Nref = 100;   % D=30 => N_init=100; Problem.N=100
    % DTLZ2-like sample: unit-sphere directions scaled by (1+g)
    X = abs(randn(N,M));
    X = X ./ vecnorm(X,2,2);
    g = 0.15*rand(N,1);
    PopObj = X .* (1+g);

    FrontNo   = NDSort(PopObj,1);
    ParetoObj = PopObj(FrontNo==1,:);
    nP = size(ParetoObj,1);

    gateUniform = (M<=3) || (N<50);
    gateFallback = (nP < max(10,Nref/2)) || (nP < 2);

    Zmin_nd = min(ParetoObj,[],1); Zmax_nd = max(ParetoObj,[],1);
    rng_nd  = Zmax_nd - Zmin_nd;
    Pnorm   = (ParetoObj - Zmin_nd)./rng_nd;

    nClusters = min(Nref,nP);
    [~,C] = kmeans(Pnorm,nClusters,'MaxIter',100,'Replicates',5,'EmptyAction','singleton');

    % Is the centroid set the point set (up to permutation)?
    Dm      = pdist2(C,Pnorm);
    maxdev  = max(min(Dm,[],2));          % each centroid -> nearest ND point
    maxdev2 = max(min(Dm,[],1));          % each ND point -> nearest centroid

    % Build V exactly as the code does
    Vc = C;
    if size(Vc,1) < Nref
        Vc = repmat(Vc,ceil(Nref/size(Vc,1)),1); Vc = Vc(1:Nref,:);
    end
    V = Vc.*rng_nd + Zmin_nd;
    V = V./vecnorm(V,2,2);

    % Compare against "just unit-normalise the ND objective vectors"
    Vdirect = ParetoObj./vecnorm(ParetoObj,2,2);
    dirDev  = max(min(pdist2(V,Vdirect),[],2));
    nUniqueDir = size(unique(round(V,10),'rows'),1);

    % score_v under this V, and its correlation with -||f-z*||
    Zmin = min(PopObj,[],1);
    cosine = 1 - pdist2(PopObj,V,'cosine');
    [~,ai] = max(cosine,[],2);
    d1 = zeros(N,1); d2 = zeros(N,1);
    for i = 1:N
        w = V(ai(i),:);
        d1(i) = (PopObj(i,:)-Zmin)*w'/norm(w);
        d2(i) = norm(PopObj(i,:)-(Zmin+d1(i)*w));
    end
    s = 1./(1+d1+5*d2);
    dist_ideal = vecnorm(PopObj-Zmin,2,2);
    rho_norm   = corr(s,-dist_ideal,'type','Pearson');
    rho_spear  = corr(s,-dist_ideal,'type','Spearman');

    % self-association rate among ND solutions
    ndIdx = find(FrontNo==1);
    selfHit = 0;
    for t = 1:numel(ndIdx)
        i = ndIdx(t);
        [~,nearest] = min(pdist2(V(ai(i),:),Vdirect),[],2);
        if nearest == t, selfHit = selfHit + 1; end
    end

    logf(fid,'M=%2d nND=%3d gateUniform=%d gateFallback=%d nClusters=%d (==nND: %d)', ...
        M,nP,gateUniform,gateFallback,nClusters,nClusters==nP);
    logf(fid,'      centroid<->point max dev = %.3e / %.3e  (0 => identity map)',maxdev,maxdev2);
    logf(fid,'      max dev V vs unit-normalised ND objs = %.3e',dirDev);
    logf(fid,'      #unique directions = %d  (Nref=%d)',nUniqueDir,Nref);
    logf(fid,'      ND self-association rate = %d/%d = %.3f',selfHit,numel(ndIdx),selfHit/numel(ndIdx));
    logf(fid,'      corr(s_i, -||f-z*||): Pearson=%.4f Spearman=%.4f',rho_norm,rho_spear);
    logf(fid,'      spread max(s)-min(s) = %.4f  => switch at rho >= %.4f', ...
        max(s)-min(s), 1 - 1/(1+(max(s)-min(s))));
end
fclose(fid);
type(fullfile(tempdir,'kmeans_degen_out.txt'));
end

function logf(fid,varargin)
    msg = sprintf(varargin{:});
    fprintf('%s\n',msg);
    fprintf(fid,'%s\n',msg);
end
