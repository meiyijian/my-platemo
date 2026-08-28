function GGP_WriteRuns(rows,Algorithm,Problem)
% GGP_WriteRuns - Append this run's checkpoint rows to a per-config CSV.
%
% One CSV per (problem, M), with every run appended to it. Writing one file
% per run would leave the analysis script globbing hundreds of files; writing
% one global file would make parallel runs on different problems collide.
%
% Layout:
%   Experiments/REMO_new2_AdaMaO_GoodGroupPrecision/results/
%       raw/GGP_<Problem>_M<M>.csv
%
% Each row is one scored (or unscored) checkpoint. The analysis script
% aggregates across runs; nothing is aggregated here, so a crashed run still
% leaves its completed checkpoints on disk and usable.

    if isempty(rows)
        return;
    end

    here    = fileparts(fileparts(mfilename('fullpath')));
    rawDir  = fullfile(here,'results','raw');
    if ~exist(rawDir,'dir')
        [ok,msg] = mkdir(rawDir);
        if ~ok
            warning('GGP:MkdirFailed','Could not create %s: %s',rawDir,msg);
            return;
        end
    end

    runId = Algorithm.run;
    if isempty(runId)
        runId = 0;
    end

    csvPath = fullfile(rawDir,sprintf('GGP_%s_M%d.csv', ...
        class(Problem),Problem.M));

    header = {'problem','M','D','run','iter','scoreIter','FE','ratio', ...
        'N','kTop','scored', ...
        'chance_retained','chance_front','chance_igdgain', ...
        'prec_v_retained','prec_anchor_retained','prec_hybrid_retained', ...
        'prec_v_front','prec_anchor_front','prec_hybrid_front', ...
        'prec_v_igdgain','prec_anchor_igdgain','prec_hybrid_igdgain'};

    needHeader = exist(csvPath,'file') ~= 2;

    fid = fopen(csvPath,'a');
    if fid < 0
        warning('GGP:FopenFailed','Could not open %s for append.',csvPath);
        return;
    end

    if needHeader
        fprintf(fid,'%s\n',strjoin(header,','));
    end

    for i = 1 : numel(rows)
        r = rows(i);
        fprintf(fid,'%s,%d,%d,%d,%d,%d,%d,%.6f,%d,%d,%d', ...
            class(Problem),Problem.M,Problem.D,runId, ...
            r.iter,r.scoreIter,r.FE,r.ratio,r.N,r.kTop,double(r.scored));
        fprintf(fid,',%s,%s,%s', ...
            GGP_Num(r.chance_retained),GGP_Num(r.chance_front), ...
            GGP_Num(r.chance_igdgain));
        fprintf(fid,',%s,%s,%s', ...
            GGP_Num(r.prec_v_retained),GGP_Num(r.prec_anchor_retained), ...
            GGP_Num(r.prec_hybrid_retained));
        fprintf(fid,',%s,%s,%s', ...
            GGP_Num(r.prec_v_front),GGP_Num(r.prec_anchor_front), ...
            GGP_Num(r.prec_hybrid_front));
        fprintf(fid,',%s,%s,%s\n', ...
            GGP_Num(r.prec_v_igdgain),GGP_Num(r.prec_anchor_igdgain), ...
            GGP_Num(r.prec_hybrid_igdgain));
    end

    fclose(fid);
end

function s = GGP_Num(x)
% NaN must reach the CSV as an empty field, not the literal "NaN": readtable
% turns an empty numeric field into NaN, whereas "NaN" in an otherwise
% numeric column can silently coerce the whole column to text.

    if isempty(x) || ~isfinite(x)
        s = '';
    else
        s = sprintf('%.6f',x);
    end
end
