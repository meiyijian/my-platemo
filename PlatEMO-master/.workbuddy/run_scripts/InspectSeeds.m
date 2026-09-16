function InspectSeeds()
%InspectSeeds Print the stored metadata of a few existing result files so the
%   seed convention of each batch can be identified before starting new runs.
    root = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    files = { ...
        fullfile(root,'10目标','n30','REMO','REMO_DTLZ1_M10_D30_1.mat')
        fullfile(root,'10目标','n30','REMO','REMO_DTLZ1_M10_D30_18.mat')
        fullfile(root,'20目标','REMO','REMO_DTLZ1_M20_D30_1.mat')
        fullfile(root,'20目标','REMO','REMO_DTLZ1_M20_D30_18.mat')
        fullfile(root,'20目标','REMO_UniformMixCandidate','REMO_UniformMixCandidate_DTLZ1_M20_D30_1.mat')
        fullfile(root,'20目标','REMO_k','REMO_k_DTLZ1_M20_D30_1.mat')
        fullfile(root,'10目标','n30','REMO_UniformMix_Pruned_Weighted_Lambdat030','REMO_UniformMix_Pruned_Weighted_Lambdat030_DTLZ1_M10_D30_19.mat')
        fullfile(root,'20目标','REMO_UniformMix_Pruned_Weighted_Lambdat030','REMO_UniformMix_Pruned_Weighted_Lambdat030_DTLZ1_M20_D30_1.mat')
        fullfile(root,'20目标','REMO_UniformMix_Pruned_Weighted_Lambdat030','REMO_UniformMix_Pruned_Weighted_Lambdat030_DTLZ1_M20_D30_30.mat')
        };
    for i = 1:numel(files)
        f = files{i};
        fprintf('\n=== %s\n',f);
        if ~isfile(f)
            fprintf('   MISSING\n');
            continue;
        end
        S = load(f);
        fprintf('   vars: %s\n',strjoin(fieldnames(S)',', '));
        if isfield(S,'metadata')
            m = S.metadata;
            fn = fieldnames(m);
            for k = 1:numel(fn)
                v = m.(fn{k});
                if isnumeric(v) && ~isempty(v) && numel(v) <= 8
                    fprintf('   %-16s = %s\n',fn{k},mat2str(v));
                elseif ischar(v)
                    fprintf('   %-16s = %s\n',fn{k},v);
                elseif iscell(v)
                    fprintf('   %-16s = %s\n',fn{k},strjoin(cellfun(@(x)sprintf('%g',x),v,'UniformOutput',false),','));
                else
                    fprintf('   %-16s = <%s>\n',fn{k},class(v));
                end
            end
        else
            fprintf('   no metadata struct\n');
        end
        if isfield(S,'metric'), fprintf('   metric fields: %s\n',strjoin(fieldnames(S.metric)',', ')); end
    end
end
