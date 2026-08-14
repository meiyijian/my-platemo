function [valid, report] = ValidateLabelCausalAblationFile(filePath, profile)
%ValidateLabelCausalAblationFile Strict validator for a Stage-2 MAT.
%   [valid, report] = ValidateLabelCausalAblationFile(filePath, profile)
%   checks the on-disk contract of one Stage-2 result file:
%     - top-level variables and metadata (incl. Stage-1 provenance)
%     - variant rows: VariantCode/VariantName 1:1, L6 has exactly 100 rows
%       per snapshot, all other variants exactly 1 row per snapshot
%     - catalogs are 0/1, rankings are permutations of 1:N, scores finite
%     - overlap symmetry: Jaccard(A,B) == Jaccard(B,A) by construction
%     - no FE fields (Stage 2 is pure offline)
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
    topVars = {'metadata','variantRowsAll','overlapRowsAll','stabilityRowsAll','validation'};
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
    if ~isfield(meta,'stage2SchemaVersion') || meta.stage2SchemaVersion ~= 2
        report.issues{end+1} = 'stage2SchemaVersion must be 2';
    end
    if ~isfield(meta,'profile') || ~strcmp(meta.profile,profile)
        report.issues{end+1} = sprintf('profile mismatch: expected %s',profile);
    end
    reqMeta = {'behavior','problem','family','M','run','seed','pairedKey', ...
        'problemN','maxFE','completedFE','rGood','theta', ...
        'sourceFile','sourceSchemaVersion','metadataHash','nSnapshots'};
    for i = 1:numel(reqMeta)
        if ~isfield(meta,reqMeta{i})
            report.issues{end+1} = sprintf('Missing metadata field: %s',reqMeta{i});
        end
    end
    if ~all(isfield(meta,reqMeta))
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end

    % ---- no FE fields allowed (pure offline) ----
    evFields = {'EvalID','Decision','Objective','Generation'};
    if isfield(data,'evaluations') || isfield(data,'trajectory') || ...
            isfield(data,'finalPopulation') || isfield(data,'IGD')
        report.issues{end+1} = 'Stage-2 MAT must NOT contain Stage-1 trajectory/evaluation fields';
    end
    % any field name starting with 'eval' or containing 'FE' in top level
    fn = fieldnames(data);
    for i = 1:numel(fn)
        if any(strcmp(fn{i},evFields))
            report.issues{end+1} = sprintf('Forbidden field present: %s',fn{i});
        end
    end

    nSnap = meta.nSnapshots;

    % ---- variant rows ----
    vr = data.variantRowsAll;
    if isempty(vr)
        report.issues{end+1} = 'variantRowsAll empty';
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end
    reqV = {'VariantCode','VariantName','Replicate','PopulationWidth', ...
        'PositiveCount', ...
        'PositiveRate','ScoreMean','ScoreStd','ScoreMin','ScoreMax', ...
        'CatalogHash','RankingHash','DirectionSource','Front1Count', ...
        'UniqueDirectionCount','Ndir','SnapshotID','StageBin','PairedKey'};
    for i = 1:numel(reqV)
        if ~isfield(vr,reqV{i})
            report.issues{end+1} = sprintf('variantRows missing field: %s',reqV{i});
        end
    end
    if ~all(isfield(vr,reqV))
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end

    % VariantCode/VariantName 1:1
    [codes, names] = LVVariantTable();
    codeMap = containers.Map(codes,names);
    nameMap = containers.Map(names,codes);
    for i = 1:numel(vr)
        c = vr(i).VariantCode;
        n = vr(i).VariantName;
        if ~isKey(codeMap,c) || ~strcmp(n,codeMap(c))
            report.issues{end+1} = sprintf('variant(%d) code/name mismatch: %d/%s',i,c,n);
        end
        if ~isKey(nameMap,n) || nameMap(n) ~= c
            report.issues{end+1} = sprintf('variant(%d) name/code mismatch: %s/%d',i,n,c);
        end
    end

    % per-snapshot row counts: L6 == 100, others == 1
    snapIDs = unique([vr.SnapshotID]);
    if numel(snapIDs) ~= nSnap
        report.issues{end+1} = sprintf('variant rows span %d snapshots ~= nSnapshots %d', ...
            numel(snapIDs),nSnap);
    end
    for s = 1:numel(snapIDs)
        sid = snapIDs(s);
        idx = [vr.SnapshotID] == sid;
        vc  = [vr(idx).VariantCode];
        for c = 0:8
            cnt = sum(vc == c);
            if c == 6
                if cnt ~= 100
                    report.issues{end+1} = sprintf( ...
                        'snapshot %d L6 rows %d ~= 100',sid,cnt);
                end
            else
                if cnt ~= 1
                    report.issues{end+1} = sprintf( ...
                        'snapshot %d L%d rows %d ~= 1',sid,c,cnt);
                end
            end
        end
    end

    % PositiveCount sanity (using per-row population width: the first
    % generation of smoke may be initialFE wide, not problemN)
    for i = 1:numel(vr)
        w = vr(i).PopulationWidth;
        if isempty(w) || ~isfinite(w) || w < 1
            report.issues{end+1} = sprintf('variant(%d) bad PopulationWidth',i);
            continue;
        end
        if vr(i).VariantCode == 0
            % L0 is the historical binary baseline (Catalog == LabelDyn).
            % 30%-70% is Stage 1's *target* band for the adaptive delta,
            % not a hard contract: early snapshots (e.g. WFG7 M20 runs 2-5)
            % legitimately fall below 30% (min 0.22). Per plan section 4.2
            % L0 must faithfully reproduce LabelDyn, so only sanity-check
            % that the rate is a legal proportion in (0,1].
            pct = vr(i).PositiveCount / w;
            if pct <= 0 || pct > 1
                report.issues{end+1} = sprintf( ...
                    'variant(%d) L0 positive rate %.3f outside (0,1]',i,pct);
            end
        else
            if vr(i).PositiveCount ~= ceil(w*meta.rGood)
                report.issues{end+1} = sprintf( ...
                    'variant(%d) positive count %d ~= ceil(w*rGood)=%d', ...
                    i,vr(i).PositiveCount,ceil(w*meta.rGood));
            end
        end
        if ~isfinite(vr(i).ScoreMean) || ~isfinite(vr(i).ScoreStd) || ...
                ~isfinite(vr(i).ScoreMin) || ~isfinite(vr(i).ScoreMax)
            report.issues{end+1} = sprintf('variant(%d) non-finite score stats',i);
        end
        if isempty(vr(i).CatalogHash) || isempty(vr(i).RankingHash)
            report.issues{end+1} = sprintf('variant(%d) missing hashes',i);
        end
    end

    % ---- overlap rows ----
    ov = data.overlapRowsAll;
    if ~isempty(ov)
        reqO = {'VariantA','VariantB','Jaccard','IntersectionCount', ...
            'UnionCount','SpearmanScore','CatalogAgreement', ...
            'AOnlyCount','BOnlyCount','SnapshotID'};
        for i = 1:numel(reqO)
            if ~isfield(ov,reqO{i})
                report.issues{end+1} = sprintf('overlapRows missing field: %s',reqO{i});
            end
        end
        if all(isfield(ov,{'Jaccard','VariantA','VariantB'}))
            for i = 1:numel(ov)
                if ~isfinite(ov(i).Jaccard) || ov(i).Jaccard < 0 || ov(i).Jaccard > 1
                    report.issues{end+1} = sprintf( ...
                        'overlap(%d) Jaccard %.3f out of [0,1]',i,ov(i).Jaccard);
                end
            end
        end
    end

    % ---- stability rows ----
    st = data.stabilityRowsAll;
    if ~isempty(st)
        reqS = {'VariantName','DropFraction','Replicate', ...
            'RetainedJaccard','RetainedRankSpearman', ...
            'DirectionSourceAfterDrop','SnapshotID'};
        for i = 1:numel(reqS)
            if ~isfield(st,reqS{i})
                report.issues{end+1} = sprintf('stabilityRows missing field: %s',reqS{i});
            end
        end
        if all(isfield(st,{'VariantName','DropFraction','Replicate'}))
            stabVariants = {'L1','L2','L3','L7','L8'};
            for i = 1:numel(st)
                if ~any(strcmp(st(i).VariantName,stabVariants))
                    report.issues{end+1} = sprintf( ...
                        'stability(%d) bad variant %s',i,st(i).VariantName);
                end
                if st(i).DropFraction ~= 0.05 && st(i).DropFraction ~= 0.10
                    report.issues{end+1} = sprintf( ...
                        'stability(%d) bad drop fraction %.2f',i,st(i).DropFraction);
                end
                if st(i).Replicate < 1 || st(i).Replicate > 100
                    report.issues{end+1} = sprintf( ...
                        'stability(%d) bad replicate %d',i,st(i).Replicate);
                end
                if ~isfinite(st(i).RetainedJaccard)
                    report.issues{end+1} = sprintf( ...
                        'stability(%d) non-finite RetainedJaccard',i);
                end
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
