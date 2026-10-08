function audit_ggp()
% Reconstruct both GGP outcomes from saved formal trajectories; no FE calls.
    here = fileparts(mfilename('fullpath'));
    root = fileparts(fileparts(fileparts(here)));
    experiment = fullfile(root,'PlatEMO-master','PlatEMO','Experiments', ...
        'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist_GoodGroupPrecision');
    addpath(experiment);
    cleanup = onCleanup(@() rmpath(experiment)); %#ok<NASGU>
    config = NBGGPProtocol('formal');
    rows = cell(5440,19);
    row = 0;
    for j = 1:numel(config.Jobs)
        job = config.Jobs(j);
        file = NBGGPResultPath(fullfile(experiment,'results'),'formal',job);
        data = load(file,'metadata','auditData');
        meta = data.metadata;
        audit = data.auditData;
        assert(meta.CompletedFE==300 && meta.InitialFE==100 && meta.ActualD==30);
        assert(meta.M==job.M && meta.Run==job.Run && meta.Seed==job.Seed);
        assert(meta.Gmax==3000 && meta.PMix==0.5 && meta.RGood==0.25);
        assert(meta.QKeep==0.70 && meta.NMax==6 && meta.LambdaT==0.30);
        assert(string(meta.FrozenAlgorithmClass)== ...
            "REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist");
        assert(numel(audit.snapshots)==34 && numel(audit.trajectory)==34);
        assert(isequal(audit.evaluations.EvalID(:),(1:300)'));
        assert(size(audit.evaluations.Decision,1)==300);
        finalIDs = audit.trajectory(end).PopulationEvalIDAfter(:);
        assert(numel(unique(finalIDs))==100);
        for k = 1:34
            s = audit.snapshots(k);
            assert(s.FE==100+6*(k-1));
            assert(audit.trajectory(k).FEBefore==s.FE);
            assert(audit.trajectory(k).FEAfter==min(s.FE+6,300));
            assert(numel(audit.trajectory(k).SelectedEvalID)==min(6,300-s.FE));
            assert(size(s.PopulationDec,1)==100 && size(s.PopulationDec,2)==30);
            ids = s.PopulationEvalID(:);
            assert(numel(unique(ids))==100 && all(ids<=s.FE));
            assert(isequal(s.PopulationDec,audit.evaluations.Decision(ids,:)));
            assert(isequal(s.PopulationObj,audit.evaluations.Objective(ids,:)));
            h = logical(s.CatalogCurrent(:));
            v = top25(s.ScoreV);
            a = top25(s.AnchorMargin);
            l = logical(s.LabelDyn(:));
            assert(isequal(h,top25(s.ScoreHybrid)) && nnz(h)==25);
            assert(max(abs(s.ScoreHybrid(:)- ...
                ((1-s.Ratio)*s.ScoreV(:)+s.Ratio*double(l))))<1e-12);
            if string(job.Problem)=="DTLZ7"
                g = 1+9*mean(s.PopulationDec(:,job.M:end),2);
            else
                g = sum((s.PopulationDec(:,job.M:end)-0.5).^2,2);
            end
            [gSorted, order] = sortrows([g,(1:100)']);
            assert(gSorted(25,1)~=gSorted(26,1));
            current = false(100,1); current(order(1:25))=true;
            retained = ismember(ids,finalIDs);
            views = [h,v,a,l];
            currentPrecision = sum(views & current,1)./sum(views,1);
            retentionPrecision = sum(views & retained,1)./sum(views,1);
            row = row+1;
            rows(row,:) = {string(job.Problem),job.M,job.Run,job.Seed,k,s.FE, ...
                string(NBGGPStageBin(s.Ratio)), ...
                currentPrecision(1),currentPrecision(2),currentPrecision(3),currentPrecision(4), ...
                retentionPrecision(1),retentionPrecision(2),retentionPrecision(3),retentionPrecision(4), ...
                mean(retained),nnz(l),nnz(h & ~l),nnz(h & ~v)};
        end
    end
    assert(row==5440);
    T = cell2table(rows,'VariableNames',{'Problem','M','Run','Seed','SnapshotID','FE','Stage', ...
        'CurrentPAQC','CurrentDirection','CurrentAnchor','CurrentNative', ...
        'RetentionPAQC','RetentionDirection','RetentionAnchor','RetentionNative', ...
        'Chance','NativeCount','PAQCOutsideNative','SwapsVsDirection'});
    writetable(T,fullfile(here,'checkpoints.csv'));
    [groups,problem,m,run] = findgroups(T.Problem,T.M,T.Run);
    R = table(problem,m,run,'VariableNames',{'Problem','M','Run'});
    vars = T.Properties.VariableNames(8:end);
    for v = 1:numel(vars)
        R.(vars{v}) = splitapply(@mean,T.(vars{v}),groups);
    end
    writetable(R,fullfile(here,'per_run.csv'));
    configurations = unique(R(:,{'Problem','M'}),'rows');
    comparisons = cell(32,11); c = 0;
    for z = 1:height(configurations)
        s = R(R.Problem==configurations.Problem(z) & R.M==configurations.M(z),:);
        assert(height(s)==20 && isequal(sort(s.Run),(1:20)'));
        for outcome = ["Retention","Current"]
            for control = ["Direction","Anchor"]
                x = s.(outcome+"PAQC"); y = s.(outcome+control);
                % All equal-quota run means have denominator 25*34=850.
                % Use integer hit differences to preserve mathematical ties.
                xHits = round(x*850); yHits = round(y*850);
                assert(max(abs(x*850-xHits))<1e-9 && max(abs(y*850-yHits))<1e-9);
                dHits = xHits-yHits;
                d = dHits/850; c = c+1;
                comparisons(c,:) = {configurations.Problem(z),configurations.M(z), ...
                    outcome,control,mean(x),mean(y),mean(d), ...
                    nnz(dHits>0),nnz(dHits==0),nnz(dHits<0),signrank(dHits,0)};
            end
        end
    end
    C = cell2table(comparisons,'VariableNames',{'Problem','M','Outcome','Control', ...
        'PAQCMean','ControlMean','Delta','Wins','Ties','Losses','PRaw'});
    C.PHolm = NBGGPHolmAdjust(C.PRaw);
    writetable(C,fullfile(here,'comparisons.csv'));
    fprintf('GGP_RAW_AUDIT_PASS: 160 runs, 5440 checkpoints, actual FE=300, no added evaluations.\n');
    disp(C);
end

function selected = top25(score)
    assert(all(isfinite(score)));
    [~,order] = sortrows([-score(:),(1:100)']);
    selected = false(100,1); selected(order(1:25))=true;
end
