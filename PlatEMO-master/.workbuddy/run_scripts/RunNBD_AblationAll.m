function RunNBD_AblationAll(workers, Ms)
%RunNBD_AblationAll  Run the requested (objective count, arm) sweeps in one process.
%
%   RunNBD_AblationAll(WORKERS)
%   RunNBD_AblationAll(WORKERS,MS)      MS defaults to [10 20]
%
%   Order: every objective count in MS is completed for one arm before the next
%   arm starts, so passing MS = 10 finishes the whole 10-objective block
%   (2 arms x 16 problems x 20 runs = 640 runs) before anything else runs.
%
%   Every job skips a file that is already on disk, so an interrupted sweep is
%   resumed by simply re-running this function.

    if nargin < 1 || isempty(workers), workers = 5; end
    if nargin < 2 || isempty(Ms),      Ms      = [10 20]; end
    arms = {'noCDIS','noPAQC'};
    t0 = tic;
    for a = 1:numel(arms)
        for m = 1:numel(Ms)
            fprintf('\n########## arm=%s M=%d  (%.1f h elapsed) ##########\n', ...
                arms{a},Ms(m),toc(t0)/3600);
            RunNBD_Ablation('run',arms{a},Ms(m),workers);
        end
    end
    fprintf('\nALL SWEEPS DONE (Ms=%s) in %.1f h\n',mat2str(Ms),toc(t0)/3600);
end
