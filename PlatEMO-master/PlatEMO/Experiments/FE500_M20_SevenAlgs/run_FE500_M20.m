function run_FE500_M20(algKey,part,runs,threads)
%RUN_FE500_M20 One slice of the seven-algorithm FE500 20-objective sweep.
%
%   run_FE500_M20(ALGKEY,PART,RUNS,THREADS)
%     ALGKEY  key from fe500_m20_registry(): REMO | PCSAEA | CSEA | HES_EA |
%             SSDE | SAMOEA | PACDIS
%     PART    global problem index in the 16-problem list:
%               1..7  = DTLZ1..DTLZ7
%               8..16 = WFG1..WFG9        (so WFG3 = 10)
%     RUNS    vector of run numbers for this slice (default 1:20).
%             NOTE the harness expands a SCALAR into 1:RUNS, so the shortest
%             legal slice is a two-element vector.
%     THREADS maxNumCompThreads for this process (default 1)
%
%   Iterating the full 16-problem list with nParts=16 makes every slice a single
%   problem, so the seed stays exactly
%       22260912 + 1000*problemIndex + run   (= 20260912 + M*100000 + ...)
%   i.e. the same paired-seed design as the rest of the 20-objective dataset.
%   Already-stored runs are skipped, so overlapping or repeated launches (and
%   re-driving after a crash) are always safe.
%
%   Protocol (see fe500_m20_registry for the full table and the rationale of
%   every class choice):
%     M=20, N=100, D=30 requested (WFG2/WFG3 -> 31), maxFE=500, save=30,
%     runs 1..20, metrics runtime + IGD + IGDp.
%
%   Results : D:\REMOandDREMO测试集\20目标\FE500\<folder>\
%             MAT = result (<=30x2 cell {FE,Population}) + metric{runtime,IGD,IGDp}
%   Logs    : <this folder>\logs   (the dataset folder stays MAT-only)
%
%   OutputRoot can be redirected on another machine with the environment
%   variable FE500_M20_OUTPUT_ROOT.

    if nargin < 1 || isempty(algKey),  algKey  = 'REMO'; end
    if nargin < 2 || isempty(part),    part    = 1;    end
    if nargin < 3 || isempty(runs),    runs    = 1:20; end
    if nargin < 4 || isempty(threads), threads = 1;    end
    maxNumCompThreads(threads);

    reg = fe500_m20_registry();
    algKey = char(string(algKey));
    % Accept the class name as a key too: the registry key is SAMOEA while the
    % class (and the file prefix) is SAMOEATL2M, which is far too easy to mix up
    % -- typing the class name once silently skipped the algorithm entirely.
    if strcmpi(algKey,'SAMOEATL2M'), algKey = 'SAMOEA'; end
    k = find(strcmpi({reg.key},algKey),1);
    assert(~isempty(k),'FE500_M20:UnknownAlgorithm', ...
        'Unknown algorithm key "%s". Known: %s',algKey,strjoin({reg.key},', '));
    R = reg(k);
    if ~iscell(R.params), R.params = cell(0,0); end   % guard against an [] field

    % Escape hatch: FE500_CLS_<KEY>=<ClassName> swaps the class without touching
    % the registry (e.g. FE500_CLS_HES_EA=HES_EA_N100_guard when the published
    % HES_EA hangs on an orphaned cluster). The output folder tracks the class
    % so a guarded run can never be mistaken for a published-class run.
    clsOverride = getenv(['FE500_CLS_' R.key]);
    if ~isempty(clsOverride)
        assert(exist(clsOverride,'class')==8,'FE500_M20:NoClass','Cannot find class %s',clsOverride);
        R.folder = clsOverride;
        R.cls    = clsOverride;
        fprintf('[note] class override for %s -> %s (folder %s)\n',R.key,R.cls,R.folder);
    end

    % HES_EA projects the objectives onto two random axes and takes cosine
    % angles; problems with an exact zero row in the normalised objectives
    % (WFG3, ...) make pdist2 warn hundreds of times per run. The class already
    % clamps those angles to pi, so the warning is pure noise.
    warning('off','stats:pdist2:ZeroPoints');

    thisFolder = fileparts(mfilename('fullpath'));
    platform   = fileparts(fileparts(thisFolder));
    harnessFolder = fullfile(platform,'Experiments', ...
        'REMO_new2_AdaMaO_UniformMix_Pruned_FullSeries');
    assert(isfolder(harnessFolder),'Missing harness folder: %s',harnessFolder);
    addpath(harnessFolder);

    logFolder = fullfile(thisFolder,'logs');
    if ~isfolder(logFolder), mkdir(logFolder); end

    outputRoot = getenv('FE500_M20_OUTPUT_ROOT');
    if isempty(outputRoot)
        outputRoot = 'D:\REMOandDREMO测试集\20目标\FE500';
    end

    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    if isscalar(runs)
        fprintf(['[note] runs is a scalar %g -> the harness expands it to 1:%g. ' ...
                 'Pass at least two run numbers (e.g. [%g %g]) for a short slice.\n'], ...
                 double(runs),double(runs),double(runs),double(runs)+1);
    end
    runs = round(double(runs(:)'));
    tag  = sprintf('%s_part%02d_r%d-%d',R.key,part,min(runs),max(runs));
    fprintf('=== %s | %s | problem %s | runs %s | threads %d\n', ...
        tag,R.cls,problems{part},mat2str(runs),threads);

    run_UniformMixPrunedFullSeries(part,16, ...
        'OutputRoot',outputRoot, ...
        'FolderName',R.folder, ...
        'Algorithm',R.cls, ...
        'Problems',problems, ...
        'Runs',runs, ...
        'M',20, 'D',30, 'MaxFE',500, 'N',100, ...
        'Parameters',R.params, ...
        'ExtraMetrics',{'IGDp'}, ...
        'SaveCount',30, ...
        'SeedBase',22260912, ...
        'SeedMode','deterministic', ...
        'FESlack',100, ...
        'PlatEMORoot',platform, ...
        'LogFile',fullfile(logFolder,[tag '.log']), ...
        'SummaryCsvDir',logFolder, ...
        'Warmup',true);
end
