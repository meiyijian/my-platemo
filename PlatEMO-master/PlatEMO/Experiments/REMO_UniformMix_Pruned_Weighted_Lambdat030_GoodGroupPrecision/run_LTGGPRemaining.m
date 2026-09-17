function run_LTGGPRemaining(part, nParts)
%RUN_LTGGPREMAINING Execute one disjoint slice of the REMAINING formal jobs.
%   Re-partitions only the jobs whose validated result file is still
%   missing, run-major interleaved, so crashed/fresh slices can be
%   relaunched at full house parallelism (12 workers) without redoing
%   completed runs. Same invariants as run_LTGGPPartition: atomic writes,
%   valid existing files are skipped, status json after every job.
%
%   The 2026-09-16 formal run lost five workers to a simultaneous
%   cold-start memory spike; relaunches must therefore be STAGGERED by the
%   caller (Start-Sleep between MATLAB launches), never started at once.

    assert(ismember(nParts,[1 12]) && ismember(part,1:nParts));
    maxNumCompThreads(1);
    [info,cleanup]=LTGGPSetupPaths(); %#ok<ASGLU>
    root=fullfile(info.ExperimentDirectory,'results');
    config=LTGGPProtocol('formal');
    assert(numel(config.Jobs)==150,'LTGGP:ProtocolDrift', ...
        'Expected 150 formal jobs; the protocol changed.');
    jobs=config.Jobs; remaining=jobs([]);
    for r=1:25
        for p=["DTLZ2","DTLZ4","DTLZ5"]
            for M=[10,20]
                job=jobs([jobs.Run]==r & [jobs.Problem]==p & [jobs.M]==M);
                if ~isfile(LTGGPResultPath(root,'formal',job))
                    remaining(end+1)=job; %#ok<AGROW>
                end
            end
        end
    end
    jobs=remaining(part:nParts:end);
    fprintf('REMAINING PARTITION %d/%d: %d jobs; started %s\n',part,nParts,numel(jobs),char(datetime('now')));
    if isempty(jobs)
        writeRemainingMarker(root,part,nParts,0);
        return;
    end
    wallTimes=[];
    for i=1:numel(jobs)
        job=jobs(i);
        fprintf('START %s M%d run%03d at %s\n',job.Problem,job.M,job.Run,char(datetime('now')));
        run_Lambdat030GoodGroupPrecision('formal','Problems',job.Problem,'Ms',job.M,'Runs',job.Run);
        data=load(LTGGPResultPath(root,'formal',job),'validation','metadata');
        wallTimes(end+1)=data.validation.WallTime; %#ok<AGROW>
        status=struct('Partition',part,'Partitions',nParts,'Completed',i,'Total',numel(jobs), ...
            'Problem',job.Problem,'M',job.M,'Run',job.Run, ...
            'LastWallSeconds',wallTimes(end),'MeanWallSeconds',mean(wallTimes), ...
            'UpdatedAt',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        fid=fopen(fullfile(root,'logs',sprintf('remaining_p%d_status.json',part)),'w');
        assert(fid>=0); fprintf(fid,'%s',jsonencode(status)); fclose(fid);
        fprintf('DONE %d/%d; recorded wall %.1f seconds\n',i,numel(jobs),wallTimes(end));
    end
    writeRemainingMarker(root,part,nParts,numel(jobs));
end

function writeRemainingMarker(root,part,nParts,jobCount)
    fid=fopen(fullfile(root,sprintf('REMAINING_P%dof%d_COMPLETE.txt',part,nParts)),'w');
    assert(fid>=0); fprintf(fid,'%d remaining jobs complete\n',jobCount); fclose(fid);
end
