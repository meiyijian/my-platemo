function MergeAllFE500IGDp(M,workers)
%MergeAllFE500IGDp Compute and merge the IGD+ trace for every algorithm of one
%   FE500 batch. Thin loop over MergeIGDpForDir with the subDir argument set to
%   'FE500', so the folder layout <M目标>[\n30]\FE500\<alg> is handled.
%   Files that already carry a trace of the right length are reused, so the call
%   is resume-safe and cheap to repeat.
    if nargin < 1 || isempty(M), M = 15; end
    if nargin < 2 || isempty(workers), workers = 12; end
    algs = {'SSDE','PCSAEA','SAMOEATL2M','CSEA', ...
            'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist','HES_EA','REMO'};
    for a = 1:numel(algs)
        fprintf('\n########## %s (M=%d) ##########\n',algs{a},M);
        try
            MergeIGDpForDir(algs{a},M,workers,false,[],'FE500');
        catch err
            fprintf(2,'%s failed: %s\n',algs{a},err.message);
        end
    end
    fprintf('\nMergeAllFE500IGDp M=%d DONE\n',M);
end
