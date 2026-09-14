function check_control_metadata()
%check_control_metadata Verify the reusable M=10 control runs of the baseline.
%   The baseline folder keeps run IDs 1-18 from a legacy harness whose seeds
%   cannot be reconstructed, and run IDs 19-30 produced with the paper harness
%   seed formula 20260912 + M*1e5 + pi*1e3 + runId. Only the second group may
%   serve as a seed-matched control. This script checks every field needed to
%   accept a control file and writes the verdict to a text log.

    controlAlg = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted';
    dataRoot = 'C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30';
    folder = fullfile(dataRoot,controlAlg);
    specs = {'DTLZ2',2;'DTLZ4',4;'DTLZ5',5;'DTLZ7',7};
    runIds = 19:28;
    logFile = fullfile(fileparts(mfilename('fullpath')),'control_metadata_check.txt');
    fid = fopen(logFile,'w','n','UTF-8');
    cleanup = onCleanup(@()fclose(fid));
    fprintf(fid,'Control algorithm: %s\n',controlAlg);
    fprintf(fid,'Control folder: %s\n',folder);
    fprintf(fid,'Run IDs: %d..%d\n\n',runIds(1),runIds(end));
    fprintf(fid,'%-6s %-3s %-4s %-10s %-3s %-4s %-4s %-4s %-6s %-6s %-7s %s\n', ...
        'prob','pi','run','seed','M','D','N','FE','modeId','IGDok','save','verdict');
    allOk = true;
    accepted = 0;
    for s = 1:size(specs,1)
        problem = specs{s,1};
        pi_ = specs{s,2};
        for ri = runIds
            expected = 20260912 + 10*100000 + pi_*1000 + ri;
            file = fullfile(folder,sprintf('%s_%s_M10_D30_%d.mat',controlAlg,problem,ri));
            verdict = 'ACCEPT';
            if ~isfile(file)
                fprintf(fid,'%-6s %-3d %-4d %-10d MISSING FILE\n',problem,pi_,ri,expected);
                allOk = false;
                continue;
            end
            S = load(file,'metadata','result','metric');
            md = S.metadata;
            ok = true;
            ok = ok && strcmp(md.algorithm,controlAlg);
            ok = ok && md.seed == expected;
            ok = ok && isequal(md.parameters,{3000,0.50,0.25,0.70,6});
            ok = ok && md.N == 100 && md.M == 10 && md.D == 30;
            ok = ok && md.maxFE == 300 && md.actualFE == 300;
            ok = ok && md.modeRunId == 1;
            ok = ok && S.result{end,1} == 300;
            igdOk = isfield(S.metric,'IGD') && isfinite(S.metric.IGD(end));
            ok = ok && igdOk;
            if ~ok
                verdict = 'REJECT';
                allOk = false;
            else
                accepted = accepted + 1;
            end
            fprintf(fid,'%-6s %-3d %-4d %-10d %-3d %-4d %-4d %-4d %-6d %-6d %-7d %s\n', ...
                problem,pi_,ri,md.seed,md.M,md.D,md.N,md.actualFE, ...
                md.modeRunId,igdOk,md.save,verdict);
        end
    end
    fprintf(fid,'\nAccepted seed-matched control files: %d of %d\n', ...
        accepted,numel(runIds)*size(specs,1));
    if allOk
        fprintf(fid,'VERDICT: PASS - existing runs 19..28 are reusable controls.\n');
    else
        fprintf(fid,'VERDICT: FAIL - at least one control must be rerun.\n');
    end
    fprintf('Written: %s\n',logFile);
    if ~allOk
        error('AdaMaO:ControlNotVerified','Some control files failed verification.');
    end
end
