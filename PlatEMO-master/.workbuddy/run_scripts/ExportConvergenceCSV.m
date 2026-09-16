function ExportConvergenceCSV()
%ExportConvergenceCSV Export IGD trajectories for the paper Section 4.7.
%   Reads the saved PlatEMO result files of the six baseline algorithms and
%   PACDIS (REMO_UniformMix_Pruned_Weighted_Lambdat030) on the selected WFG
%   problems at M = 10, 15 and 20, and writes:
%     1) a long-format CSV  (M, Problem, Algorithm, Run, FE, IGD), one row
%        per saved snapshot, for the Python figure builder;
%     2) an inventory log listing, per (M, problem, algorithm, run), the
%        snapshot count and the first/last snapshot FE, so the run counts
%        quoted in the paper can be verified.
%   The script is read-only with respect to the dataset: no result file is
%   created, moved or modified. Only the two output files in the paper
%   figure source-data folder are written.

    addpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO');   % SOLUTION class for load()

    algos = {'REMO','PIEA','CSEA','PCSAEA_N100','KRVEA_100','MCEAD', ...
             'REMO_UniformMix_Pruned_Weighted_Lambdat030'};
    probs = {'WFG1','WFG6','WFG7','WFG8'};
    roots = {10,'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30'; ...
             15,'C:\Users\lsx\Desktop\REMOandDREMO测试集\15目标'; ...
             20,'C:\Users\lsx\Desktop\REMOandDREMO测试集\20目标'};

    outDir   = 'D:\PlatEMO-master\论文写作\figures\source_data';
    outCsv   = fullfile(outDir,'convergence_igd.csv');
    outLog   = fullfile(outDir,'convergence_inventory.txt');
    if ~isfolder(outDir), mkdir(outDir); end

    fid = fopen(outCsv,'w');
    assert(fid > 0,'Cannot open CSV for writing: %s',outCsv);
    fprintf(fid,'M,Problem,Algorithm,Run,FE,IGD\n');
    lid = fopen(outLog,'w');
    assert(lid > 0,'Cannot open log for writing: %s',outLog);
    fprintf(lid,'%s\n',strjoin({'M','Problem','Algorithm','Run', ...
        'Snapshots','FirstFE','LastFE','FinalIGD'},','));

    nRows = 0; nFiles = 0; nSkipped = 0;
    for r = 1:size(roots,1)
        M     = roots{r,1};
        rroot = roots{r,2};
        assert(isfolder(rroot),'Dataset root not found: %s',rroot);
        for a = 1:numel(algos)
            folder = fullfile(rroot,algos{a});
            assert(isfolder(folder),'Algorithm folder not found: %s',folder);
            for p = 1:numel(probs)
                pat = sprintf('%s_%s_M%d_*.mat',algos{a},probs{p},M);
                files = dir(fullfile(folder,pat));
                for f = 1:numel(files)
                    fpath = fullfile(folder,files(f).name);
                    tok = regexp(files(f).name,'_(\d+)\.mat$','tokens','once');
                    if isempty(tok)
                        nSkipped = nSkipped + 1;
                        fprintf(lid,'# unparsed name: %s\n',files(f).name);
                        continue;
                    end
                    runId = str2double(tok{1});
                    try
                        S = load(fpath,'result','metric');
                        fe  = cellfun(@(v) v(1), S.result(:,1));
                        fe  = fe(:);
                        igd = S.metric.IGD(:);
                    catch ME
                        nSkipped = nSkipped + 1;
                        fprintf(lid,'# load failed: %s (%s)\n', ...
                            files(f).name,ME.message);
                        continue;
                    end
                    if numel(fe) ~= numel(igd) || isempty(fe)
                        nSkipped = nSkipped + 1;
                        fprintf(lid,'# length mismatch: %s\n',files(f).name);
                        continue;
                    end
                    for k = 1:numel(fe)
                        fprintf(fid,'%d,%s,%s,%d,%.10g,%.10g\n', ...
                            M,probs{p},algos{a},runId,fe(k),igd(k));
                    end
                    fprintf(lid,'%d,%s,%s,%d,%d,%.10g,%.10g,%.10g\n', ...
                        M,probs{p},algos{a},runId,numel(fe), ...
                        fe(1),fe(end),igd(end));
                    nRows = nRows + numel(fe);
                    nFiles = nFiles + 1;
                end
            end
        end
        fprintf('M=%d done. Total files so far: %d, rows: %d, skipped: %d\n', ...
            M,nFiles,nRows,nSkipped);
    end
    fclose(fid); fclose(lid);
    fprintf('CSV   : %s (%d rows from %d files)\n',outCsv,nRows,nFiles);
    fprintf('LOG   : %s\n',outLog);
    fprintf('Skipped files: %d\n',nSkipped);
end
