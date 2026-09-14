function check_source_hashes()
%check_source_hashes Compare the current baseline sources with the frozen hashes.
%   RunPaperWeighted30 writes a SHA-256 manifest of the algorithm sources at the
%   start of every session. If the baseline sources changed between sessions,
%   the stored control runs would not come from one single code revision. This
%   script prints, for the baseline and for the Lambda020 variant, which stored
%   manifests still agree with the files on disk.

    root = fileparts(fileparts(fileparts(mfilename('fullpath'))));
    platform = fileparts(fileparts(fileparts(root)));
    baselineFolder = fullfile(platform,'Algorithms','Multi-objective optimization', ...
        'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted');
    manifestFolder = fullfile(baselineFolder,'diagnostics','paper_30runs');
    baseline = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted';
    logFile = fullfile(root,'diagnostics','lambda020_10runs','source_hash_check.txt');
    fid = fopen(logFile,'w','n','UTF-8');
    cleanup = onCleanup(@()fclose(fid));

    files = listSources(root);
    fprintf(fid,'Current sources of this variant:\n');
    for i = 1:numel(files)
        fprintf(fid,'  %-52s %s\n',files(i).rel,sha256(files(i).file));
    end
    fprintf(fid,'\n');

    manifests = dir(fullfile(manifestFolder,'sources_*.mat'));
    fprintf(fid,'%-34s %-24s %-10s %-10s %s\n', ...
        'manifest','saved at','entries','mismatch','verdict');
    for i = 1:numel(manifests)
        file = fullfile(manifests(i).folder,manifests(i).name);
        S = load(file,'manifest');
        entries = S.manifest;
        entry = entries(strcmp({entries.algorithm},baseline));
        if isempty(entry)
            fprintf(fid,'%-34s %-24s %-10s %-10s %s\n', ...
                manifests(i).name,'-','0','-','NO BASELINE ENTRY');
            continue;
        end
        mismatch = 0;
        checked = 0;
        for k = 1:numel(entry)
            if ~isfile(entry(k).file)
                mismatch = mismatch + 1;
                continue;
            end
            checked = checked + 1;
            if ~strcmp(entry(k).sha256,sha256(entry(k).file))
                mismatch = mismatch + 1;
                fprintf(fid,'   CHANGED: %s\n',entry(k).file);
            end
        end
        if mismatch == 0
            verdict = 'MATCHES CURRENT SOURCES';
        else
            verdict = 'DIFFERS';
        end
        stamp = char(datetime(manifests(i).date,'Format','yyyy-MM-dd HH:mm:ss'));
        fprintf(fid,'%-34s %-24s %-10d %-10d %s\n', ...
            manifests(i).name,stamp,checked,mismatch,verdict);
    end
    fprintf(fid,'\nLog written for manual review.\n');
    fprintf('Log written: %s\n',logFile);
end

function files = listSources(root)
%listSources Top-level and private .m files of an algorithm folder.
    top = dir(fullfile(root,'*.m'));
    priv = dir(fullfile(root,'private','*.m'));
    files = struct('rel',{},'file',{});
    for i = 1:numel(top)
        files(end+1) = struct('rel',top(i).name, ...
            'file',fullfile(top(i).folder,top(i).name)); %#ok<AGROW>
    end
    for i = 1:numel(priv)
        files(end+1) = struct('rel',fullfile('private',priv(i).name), ...
            'file',fullfile(priv(i).folder,priv(i).name)); %#ok<AGROW>
    end
end

function h = sha256(file)
%sha256 Lower-case hexadecimal SHA-256 of a file.
    fid = fopen(file,'r');
    assert(fid >= 0,'Cannot read %s.',file);
    bytes = fread(fid,Inf,'*uint8');
    fclose(fid);
    md = java.security.MessageDigest.getInstance('SHA-256');
    digest = md.digest(bytes);
    h = lower(reshape(dec2hex(typecast(digest,'uint8'),2)',1,[]));
end
