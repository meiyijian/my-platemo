function finish_LTGGP()
%FINISH_LTGGP Validate all formal results, then run the frozen analysis.
%   Writes results/FORMAL_COMPLETE.txt only after every one of the 150
%   results passes LTGGPValidateRunFile with matching identity fields and
%   the analysis reports 6/6 complete configurations.

    [info,cleanup]=LTGGPSetupPaths(); %#ok<ASGLU>
    config=LTGGPProtocol('formal'); assert(numel(config.Jobs)==150);
    resultRoot=fullfile(info.ExperimentDirectory,'results');
    for jobIndex=1:numel(config.Jobs)
        job=config.Jobs(jobIndex);
        file=LTGGPResultPath(resultRoot,'formal',job);
        [ok,report]=LTGGPValidateRunFile(file,'formal');
        assert(ok,'LTGGP:InvalidResult','%s: %s',file,report.Detail);
        data=load(file,'metadata');
        assert(data.metadata.Seed==job.Seed && data.metadata.Run==job.Run && ...
            data.metadata.M==job.M && string(data.metadata.Problem)==job.Problem);
    end
    outputs=analyze_Lambdat030GoodGroupPrecision('formal');
    assert(height(outputs.Coverage)==6 && all(outputs.Coverage.Complete));
    fid=fopen(fullfile(resultRoot,'FORMAL_COMPLETE.txt'),'w');
    assert(fid>=0); fprintf(fid,'150/150 validated; 6/6 configurations complete; analysis saved\n'); fclose(fid);
end
