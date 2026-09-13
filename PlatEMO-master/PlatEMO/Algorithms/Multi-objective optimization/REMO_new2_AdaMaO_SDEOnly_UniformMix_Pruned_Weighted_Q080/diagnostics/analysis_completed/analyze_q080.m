addpath(genpath('D:/PlatEMO-master/PlatEMO-master/PlatEMO'));
base='C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30';
out=fileparts(mfilename('fullpath'));
prefix='REMO_new2_AdaMaO_SDEOnly_UniformMix_';
variants={'Original','Pruned_Weighted','Pruned_Weighted_Q080','Pruned_Weighted_Q070','Pruned'};
problems={'DTLZ2','DTLZ5','DTLZ7','WFG7'};
R=struct([]);S=struct([]);P=struct([]);bad={};
for vi=1:numel(variants)
 alg=[prefix,variants{vi}];
 for pi=1:numel(problems)
  for ri=1:18
   file=fullfile(base,alg,sprintf('%s_%s_M10_D30_%d.mat',alg,problems{pi},ri));
   if ~isfile(file),continue;end
   try
    d=load(file,'result','metric');
    if vi==3 || vi==4
     m=load(file,'metadata');d.metadata=m.metadata;
    end
    assert(d.result{end,1}==300 && isfield(d.metric,'IGD') && isfinite(d.metric.IGD(end)));
    r=struct('variant',variants{vi},'problem',problems{pi},'run',ri,'FE',d.result{end,1},'IGD',d.metric.IGD(end),'runtime',d.metric.runtime,'seed',NaN,'qKeep',NaN,'modeRunId',NaN,'file',file);
    if isfield(d,'metadata')
     r.seed=d.metadata.seed;r.qKeep=d.metadata.parameters{4};r.modeRunId=d.metadata.modeRunId;
    end
    if isempty(R),R=r;else,R(end+1)=r;end %#ok<SAGROW>
   catch err
    bad{end+1}=struct('file',file,'error',err.message); %#ok<SAGROW>
   end
  end
 end
end
for vi=[1,2,5]
 for pi=1:4
  x=[R(strcmp({R.variant},variants{3}) & strcmp({R.problem},problems{pi})).IGD];
  y=[R(strcmp({R.variant},variants{vi}) & strcmp({R.problem},problems{pi})).IGD];
  s=struct('comparator',variants{vi},'problem',problems{pi},'nx',numel(x),'ny',numel(y),'meanQ080',mean(x),'sdQ080',std(x),'meanOther',mean(y),'sdOther',std(y),'relativePercent',100*(mean(x)/mean(y)-1),'pExact',ranksum(x,y,'method','exact'),'pHolm',NaN);
  if isempty(S),S=s;else,S(end+1)=s;end %#ok<SAGROW>
 end
 ids=find(strcmp({S.comparator},variants{vi}));[ps,ord]=sort([S(ids).pExact]);pa=min(1,cummax(ps.*(4:-1:1)));
 for j=1:4,S(ids(ord(j))).pHolm=pa(j);end
end
for pi=1:4
 x=R(strcmp({R.variant},variants{3}) & strcmp({R.problem},problems{pi}));
 y=R(strcmp({R.variant},variants{4}) & strcmp({R.problem},problems{pi}));
 [ids,ix,iy]=intersect([x.run],[y.run]);
 if isempty(ids),continue;end
 x=x(ix);y=y(iy);match=true;
 for j=1:numel(ids)
  a=load(x(j).file,'result','metadata');b=load(y(j).file,'result','metadata');
  match=match && x(j).seed==y(j).seed && x(j).modeRunId==y(j).modeRunId ...
   && isequal(a.result{1,2}.decs,b.result{1,2}.decs) && isequal(a.result{1,2}.objs,b.result{1,2}.objs);
 end
 assert(match,'Seed or initial population mismatch');
 xv=[x.IGD];yv=[y.IGD];
 p=struct('problem',problems{pi},'nPairs',numel(ids),'runIds',ids,'matchedInitialPopulation',match,'meanQ080',mean(xv),'meanQ070',mean(yv),'relativePercent',100*(mean(xv)/mean(yv)-1),'pPaired',signrank(xv,yv,'method','exact'),'pHolm',NaN,'q080Better',sum(xv<yv),'q080Worse',sum(xv>yv));
 if isempty(P),P=p;else,P(end+1)=p;end %#ok<SAGROW>
end
if ~isempty(P)
 [ps,ord]=sort([P.pPaired]);pa=min(1,cummax(ps.*(numel(P):-1:1)));
 for j=1:numel(P),P(ord(j)).pHolm=pa(j);end
end
fid=fopen(fullfile(out,'analysis.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(struct('runs',R,'comparisons',S,'paired',P,'invalid',{bad})));fclose(fid);
writetable(struct2table(R),fullfile(out,'runs.csv'));
writetable(struct2table(S),fullfile(out,'comparisons.csv'));
disp(struct2table(S));disp(P);fprintf('VALID %d; INVALID %d\n',numel(R),numel(bad));
