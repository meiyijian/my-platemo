function [valid, report] = ValidateIndependentUtilityFile(filePath, profile)
%ValidateIndependentUtilityFile Strict validator for a Stage-3 MAT.
%   [valid, report] = ValidateIndependentUtilityFile(filePath, profile)
%   checks the on-disk contract of one Stage-3 result file:
%     - top-level variables and metadata (incl. Stage-1/Stage-2 provenance)
%     - checkpoint rows: targetRatio 0.20/0.40/0.60/0.80/0.95, no dupes
%     - solutionUtilityRows: PopulationEvalID present, finite LOO
%     - variantMetricRows: L0 native + L1-L8 rows, sane Jaccard in [0,1]
%     - disagreementRows: three pre-registered pairs present
%     - referenceSensitivity present (or explicit NA)
%     - no FE fields (Stage 3 is pure offline)
%
%   profile is 'smoke' | 'pilot' | 'screening'. Returns valid (logical)
%   and report (struct with .issues cellstr and .detail).

    valid  = false;
    report = struct('issues',{{}},'detail','');

    if ~isfile(filePath)
        report.issues{end+1} = sprintf('File not found: %s',filePath);
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end
    try
        data = load(filePath);
    catch err
        report.issues{end+1} = sprintf('Cannot load MAT: %s',err.message);
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end

    % ---- top-level variables ----
    topVars = {'metadata','checkpointRows','solutionUtilityRows', ...
        'variantMetricRows','disagreementRows','referenceSensitivity','validation'};
    for i = 1:numel(topVars)
        if ~isfield(data,topVars{i})
            report.issues{end+1} = sprintf('Missing top-level variable: %s',topVars{i});
        end
    end
    if ~all(isfield(data,topVars))
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end

    meta = data.metadata;
    if ~isfield(meta,'stage3SchemaVersion') || meta.stage3SchemaVersion ~= 1
        report.issues{end+1} = 'stage3SchemaVersion must be 1';
    end
    if ~isfield(meta,'profile') || ~strcmp(meta.profile,profile)
        report.issues{end+1} = sprintf('profile mismatch: expected %s',profile);
    end
    reqMeta = {'behavior','problem','family','M','run','seed','pairedKey', ...
        'stage1File','stage2File','stage1MetadataHash','stage2MetadataHash', ...
        'problemN','maxFE','completedFE','rGood','referenceSeed','nCheckpoints'};
    for i = 1:numel(reqMeta)
        if ~isfield(meta,reqMeta{i})
            report.issues{end+1} = sprintf('Missing metadata field: %s',reqMeta{i});
        end
    end
    if ~all(isfield(meta,reqMeta))
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end

    % ---- no FE fields (pure offline) ----
    fn = fieldnames(data);
    for i = 1:numel(fn)
        if any(strcmp(fn{i},{'EvalID','Decision','Objective','Generation', ...
                'evaluations','trajectory','finalPopulation'}))
            report.issues{end+1} = sprintf('Forbidden field present: %s',fn{i});
        end
    end

    % ---- checkpoint rows ----
    cp = data.checkpointRows;
    if isempty(cp)
        report.issues{end+1} = 'checkpointRows empty';
    else
        reqC = {'TargetRatio','SnapshotID','FE','Ratio','StageBin', ...
            'OracleTop25Count','NondominatedCount','UtilityLOONonZero'};
        for i = 1:numel(reqC)
            if ~isfield(cp,reqC{i})
                report.issues{end+1} = sprintf('checkpointRows missing field: %s',reqC{i});
            end
        end
        targetRatios = [cp.TargetRatio];
        expected = [0.20 0.40 0.60 0.80 0.95];
        if strcmp(profile,'screening')
            % formal screening requires all five checkpoints
            for t = 1:numel(expected)
                if ~any(abs(targetRatios - expected(t)) < 1e-9)
                    report.issues{end+1} = sprintf( ...
                        'checkpoint target %.2f missing',expected(t));
                end
            end
        else
            % smoke/pilot only validate the implementation: at least one
            % checkpoint (may be < 5 because few snapshots exist)
            if isempty(targetRatios)
                report.issues{end+1} = 'no checkpoint rows';
            end
        end
        if numel(unique([cp.SnapshotID])) ~= numel(cp)
            report.issues{end+1} = 'duplicate checkpoint SnapshotID';
        end
        if any([cp.OracleTop25Count] ~= 25)
            report.issues{end+1} = 'OracleTop25Count must be 25';
        end
    end

    % ---- solution utility rows ----
    su = data.solutionUtilityRows;
    if isempty(su)
        report.issues{end+1} = 'solutionUtilityRows empty';
    else
        reqS = {'CheckpointID','PopulationEvalID','UtilityLOO', ...
            'InOracleTop25','InPopulationH1','InPopulationH3', ...
            'InFinalPopulation','NondominatedInArchiveH1', ...
            'NondominatedInArchiveH3','NondominatedInFinalArchive'};
        for i = 1:numel(reqS)
            if ~isfield(su,reqS{i})
                report.issues{end+1} = sprintf( ...
                    'solutionUtilityRows missing field: %s',reqS{i});
            end
        end
        if all(isfield(su,{'UtilityLOO','CheckpointID','PopulationEvalID'}))
            if any(~isfinite([su.UtilityLOO]))
                report.issues{end+1} = 'non-finite UtilityLOO';
            end
            if any([su.UtilityLOO] < 0)
                report.issues{end+1} = 'negative UtilityLOO';
            end
            % each checkpoint must have a consistent positive row count;
            % for screening this equals problemN (100)
            cps = unique([su.CheckpointID]);
            expectedRows = [];
            if strcmp(profile,'screening')
                expectedRows = meta.problemN;
            end
            for c = 1:numel(cps)
                n = nnz([su.CheckpointID]==cps(c));
                if n < 1
                    report.issues{end+1} = sprintf( ...
                        'checkpoint %d has no solution rows',cps(c));
                elseif ~isempty(expectedRows) && n ~= expectedRows
                    report.issues{end+1} = sprintf( ...
                        'checkpoint %d solution rows %d ~= problemN %d', ...
                        cps(c),n,expectedRows);
                end
            end
        end
    end

    % ---- variant metric rows ----
    vm = data.variantMetricRows;
    if isempty(vm)
        report.issues{end+1} = 'variantMetricRows empty';
    else
        reqV = {'CheckpointID','VariantName','Replicate', ...
            'PrecisionAt25','RecallAt25','JaccardAt25'};
        for i = 1:numel(reqV)
            if ~isfield(vm,reqV{i})
                report.issues{end+1} = sprintf( ...
                    'variantMetricRows missing field: %s',reqV{i});
            end
        end
        if all(isfield(vm,{'VariantName','CheckpointID'}))
            vNames = {vm.VariantName};
            for v = {'L0','L1','L2','L3','L4','L5','L6','L7','L8'}
                if ~any(strcmp(vNames,v{1}))
                    report.issues{end+1} = sprintf( ...
                        'variant %s missing from metric rows',v{1});
                end
            end
        end
        if all(isfield(vm,{'JaccardAt25','VariantName'}))
            for i = 1:numel(vm)
                if ~strcmp(vm(i).VariantName,'L0')
                    j = vm(i).JaccardAt25;
                    if isnan(j) || j < 0 || j > 1
                        report.issues{end+1} = sprintf( ...
                            'variantMetric(%d) JaccardAt25 %.3f out of [0,1]',i,j);
                    end
                end
            end
        end
    end

    % ---- disagreement rows ----
    dg = data.disagreementRows;
    if isempty(dg)
        report.issues{end+1} = 'disagreementRows empty';
    else
        reqD = {'CheckpointID','VariantA','VariantB','AOnlyCount','BOnlyCount'};
        for i = 1:numel(reqD)
            if ~isfield(dg,reqD{i})
                report.issues{end+1} = sprintf( ...
                    'disagreementRows missing field: %s',reqD{i});
            end
        end
        % three pre-registered pairs present per checkpoint
        if all(isfield(dg,{'VariantA','VariantB','CheckpointID'}))
            cps = unique([dg.CheckpointID]);
            for c = 1:numel(cps)
                idx = [dg.CheckpointID]==cps(c);
                keys = arrayfun(@(x)sprintf('%s|%s',x.VariantA,x.VariantB), ...
                    dg(idx),'UniformOutput',false);
                for pr = {'L2|L1','L3|L1','L3|L2'}
                    if ~any(strcmp(keys,pr{1}))
                        report.issues{end+1} = sprintf( ...
                            'disagreement pair %s missing at checkpoint %d', ...
                            pr{1},cps(c));
                    end
                end
            end
        end
    end

    % ---- reference sensitivity ----
    rs = data.referenceSensitivity;
    if isempty(rs)
        report.issues{end+1} = 'referenceSensitivity empty';
    else
        reqR = {'ReferenceSize','SpearmanLOO','OracleJaccard','Passed'};
        for i = 1:numel(reqR)
            if ~isfield(rs,reqR{i})
                report.issues{end+1} = sprintf( ...
                    'referenceSensitivity missing field: %s',reqR{i});
            end
        end
    end

    % ---- verdict ----
    if isempty(report.issues)
        valid = true;
        report.detail = 'OK';
    else
        report.detail = sprintf('%d issue(s)',numel(report.issues));
    end
end
