platform='D:/PlatEMO-master/PlatEMO-master/PlatEMO';
addpath(genpath(platform));
base='C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30';
out=fileparts(mfilename('fullpath'));
prefix='REMO_new2_AdaMaO_SDEOnly_UniformMix_';
algs={'REMO','PIEA','MCEAD','R2AEA','CSEA','PCSAEA_N100','KRVEA_100',[prefix,'Original'],[prefix,'Pruned_Weighted'],[prefix,'Pruned']};
labels={'REMO','PIEA','MCEAD','R2AEA','CSEA','PCSAEA_N100','KRVEA_100','Original','Weighted','Pruned'};
problems=[arrayfun(@(i)sprintf('DTLZ%d',i),1:7,'UniformOutput',false),arrayfun(@(i)sprintf('WFG%d',i),1:9,'UniformOutput',false)];
R=struct([]); k=0;
for ai=1:numel(algs)
 for pi=1:numel(problems)
  fs=dir(fullfile(base,algs{ai},sprintf('%s_%s_M10_D*_*.mat',algs{ai},problems{pi})));
  for fi=1:numel(fs)
   tok=regexp(fs(fi).name,'_M(\d+)_D(\d+)_(\d+)\.mat$','tokens','once');
   runId=str2double(tok{3}); if runId>18,continue;end
   d=load(fullfile(fs(fi).folder,fs(fi).name),'metric','result');
   r=struct('algorithm',labels{ai},'problem',problems{pi},'D',str2double(tok{2}),'run',runId,'FE',d.result{end,1},'firstFE',d.result{1,1},'nFinal',length(d.result{end,2}),'IGD',NaN,'HV',NaN,'runtime',NaN,'trajectoryFE',[d.result{:,1}],'trajectoryIGD',[],'file',fullfile(fs(fi).folder,fs(fi).name));
   if isfield(d.metric,'IGD'),r.IGD=d.metric.IGD(end);r.trajectoryIGD=d.metric.IGD;end
   if isfield(d.metric,'HV'),r.HV=d.metric.HV(end);end
   if isfield(d.metric,'runtime'),r.runtime=d.metric.runtime;end
   k=k+1;if k==1,R=r;else,R(k)=r;end
  end
 end
 fprintf('Loaded %s: %d runs\n',labels{ai},sum(strcmp({R.algorithm},labels{ai})));
end
fid=fopen(fullfile(out,'runs.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(R));fclose(fid);
T=struct2table(rmfield(R,{'trajectoryFE','trajectoryIGD'}));writetable(T,fullfile(out,'run_metrics.csv'));
S=struct([]);k=0;rng(20260912,'twister');
for target={'Weighted','Original'}
 for ai=1:numel(labels)
  if strcmp(labels{ai},target{1}),continue;end
  for pi=1:numel(problems)
   x=[R(strcmp({R.algorithm},target{1}) & strcmp({R.problem},problems{pi})).IGD];
   y=[R(strcmp({R.algorithm},labels{ai}) & strcmp({R.problem},problems{pi})).IGD];
   if isempty(x)||isempty(y),continue;end
   s=struct('target',target{1},'comparator',labels{ai},'problem',problems{pi},'nx',numel(x),'ny',numel(y),'meanTarget',mean(x),'sdTarget',std(x),'meanComparator',mean(y),'sdComparator',std(y),'relativePercent',100*(mean(x)/mean(y)-1),'pDefault',ranksum(x,y),'pExact',ranksum(x,y,'method','exact'),'pHolm',NaN,'delta',mean(sign(y(:)'-x(:)),'all'),'ciLow',NaN,'ciHigh',NaN);
   if strcmp(target{1},'Weighted') && strcmp(labels{ai},'Original')
    bx=mean(x(randi(numel(x),numel(x),10000)),1);by=mean(y(randi(numel(y),numel(y),10000)),1);
    ci=prctile(100*(bx./by-1),[2.5,97.5]);s.ciLow=ci(1);s.ciHigh=ci(2);
   end
   k=k+1;if k==1,S=s;else,S(k)=s;end
  end
  ids=find(strcmp({S.target},target{1}) & strcmp({S.comparator},labels{ai}));
  [ps,ord]=sort([S(ids).pExact]);pa=min(1,cummax(ps.*(numel(ids):-1:1)));
  for j=1:numel(ids),S(ids(ord(j))).pHolm=pa(j);end
 end
end
writetable(struct2table(S),fullfile(out,'comparisons.csv'));
fid=fopen(fullfile(out,'comparisons.json'),'w');fprintf(fid,'%s',jsonencode(S));fclose(fid);
settings=load(fullfile(base,'总实验8.26.mat'));
fid=fopen(fullfile(out,'settings.json'),'w','n','UTF-8');fprintf(fid,'%s',jsonencode(settings));fclose(fid);
disp(struct2table(S(strcmp({S.target},'Weighted') & strcmp({S.comparator},'Original'))));
fprintf('DONE %d run records, %d contrasts\n',numel(R),numel(S));
