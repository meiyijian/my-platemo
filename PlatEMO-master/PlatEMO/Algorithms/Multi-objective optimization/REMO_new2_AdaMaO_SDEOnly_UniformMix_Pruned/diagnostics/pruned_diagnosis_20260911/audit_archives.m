% Read saved archives only. No optimization or Problem.Evaluation calls.
platform = 'D:/PlatEMO-master/PlatEMO-master/PlatEMO';
addpath(genpath(platform));
base = 'C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30';
out = 'D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned/diagnostics/pruned_diagnosis_20260911';
diary(fullfile(out,'archive_audit.log'));
variants = {'Original','Maximin','Pruned'};
problems = {'DTLZ2','DTLZ5','DTLZ7','WFG4','WFG7','WFG9'};
Records = struct([]);
Raw = struct([]);
n = 0;
for pi = 1:numel(problems)
    prob = problems{pi};
    problem = feval(prob,'M',10,'D',30,'N',100,'maxFE',300);
    for vi = 1:numel(variants)
        variant = variants{vi};
        alg = ['REMO_new2_AdaMaO_SDEOnly_UniformMix_',variant];
        files = dir(fullfile(base,alg,[alg,'_',prob,'_M10_D30_*.mat']));
        for fi = 1:numel(files)
            file = fullfile(files(fi).folder,files(fi).name);
            data = load(file);
            runTokens = regexp(files(fi).name,'_(\d+)\.mat$','tokens','once');
            runId = str2double(runTokens{1});
            population = data.result{end,2};
            x = population.decs; f = population.objs;
            n = n+1;
            r = struct('variant',variant,'problem',prob,'run',runId, ...
                'file',file,'FE',data.result{end,1}, ...
                'nrows',size(x,1),'snapshots',size(data.result,1), ...
                'FEhistory',cell2mat(data.result(:,1))', ...
                'savedIGD',NaN,'initialIGD',NaN,'uniqueX',size(unique(x,'rows'),1), ...
                'bestCount',length(population.best), ...
                'initialGMin',NaN,'initialGMedian',NaN, ...
                'newGMin',NaN,'newGMedian',NaN,'bestGMedian',NaN, ...
                'projectedIGD',NaN,'savedIGDRecomputed',NaN, ...
                'minGCurve',[],'igdCurve',[],'initialEqualToOriginal',false);
            if isfield(data.metric,'IGD'), r.savedIGD=data.metric.IGD(end); end
            if vi==1 && fi==1
                fprintf('%s metric fields: %s; result FE %s, rows %d\n', ...
                    prob,strjoin(fieldnames(data.metric),','),mat2str(r.FEhistory),r.nrows);
            end
            if startsWith(prob,'DTLZ') && size(x,1)==300
                r.initialIGD=IGD(population(1:100),problem.optimum);
                bestPopulation=population.best;
                bestX=bestPopulation.decs;
                if strcmp(prob,'DTLZ7')
                    g=1+9*mean(x(:,10:end),2);
                    bestG=1+9*mean(bestX(:,10:end),2);
                else
                    g=sum((x(:,10:end)-0.5).^2,2);
                    bestG=sum((bestX(:,10:end)-0.5).^2,2);
                end
                r.initialGMin=min(g(1:100));r.initialGMedian=median(g(1:100));
                r.newGMin=min(g(101:end));r.newGMedian=median(g(101:end));
                r.bestGMedian=median(bestG);
                checkpoints=[100,150,200,250,300];
                r.minGCurve=arrayfun(@(k)min(g(1:k)),checkpoints);
                r.igdCurve=arrayfun(@(k)IGD(population(1:k),problem.optimum),checkpoints);
                r.savedIGDRecomputed=r.igdCurve(end);
                xp=x;
                if strcmp(prob,'DTLZ7'), xp(:,10:end)=0;else,xp(:,10:end)=0.5;end
                fp=problem.CalObj(xp);
                if strcmp(prob,'DTLZ7')
                    fronts=NDSort(fp,1);fp=fp(fronts==1,:);
                end
                r.projectedIGD=mean(min(pdist2(problem.optimum,fp),[],2));
            end
            Raw(n).variant=variant;Raw(n).problem=prob;Raw(n).run=runId;
            Raw(n).X=x;Raw(n).F=f;
            if n==1
                Records=r;
            else
                Records(n)=orderfields(r,Records(1));
            end
        end
        fprintf('Loaded %s %s: %d runs\n',variant,prob,numel(files));
    end
end
for i=1:numel(Records)
    r=Records(i);
    match=find(strcmp({Records.variant},'Original') & ...
        strcmp({Records.problem},r.problem) & [Records.run]==r.run,1);
    if ~isempty(match) && size(Raw(i).X,1)>=100 && size(Raw(match).X,1)>=100
        Records(i).initialEqualToOriginal=isequal(Raw(i).X(1:100,:),Raw(match).X(1:100,:));
    end
end
save(fullfile(out,'numerical_archives.mat'),'Raw','-v7');
fid=fopen(fullfile(out,'archive_summary.json'),'w','n','UTF-8');
fprintf(fid,'%s',jsonencode(Records));fclose(fid);
fprintf('Exported %d run summaries.\n',numel(Records));
for pi=1:numel(problems)
    for vi=1:numel(variants)
        idx=strcmp({Records.problem},problems{pi}) & strcmp({Records.variant},variants{vi});
        values=[Records(idx).savedIGD];
        idx9=idx & [Records.run]<=9;v9=[Records(idx9).savedIGD];
        fprintf('%s %s n=%d mean=%.8g sd=%.8g first9=%.8g sd9=%.8g\n', ...
            problems{pi},variants{vi},numel(values),mean(values),std(values),mean(v9),std(v9));
    end
end
diary off;
