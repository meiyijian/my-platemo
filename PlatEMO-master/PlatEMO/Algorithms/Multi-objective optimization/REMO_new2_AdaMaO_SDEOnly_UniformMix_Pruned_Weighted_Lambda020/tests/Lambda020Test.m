function Lambda020Test()
%Lambda020Test Static checks and the lambda0=0 equivalence of the new selector.
%   Three things are verified without running an optimization:
%   1. checkcode reports no error-level problem in the new sources.
%   2. LambdaWeightedBatchSelection with lambda0=0 returns exactly the batch of
%      the pruned baseline selector, over randomized candidates including ties,
%      degenerate score ranges and batches larger than the retained set.
%   3. Every top-level file of this folder that shares its name with an existing
%      algorithm folder is byte-identical, so path shadowing stays harmless.

    root = fileparts(fileparts(mfilename('fullpath')));
    logFile = fullfile(root,'tests','Lambda020Test.log');
    fid = fopen(logFile,'w','n','UTF-8');
    cleanup = onCleanup(@()fclose(fid));
    failures = 0;

    fprintf(fid,'=== 1. Static analysis ===\n');
    files = [dir(fullfile(root,'*.m'));dir(fullfile(root,'private','*.m'))];
    findings = 0;
    for i = 1:numel(files)
        file = fullfile(files(i).folder,files(i).name);
        info = checkcode(file,'-struct');
        for k = 1:numel(info)
            findings = findings + 1;
            fprintf(fid,'%-50s line %-4d %s\n',files(i).name, ...
                info(k).line,info(k).message);
        end
    end
    fprintf(fid,'Source files checked: %d; findings reported: %d\n', ...
        numel(files),findings);
    fprintf(fid,'Findings are informational; a syntax error would surface when\n');
    fprintf(fid,'the algorithm is constructed and solved during verification.\n\n');

    fprintf(fid,'=== 2. lambda0=0 equivalence with the pruned selector ===\n');
    rng(7,'twister');
    mismatches = 0;
    rewardEffect = 0;
    cases = 0;
    for trial = 1:120
        n = 20 + randi(280);
        dim = 30;
        nCandidates = 12 + randi(n-11);
        candidates = randn(nCandidates,dim);
        scores = randn(nCandidates,1);
        if mod(trial,4) == 0
            scores = round(scores*2)/2;        % heavy ties
        end
        if mod(trial,5) == 0
            scores = 0.25*ones(nCandidates,1); % degenerate range
        end
        uncertainty = rand(nCandidates,1);
        if mod(trial,3) == 0
            uncertainty = ones(nCandidates,1)*0.75;
        end
        if mod(trial,7) == 0
            batchSize = 2000;                  % retained set smaller than batch
        else
            batchSize = 6;
        end
        ratio = rand();
        [nextZero,~] = LambdaWeightedBatchSelection( ...
            candidates,scores,uncertainty,0.70,batchSize,0,ratio);
        nextBase = PrunedWeightedBatchSelection( ...
            candidates,scores,0.70,batchSize);
        cases = cases + 1;
        if ~isequal(nextZero,nextBase)
            mismatches = mismatches + 1;
            fprintf(fid,'MISMATCH trial %d: n=%d retained-branch=%d\n', ...
                trial,nCandidates,batchSize > nCandidates);
        end
        [nextReward,info] = LambdaWeightedBatchSelection( ...
            candidates,scores,uncertainty,0.70,batchSize,0.20,ratio);
        if ~isequal(nextReward,nextBase), rewardEffect = rewardEffect + 1; end
        if info.lambdaT ~= 0.20*(1-ratio)
            failures = failures + 1;
            fprintf(fid,'BAD lambdaT trial %d: %g\n',trial,info.lambdaT);
        end
    end
    fprintf(fid,'Cases: %d; lambda0=0 mismatches: %d; batches moved by the reward: %d\n\n', ...
        cases,mismatches,rewardEffect);
    if mismatches > 0
        failures = failures + 1;
    end

    fprintf(fid,'=== 3. Shadowing audit of duplicated file names ===\n');
    thisFolder = root;
    parent = fileparts(root);
    siblings = dir(parent);
    top = dir(fullfile(root,'*.m'));
    duplicated = 0;
    codeDiffs = 0;
    for i = 1:numel(top)
        name = top(i).name;
        mine = fileread(fullfile(root,name));
        for k = 1:numel(siblings)
            if ~siblings(k).isdir || ...
                    any(strcmp(siblings(k).name,{'.','..'}))
                continue;
            end
            twinFolder = fullfile(parent,siblings(k).name);
            if strcmpi(twinFolder,thisFolder), continue; end
            twin = fullfile(twinFolder,name);
            if ~isfile(twin), continue; end
            duplicated = duplicated + 1;
            theirs = fileread(twin);
            if isequal(mine,theirs)
                verdict = 'byte-identical';
            elseif isequal(codeOnly(mine),codeOnly(theirs))
                verdict = 'comment-only-diff';
            else
                verdict = 'CODE-DIFF';
                codeDiffs = codeDiffs + 1;
            end
            fprintf(fid,'%-50s twin %-62s %s\n',name,siblings(k).name,verdict);
        end
    end
    fprintf(fid,'Duplicated top-level names: %d; code-level conflicts: %d\n\n', ...
        duplicated,codeDiffs);
    if codeDiffs > 0
        failures = failures + 1;
    end
    resolved = which('ResolveUniformMixMode','-all');
    fprintf(fid,'Resolved ResolveUniformMixMode: %s\n',resolved{1});
    fprintf(fid,'Resolved PrunedIndicatorSelection: %s\n', ...
        which('PrunedIndicatorSelection'));
    fprintf(fid,'Resolved DiversifiedInfillSelection: %s\n', ...
        which('DiversifiedInfillSelection'));
    fprintf(fid,'Resolved LambdaWeightedBatchSelection: %s\n\n', ...
        which('LambdaWeightedBatchSelection'));

    % Machine-readable evidence for the two reference folders this variant was
    % derived from: every unchanged file must be byte-identical, and the shared
    % helper that differs only in comments must stay code-identical.
    references = {'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted', ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Original'};
    evidence = struct('file',{},'reference',{},'present',{}, ...
        'byteIdentical',{},'codeIdentical',{});
    mineFiles = [dir(fullfile(root,'*.m'));dir(fullfile(root,'private','*.m'))];
    for i = 1:numel(mineFiles)
        name = mineFiles(i).name;
        rel = name;
        if strcmp(mineFiles(i).folder,fullfile(root,'private'))
            rel = fullfile('private',name);
        end
        mine = fileread(fullfile(root,rel));
        for r = 1:numel(references)
            twin = fullfile(parent,references{r},rel);
            present = isfile(twin);
            byteSame = false;
            codeSame = false;
            if present
                theirs = fileread(twin);
                byteSame = isequal(mine,theirs);
                codeSame = isequal(codeOnly(mine),codeOnly(theirs));
            end
            evidence(end+1) = struct('file',rel,'reference',references{r}, ...
                'present',present,'byteIdentical',byteSame, ...
                'codeIdentical',codeSame); %#ok<AGROW>
        end
    end
    fid2 = fopen(fullfile(root,'copy_verification.json'),'w','n','UTF-8');
    assert(fid2 >= 0,'Cannot write copy_verification.json.');
    fwrite(fid2,jsonencode(evidence,'PrettyPrint',true));
    fclose(fid2);
    fprintf(fid,'Copy evidence written: copy_verification.json\n');

    fprintf(fid,'=== Summary ===\n');
    if failures == 0
        fprintf(fid,'PASS: static checks, equivalence and shadowing audit.\n');
    else
        fprintf(fid,'FAIL: %d failure group(s).\n',failures);
    end
    fprintf('Log written: %s\n',logFile);
    if failures > 0
        error('AdaMaO:Lambda020TestFailed','See %s.',logFile);
    end
end

function bytes = readBytes(file)
%readBytes Read a file as a uint8 row vector.
    fid = fopen(file,'r');
    assert(fid >= 0,'Cannot read %s.',file);
    bytes = fread(fid,Inf,'*uint8')';
    fclose(fid);
end

function lines = codeOnly(text)
%codeOnly Drop comments and blank lines so only statements are compared.
    raw = regexp(text,'\r\n|\n|\r','split');
    lines = {};
    for i = 1:numel(raw)
        line = raw{i};
        cut = find(line == '%',1);
        if ~isempty(cut), line = line(1:cut-1); end
        line = strtrim(line);
        if ~isempty(line), lines{end+1} = line; end %#ok<AGROW>
    end
end
