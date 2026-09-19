function run_HES_EA_N100_M10(part,runs,threads)
%Run one slice of the M=10 DTLZ/WFG sweep for HES_EA_N100.
%
%   run_HES_EA_N100_M10(PART,RUNS,THREADS)
%     PART    - global problem index in the paper's 16-problem list:
%               1..7  = DTLZ1..DTLZ7
%               8..16 = WFG1..WFG9
%     RUNS    - vector of run numbers for this slice (default 1:20)
%     THREADS - maxNumCompThreads for this process (default 1)
%
%   Iterating the full 16-problem list with nParts=16 makes every slice a
%   single problem, so the seed stays exactly
%       21260912 + 1000*problemIndex + run      (= 20260912 + M*100000 + ...)
%   which matches the rest of the 10-objective dataset. RUNS may be a vector,
%   so several processes can share one problem and split the run range.
%   Stored results are skipped, so overlapping or repeated launches are safe.
%
%   Algorithm: HES_EA_N100
%              "A Hierarchical and Ensemble Surrogate-Assisted Evolutionary
%               Algorithm with Model Reduction for Expensive Many-objective
%               Optimization", IEEE TEVC 2024.
%   Its own hyper-parameters stay at the published defaults
%   {wmax,WN,KMeans} = {20,190,4}. `Parameters` is therefore passed as an
%   EMPTY cell so Algorithm.ParameterSet falls back to the class defaults.
%   (Passing the house 5-element vector here would silently set
%    wmax=3000 / WN=0.5 / KMeans=0.25.)
%
%   Extra metric: IGDp as well as IGD (both traces, 30 snapshots each).
%
%   Results : D:\REMOandDREMO测试集\10目标\n30\HES_EA_N100
%             MAT = result (30x2 cell {FE,Population}) + metric{runtime,IGD,IGDp}
%   Logs    : <this folder>\logs   (the dataset folder stays MAT-only)

    if nargin < 1 || isempty(part),    part    = 1;    end
    if nargin < 2 || isempty(runs),    runs    = 1:20; end
    if nargin < 3 || isempty(threads), threads = 1;    end
    maxNumCompThreads(threads);

    % HES_EA_N100 projects the objectives onto two randomly chosen axes and
    % takes cosine angles (its line ~75). Problems whose normalised objectives
    % contain an exact zero row (WFG3, ...) make pdist2 emit
    % 'stats:pdist2:ZeroPoints' hundreds of times per run; the class already
    % clamps those angles to pi, so the warning is pure noise. Suppressed here
    % (in the runner, NOT in the algorithm) to keep the slice logs readable.
    warning('off','stats:pdist2:ZeroPoints');

    thisFolder = fileparts(mfilename('fullpath'));
    platform   = fileparts(fileparts(thisFolder));
    harnessFolder = fullfile(platform,'Experiments', ...
        'REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries');
    assert(isfolder(harnessFolder),'Missing harness folder: %s',harnessFolder);
    addpath(harnessFolder);

    logFolder = fullfile(thisFolder,'logs');
    if ~isfolder(logFolder), mkdir(logFolder); end

    % Output root may be relocated on another machine; the folder name inside it
    % is fixed to HES_EA_N100. Default = this project's 10-objective dataset.
    outputRoot = getenv('HESEA_M10_OUTPUT_ROOT');
    if isempty(outputRoot)
        outputRoot = 'D:\REMOandDREMO测试集\10目标\n30';
    end

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    % The harness expands any SCALAR `Runs` into 1:Runs. In MATLAB
    % isscalar([7]) is true, so even a one-element vector is expanded -- there
    % is no way to ask the harness for exactly one run; the shortest request is
    % a two-element vector. Warn loudly rather than silently launching 1:RUNS.
    if isscalar(runs)
        fprintf(['[note] runs is a scalar %g -> the harness expands it to ' ...
                 '1:%g. Pass at least two run numbers (e.g. [%g %g]) to keep ' ...
                 'the slice short.\n'], ...
                 double(runs),double(runs),double(runs),double(runs)+1);
    end
    runs = round(double(runs(:)'));
    tag  = sprintf('part%02d_r%d-%d',part,min(runs),max(runs));
    fprintf('=== %s | problem %s | runs %s | threads %d | platform %s\n', ...
        tag,problems{part},mat2str(runs),threads,platform);

    run_UniformMixPrunedFullSeries(part,16, ...
        'OutputRoot',outputRoot, ...
        'FolderName','HES_EA_N100', ...
        'Algorithm','HES_EA_N100', ...
        'Problems',problems, ...
        'Runs',runs, ...
        'M',10, 'D',30, 'MaxFE',300, 'N',100, ...
        'Parameters',{}, ...
        'ExtraMetrics',{'IGDp'}, ...
        'SaveCount',30, ...
        'SeedBase',21260912, ...
        'SeedMode','deterministic', ...
        'PlatEMORoot',platform, ...
        'LogFile',fullfile(logFolder,[tag '.log']), ...
        'SummaryCsvDir',logFolder, ...
        'Warmup',true);
end
