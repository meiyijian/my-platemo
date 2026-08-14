function status = check_Stage1Progress(profile)
%check_Stage1Progress Report Stage-1 pipeline completion status.
%   status = check_Stage1Progress(profile) scans results/stage1/<profile>
%   for all expected jobs (from LabelValidationProtocol), validates any
%   existing MAT files and prints a compact progress report.
%
%   Optional: call with no argument to check all profiles.
%   Returns a struct with .expected, .completed, .skipped, .failed,
%   .invalid, .pending, .allDone.

    if nargin < 1 || isempty(profile)
        profiles = {'smoke','pilot','screening'};
        for i = 1:numel(profiles)
            fprintf('===== profile: %s =====\n',profiles{i});
            check_Stage1Progress(profiles{i});
        end
        return;
    end

    expDir = fileparts(mfilename('fullpath'));
    resultRoot = fullfile(expDir,'results','stage1',profile);
    cfg = LabelValidationProtocol(profile);
    jobs = cfg.jobs;

    expected = numel(jobs);
    completed = 0; skipped = 0; failed = 0; invalid = 0; pending = 0;
    failedList = {};
    invalidList = {};

    for i = 1:expected
        job = jobs(i);
        outFile = fullfile(resultRoot,job.behavior,job.problem, ...
            sprintf('M%d',job.M),sprintf('run_%03d.mat',job.run));
        if isfile(outFile)
            [ok,rep] = ValidateLabelMechanismSnapshotFile(outFile,profile);
            if ok
                completed = completed + 1;
            else
                invalid = invalid + 1;
                invalidList{end+1} = sprintf('%s [%s]',outFile,rep.detail); %#ok<AGROW>
            end
        else
            % maybe a manifest knows the job status
            tmpFile = [outFile,'.tmp.mat'];
            if isfile(tmpFile)
                pending = pending + 1;
            else
                pending = pending + 1;
            end
        end
    end

    % manifest detail (if exists)
    manFile = fullfile(resultRoot,'analysis','Stage1_run_manifest.csv');
    if isfile(manFile)
        fprintf('Manifest: %s\n',manFile);
    end

    allDone = (completed == expected) && (failed == 0) && (invalid == 0);

    status = struct('profile',profile,'expected',expected, ...
        'completed',completed,'skipped',skipped,'failed',failed, ...
        'invalid',invalid,'pending',pending,'allDone',allDone, ...
        'failedList',{failedList},'invalidList',{invalidList});

    fprintf('Expected: %d | Completed(valid): %d | Invalid: %d | Pending: %d\n', ...
        expected,completed,invalid,pending);
    if ~isempty(failedList)
        fprintf('FAILED jobs (%d):\n',numel(failedList));
        for i = 1:numel(failedList), fprintf('  %s\n',failedList{i}); end
    end
    if ~isempty(invalidList)
        fprintf('INVALID jobs (%d):\n',numel(invalidList));
        for i = 1:numel(invalidList), fprintf('  %s\n',invalidList{i}); end
    end
    if allDone
        fprintf('>>> PROFILE %s: ALL %d JOBS DONE AND VALID <<<\n',profile,expected);
    end
end
