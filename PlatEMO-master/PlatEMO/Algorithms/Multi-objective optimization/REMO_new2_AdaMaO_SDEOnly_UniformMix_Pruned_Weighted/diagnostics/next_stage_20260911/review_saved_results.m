platform='D:/PlatEMO-master/PlatEMO-master/PlatEMO';
addpath(genpath(platform));
b='C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30';
out=fileparts(mfilename('fullpath'));
problems={'DTLZ2','DTLZ5','DTLZ7','WFG4','WFG7','WFG9'};
variants={'Original','Pruned','Pruned_Weighted'};
R=struct([]);k=0;
for ip=1:numel(problems)
 for iv=1:numel(variants)
  alg=['REMO_new2_AdaMaO_SDEOnly_UniformMix_',variants{iv}];
  for runId=1:9
   file=fullfile(b,alg,sprintf('%s_%s_M10_D30_%d.mat',alg,problems{ip},runId));
   d=load(file,'result','metric');pop=d.result{end,2};
   r.variant=variants{iv};r.problem=problems{ip};r.run=runId;
   r.FE=d.result{end,1};r.nrows=length(pop);r.IGD=d.metric.IGD(end);
   r.HV=NaN;if isfield(d.metric,'HV'),r.HV=d.metric.HV(end);end;r.runtime=d.metric.runtime;
   k=k+1;if k==1,R=r;else,R(k)=r;end
  end
 end
end
S=struct([]);k=0;
for iv=1:2
 for ip=1:numel(problems)
  a=[R(strcmp({R.variant},'Pruned_Weighted') & strcmp({R.problem},problems{ip})).IGD];
  c=[R(strcmp({R.variant},variants{iv}) & strcmp({R.problem},problems{ip})).IGD];
  s.problem=problems{ip};s.comparator=variants{iv};s.meanWeighted=mean(a);s.sdWeighted=std(a);
  s.meanComparator=mean(c);s.relativePercent=100*(mean(a)/mean(c)-1);
  s.pExact=ranksum(a,c,'method','exact');s.pHolm=NaN;
  k=k+1;if k==1,S=s;else,S(k)=s;end
 end
 ids=find(strcmp({S.comparator},variants{iv}));[ps,ord]=sort([S(ids).pExact]);
 pa=min(1,cummax(ps.*(6:-1:1)));for j=1:6,S(ids(ord(j))).pHolm=pa(j);end
end
Settings=load(fullfile(b,'简化参数的四个退化问题实验.mat'));
fid=fopen(fullfile(out,'review.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(struct('runs',R,'comparisons',S,'settings',Settings)));fclose(fid);
disp(struct2table(S));fprintf('FE values: %s; run records %d\n',mat2str(unique([R.FE])),numel(R));
