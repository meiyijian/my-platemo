function status = check_Stage2Progress(profile)
%check_Stage2Progress Report Stage-2 pipeline completion status.
%   status = check_Stage2Progress(profile) scans results/stage2/<profile>
%   for all expected jobs (from LabelValidationProtocol), validates any
%   existing MAT files and prints a compact progress report.
%
%   Optional: call with no argument to check all profiles.
%   Returns a struct with .expected, .completed, .invalid, .pending,
%   .allDone.

    if nargin < 1 || isempty(profile)
        profiles = {'smoke','pilot','screening'};
        for i = 1:numel(profiles)
            fprintf('===== profile: %s =====\n',profiles{i});
            check_Stage2Progress(profiles{i});
        end
        return;
    end

    expDir = fileparts(mfilename('fullpath'));
    resultRoot = fullfile(expDir,'results','stage2',profile);
    cfg = LabelValidationProtocol(profile);
    jobs = cfg.jobs;

    expected = numel(jobs);
    completed = 0; invalid = 0; pending = 0;
    invalidList = {};

    for i = 1:expected
        job = jobs(i);
        outFile = fullfile(resultRoot,job.behavior,job.problem, ...
            sprintf('M%d',job.M),sprintf('run_%03d.mat',job.run));
        if isfile(outFile)
            [ok,rep] = ValidateLabelCausalAblationFile(outFile,profile);
            if ok
                completed = completed + 1;
            else
                invalid = invalid + 1;
                invalidList{end+1} = sprintf('%s [%s]',outFile,rep.detail); %#ok<AGROW>
            end
        else
            pending = pending + 1;
        end
    end

    allDone = (completed == expected) && (invalid == 0);

    status = struct('profile',profile,'expected',expected, ...
        'completed',completed,'invalid',invalid,'pending',pending, ...
        'allDone',allDone,'invalidList',{invalidList});

    fprintf('Expected: %d | Completed(valid): %d | Invalid: %d | Pending: %d\n', ...
        expected,completed,invalid,pending);
    if ~isempty(invalidList)
        fprintf('INVALID jobs (%d):\n',numel(invalidList));
        for i = 1:numel(invalidList), fprintf('  %s\n',invalidList{i}); end
    end
    if allDone
        fprintf('>>> PROFILE %s: ALL %d JOBS DONE AND VALID <<<\n',profile,expected);
    end
end
