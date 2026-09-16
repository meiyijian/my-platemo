function out = ProbeCdisResolution()
%ProbeCdisResolution Temporary probe: report the resolved file of the private
%   helper functions when called from inside RMEO_k_CDIS. Moved out of the
%   algorithm folder immediately after the smoke test.

    names = {'ResolveUniformMixMode','Shape_Estimate','RefSelect', ...
        'GetOutput_PBI','DataProcess','onehotconv','GetRelationPairs', ...
        'IndicatorSelectorSDEOnly','Lambdat030WeightedBatchSelection', ...
        'PrunedIndicatorSelection','DiversifiedInfillSelection', ...
        'calFitness_SDE','CreateSDECandidateModeStream'};
    out = struct();
    for i = 1:numel(names)
        fh = str2func(names{i});
        info = functions(fh);
        out.(names{i}) = info.file;
    end
end
