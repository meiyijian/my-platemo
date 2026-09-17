function run_LTGGPPartition(part, nParts)
%RUN_LTGGPPARTITION Execute one disjoint slice of the formal LTGGP protocol.
%   The 150 formal jobs are interleaved (run-major, then problem, then M)
%   so the twelve partitions mix problems and objective counts, which
%   balances the wall time across workers. Results are written atomically
%   and valid existing files are skipped, so partitions are resumable.
%   Partition status is appended to results/logs/partition<N>_status.json
%   after every job for progress probing.
%
%   House maximum for this machine (Ryzen 7 8745HS, 16 logical cores):
%   12 MATLAB processes x maxNumCompThreads(1), the same configuration the
%   1200-run pMix sweep used with ~98% pool utilization. Do not mix thread
%   counts across runs of one comparison table.

    assert(nParts==12 && ismember(part,1:nParts));
    maxNumCompThreads(1);
    [info,cleanup]=LTGGPSetupPaths(); %#ok<ASGLU>
    root=fullfile(info.ExperimentDirectory,'results');
    config=LTGGPProtocol('formal');
    assert(numel(config.Jobs)==150,'LTGGP:ProtocolDrift', ...
        'Expected 150 formal jobs; the protocol changed.');
    jobs=config.Jobs; ordered=jobs([]);
    for r=1:25
        for p=["DTLZ2","DTLZ4","DTLZ5"]
            for M=[10,20]
                ordered(end+1)=jobs([jobs.Run]==r & [jobs.Problem]==p & [jobs.M]==M); %#ok<AGROW>
            end
        end
    end
    jobs=ordered(part:nParts:end);
    fprintf('PARTITION %d/%d: %d jobs; started %s\n',part,nParts,numel(jobs),char(datetime('now')));
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
        fid=fopen(fullfile(root,'logs',sprintf('partition%d_status.json',part)),'w');
        assert(fid>=0); fprintf(fid,'%s',jsonencode(status)); fclose(fid);
        fprintf('DONE %d/%d; recorded wall %.1f seconds\n',i,numel(jobs),wallTimes(end));
    end
    fid=fopen(fullfile(root,sprintf('PART%dof%d_COMPLETE.txt',part,nParts)),'w');
    assert(fid>=0); fprintf(fid,'%d validated jobs complete\n',numel(jobs)); fclose(fid);
end
