% Statistics from completed first-nine runs, plus diagnostic projections.
out='D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned/diagnostics/pruned_diagnosis_20260911';
addpath(genpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO'));
R=jsondecode(fileread(fullfile(out,'archive_summary.json')));
load(fullfile(out,'numerical_archives.mat'),'Raw');
problems={'DTLZ2','DTLZ5','DTLZ7','WFG4','WFG7','WFG9'};
comparators={'Original','Maximin'};
rng(913,'twister');
Stats=struct([]);n=0;
for ci=1:numel(comparators)
    for pi=1:numel(problems)
        idxA=strcmp({R.variant},'Pruned') & strcmp({R.problem},problems{pi}) & [R.run]<=9;
        idxB=strcmp({R.variant},comparators{ci}) & strcmp({R.problem},problems{pi}) & [R.run]<=9;
        a=[R(idxA).savedIGD]';b=[R(idxB).savedIGD]';
        stat.problem=problems{pi};stat.comparator=comparators{ci};
        stat.nPruned=numel(a);stat.nComparator=numel(b);
        stat.meanPruned=mean(a);stat.meanComparator=mean(b);
        stat.percentChange=100*(mean(a)/mean(b)-1);
        stat.pExact=ranksum(a,b,'method','exact');
        stat.cliffsDelta=mean(sign(a-b'),'all');
        ba=mean(a(randi(numel(a),numel(a),10000)),1);
        bb=mean(b(randi(numel(b),numel(b),10000)),1);
        stat.meanDifferenceCI=prctile(ba-bb,[2.5,97.5]);
        stat.pHolm=NaN;
        n=n+1;if n==1,Stats=stat;else,Stats(n)=stat;end
    end
    ids=find(strcmp({Stats.comparator},comparators{ci}));
    [pv,ord]=sort([Stats(ids).pExact]);
    adjusted=min(1,cummax(pv.*(numel(pv):-1:1)));
    for j=1:numel(ids),Stats(ids(ord(j))).pHolm=adjusted(j);end
end
fid=fopen(fullfile(out,'statistics.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(Stats));fclose(fid);
disp(struct2table(Stats));
Projection=struct([]);n=0;
for i=1:numel(Raw)
    v=Raw(i);
    if v.run>9 || ~ismember(v.problem,{'DTLZ2','DTLZ5'}),continue;end
    p=feval(v.problem,'M',10,'D',30);
    xp=v.X;xp(:,10:end)=0.5;
    fp=p.CalObj(xp);
    rr.variant=v.variant;rr.problem=v.problem;rr.run=v.run;
    rr.initialProjectedIGD=mean(min(pdist2(p.optimum,fp(1:100,:)),[],2));
    rr.newProjectedIGD=mean(min(pdist2(p.optimum,fp(101:end,:)),[],2));
    n=n+1;if n==1,Projection=rr;else,Projection(n)=rr;end
end
fid=fopen(fullfile(out,'projection_details.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(Projection));fclose(fid);
