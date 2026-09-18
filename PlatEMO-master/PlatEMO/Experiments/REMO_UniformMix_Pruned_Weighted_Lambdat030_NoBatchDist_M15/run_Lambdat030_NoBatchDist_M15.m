function run_Lambdat030_NoBatchDist_M15(part,runs,threads)
%Run one slice of the M=15 DTLZ/WFG sweep for the NoBatchDist variant.
%
%   run_Lambdat030_NoBatchDist_M15(PART,RUNS,THREADS)
%     PART    - global problem index in the paper's 16-problem list:
%               1..7  = DTLZ1..DTLZ7
%               8..16 = WFG1..WFG9
%     RUNS    - vector of run numbers for this slice (default 1:20)
%     THREADS - maxNumCompThreads for this process (default 1)
%
%   Iterating the full 16-problem list with nParts=16 makes every slice a
%   single problem, so the seed stays exactly
%       21760912 + 1000*problemIndex + run      (= 20260912 + M*100000 + ...)
%   which matches the rest of the 15-objective dataset. RUNS may be a vector,
%   so several processes can share one problem and split the run range. Stored
%   results are skipped, so overlapping or repeated launches are always safe.
%
%   Algorithm: REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist
%              (Lambdat030 with the 0.25*batch-distance term deleted, the
%               0.30 ambiguity reward kept).
%
%   Results : D:\REMOandDREMO测试集\15目标\REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist
%   Logs    : <this folder>\logs   (the dataset folder stays MAT-only)

    if nargin < 1 || isempty(part),    part    = 1;    end
    if nargin < 2 || isempty(runs),    runs    = 1:20; end
    if nargin < 3 || isempty(threads), threads = 1;    end
    maxNumCompThreads(threads);

    thisFolder = fileparts(mfilename('fullpath'));
    platform   = fileparts(fileparts(thisFolder));
    harnessFolder = fullfile(platform,'Experiments', ...
        'REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries');
    assert(isfolder(harnessFolder),'Missing harness folder: %s',harnessFolder);
    addpath(harnessFolder);

    logFolder = fullfile(thisFolder,'logs');
    if ~isfolder(logFolder), mkdir(logFolder); end

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    runs = round(double(runs(:)'));
    tag  = sprintf('part%02d_r%d-%d',part,min(runs),max(runs));
    fprintf('=== %s | problem %s | runs %s | threads %d | platform %s\n', ...
        tag,problems{part},mat2str(runs),threads,platform);

    run_UniformMixPrunedFullSeries(part,16, ...
        'OutputRoot','D:\REMOandDREMO测试集\15目标', ...
        'FolderName','REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist', ...
        'Algorithm','REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist', ...
        'Problems',problems, ...
        'Runs',runs, ...
        'M',15, 'D',30, 'MaxFE',300, 'N',100, ...
        'Parameters',{3000,0.50,0.25,0.70,6}, ...
        'SaveCount',30, ...
        'SeedBase',21760912, ...
        'SeedMode','deterministic', ...
        'PlatEMORoot',platform, ...
        'LogFile',fullfile(logFolder,[tag '.log']), ...
        'SummaryCsvDir',logFolder, ...
        'Warmup',true);
end
