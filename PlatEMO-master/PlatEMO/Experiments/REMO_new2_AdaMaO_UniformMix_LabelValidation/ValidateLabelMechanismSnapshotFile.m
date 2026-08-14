function [valid, report] = ValidateLabelMechanismSnapshotFile(filePath, profile)
%ValidateLabelMechanismSnapshotFile Strict validator for a Stage-1 MAT.
%   [valid, report] = ValidateLabelMechanismSnapshotFile(filePath, profile)
%   checks the on-disk contract of one result file:
%     - schema version and metadata fields
%     - completedFE == maxFE and EvalID == 1:completedFE
%     - dimensions (actualD, M) and finite values
%     - all EvalID foreign keys
%     - behavior invariants (Hybrid topQ size, AnchorNative == LabelDyn)
%
%   profile is 'smoke' | 'pilot' | 'screening'. Returns valid (logical)
%   and report (struct with .issues cellstr and .detail).

    valid  = false;
    report = struct('issues',{{}},'detail','');

    % ---- 1. loadable ----
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

    % ---- 2. top-level variables ----
    schema = LabelValidationSchema();
    for i = 1:numel(schema.topLevelVariables)
        if ~isfield(data,schema.topLevelVariables{i})
            report.issues{end+1} = sprintf('Missing top-level variable: %s', ...
                schema.topLevelVariables{i});
        end
    end
    if ~all(isfield(data,schema.topLevelVariables))
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end

    % ---- 3. metadata ----
    meta = data.metadata;
    if ~isfield(meta,'schemaVersion') || meta.schemaVersion ~= schema.version
        report.issues{end+1} = sprintf('schemaVersion mismatch: expected %d',schema.version);
    end
    if ~isfield(meta,'profile') || ~strcmp(meta.profile,profile)
        report.issues{end+1} = sprintf('profile mismatch: expected %s',profile);
    end
    for i = 1:numel(schema.metadataFields)
        if ~isfield(meta,schema.metadataFields{i})
            report.issues{end+1} = sprintf('Missing metadata field: %s', ...
                schema.metadataFields{i});
        end
    end

    % ---- 4. FE contract ----
    if ~isfield(meta,'completedFE') || ~isfield(meta,'maxFE') || ...
            meta.completedFE ~= meta.maxFE
        report.issues{end+1} = sprintf( ...
            'completedFE (%s) ~= maxFE (%s)', ...
            num2str(meta.completedFE),num2str(meta.maxFE));
    end
    completedFE = meta.completedFE;
    if ~isnumeric(completedFE) || ~isscalar(completedFE) || ...
            completedFE < 1 || completedFE ~= floor(completedFE)
        report.issues{end+1} = 'completedFE must be a positive integer';
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end

    % ---- 5. evaluations ----
    ev = data.evaluations;
    for i = 1:numel(schema.evaluationFields)
        if ~isfield(ev,schema.evaluationFields{i})
            report.issues{end+1} = sprintf('Missing evaluation field: %s', ...
                schema.evaluationFields{i});
        end
    end
    if ~all(isfield(ev,schema.evaluationFields))
        report.detail = sprintf('%d issue(s)',numel(report.issues));
        return;
    end
    if ~isequal(ev.EvalID(:),(1:completedFE)')
        report.issues{end+1} = 'EvalID must equal 1:completedFE';
    end
    if size(ev.Decision,1) ~= completedFE || size(ev.Objective,1) ~= completedFE
        report.issues{end+1} = 'evaluations row count ~= completedFE';
    end
    actualD = meta.actualD;
    if size(ev.Decision,2) ~= actualD
        report.issues{end+1} = sprintf('Decision columns %d ~= actualD %d', ...
            size(ev.Decision,2),actualD);
    end
    if size(ev.Objective,2) ~= meta.M
        report.issues{end+1} = sprintf('Objective columns %d ~= M %d', ...
            size(ev.Objective,2),meta.M);
    end
    if ~all(isfinite(ev.Decision(:))) || ~all(isfinite(ev.Objective(:)))
        report.issues{end+1} = 'evaluations contain non-finite values';
    end
    if any(ev.Generation < 0) || any(ev.Generation ~= floor(ev.Generation))
        report.issues{end+1} = 'evaluations.Generation must be non-negative integers';
    end

    % ---- 6. WFG3 dimension fact ----
    if strcmp(meta.problem,'WFG3')
        if meta.actualD ~= 31 || meta.requestedD ~= 30
            report.issues{end+1} = 'WFG3 must have requestedD=30, actualD=31';
        end
    else
        if meta.actualD ~= meta.requestedD
            report.issues{end+1} = sprintf( ...
                'Non-WFG3 actualD %d ~= requestedD %d', ...
                meta.actualD,meta.requestedD);
        end
    end

    % ---- 7. snapshots ----
    snap = data.snapshots;
    traj = data.trajectory;
    nSnap = numel(snap);
    nTraj = numel(traj);
    if nSnap == 0 || nTraj == 0
        report.issues{end+1} = 'snapshots/trajectory must be non-empty';
    end
    if nSnap ~= nTraj
        report.issues{end+1} = sprintf('snapshot rows %d ~= trajectory rows %d', ...
            nSnap,nTraj);
    end
    popN = meta.problemN;   % Problem.N used by the algorithm
    for s = 1:nSnap
        S = snap(s);
        for i = 1:numel(schema.snapshotFields)
            if ~isfield(S,schema.snapshotFields{i})
                report.issues{end+1} = sprintf( ...
                    'snapshot(%d) missing field: %s',s,schema.snapshotFields{i});
            end
        end
        if ~all(isfield(S,schema.snapshotFields))
            continue;
        end
        % row widths: first generation population may be the initialization
        % size (11D-1 for D<=10) instead of Problem.N; later generations
        % equal Problem.N. Plan section 3.1 requires the validator to
        % expect this fact (smoke: initialFE=32, problemN=20).
        wPop = numel(S.PopulationEvalID);
        if wPop ~= popN && wPop ~= meta.initialFE
            report.issues{end+1} = sprintf( ...
                'snapshot(%d) population width %d ~= {problemN, initialFE}',s,wPop);
        end
        if size(S.PopulationDec,1) ~= wPop || size(S.PopulationObj,1) ~= wPop
            report.issues{end+1} = sprintf( ...
                'snapshot(%d) population matrix rows ~= population width',s);
        end
        if numel(S.LabelDyn) ~= wPop || numel(S.ScoreV) ~= wPop || ...
                numel(S.ScoreHybrid) ~= wPop || numel(S.CatalogCurrent) ~= wPop || ...
                numel(S.AnchorNormalizedG) ~= wPop || ...
                numel(S.AnchorMargin) ~= wPop
            report.issues{end+1} = sprintf( ...
                'snapshot(%d) label/view width ~= population width',s);
        end
        if size(S.V,2) ~= meta.M || size(S.V,1) < 1
            report.issues{end+1} = sprintf( ...
                'snapshot(%d) V size %dx%d ~= * x M',s,size(S.V,1),size(S.V,2));
        end
        % foreign keys
        if ~all(ismember(S.PopulationEvalID,1:completedFE))
            report.issues{end+1} = sprintf( ...
                'snapshot(%d) PopulationEvalID out of range',s);
        end
        if ~all(ismember(S.RefEvalID,1:completedFE))
            report.issues{end+1} = sprintf( ...
                'snapshot(%d) RefEvalID out of range',s);
        end
        % finite values
        if ~all(isfinite(S.PopulationDec(:))) || ~all(isfinite(S.PopulationObj(:))) || ...
                ~all(isfinite(S.ScoreV(:))) || ~all(isfinite(S.ScoreHybrid(:))) || ...
                ~all(isfinite(S.AnchorNormalizedG(:))) || ~all(isfinite(S.V(:)))
            report.issues{end+1} = sprintf( ...
                'snapshot(%d) contains non-finite values',s);
        end
        % behavior invariants
        if strcmp(meta.behavior,'Hybrid')
            expected = ceil(numel(S.CatalogCurrent)*meta.rGood);
            if sum(S.CatalogCurrent) ~= expected
                report.issues{end+1} = sprintf( ...
                    'Hybrid snapshot(%d) CatalogCurrent sum %d ~= ceil(pop*rGood)=%d', ...
                    s,sum(S.CatalogCurrent),expected);
            end
            if ~isequal(S.TrainingCatalog(:),S.CatalogCurrent(:))
                report.issues{end+1} = sprintf( ...
                    'Hybrid snapshot(%d) TrainingCatalog ~= CatalogCurrent',s);
            end
        elseif strcmp(meta.behavior,'AnchorNative')
            if ~isequal(S.TrainingCatalog(:),S.LabelDyn(:))
                report.issues{end+1} = sprintf( ...
                    'AnchorNative snapshot(%d) TrainingCatalog ~= LabelDyn',s);
            end
        end
    end

    % ---- 8. trajectory ----
    for t = 1:nTraj
        T = traj(t);
        for i = 1:numel(schema.trajectoryFields)
            if ~isfield(T,schema.trajectoryFields{i})
                report.issues{end+1} = sprintf( ...
                    'trajectory(%d) missing field: %s',t,schema.trajectoryFields{i});
            end
        end
        if ~all(isfield(T,schema.trajectoryFields))
            continue;
        end
        if ~any(strcmp(T.CandidateMode,schema.candidateModes))
            report.issues{end+1} = sprintf( ...
                'trajectory(%d) invalid CandidateMode: %s',t,T.CandidateMode);
        end
        if ~isempty(T.SelectedEvalID) && ...
                ~all(ismember(T.SelectedEvalID,1:completedFE))
            report.issues{end+1} = sprintf( ...
                'trajectory(%d) SelectedEvalID out of range',t);
        end
        if ~all(ismember(T.PopulationEvalIDAfter,1:completedFE))
            report.issues{end+1} = sprintf( ...
                'trajectory(%d) PopulationEvalIDAfter out of range',t);
        end
        if T.FEBefore < 0 || T.FEAfter < T.FEBefore || T.FEAfter > completedFE
            report.issues{end+1} = sprintf( ...
                'trajectory(%d) invalid FEBefore/FEAfter',t);
        end
    end

    % ---- 9. final population / metrics ----
    fp = data.finalPopulation;
    if size(fp.dec,1) ~= size(fp.obj,1)
        report.issues{end+1} = 'finalPopulation rows mismatch dec/obj';
    end
    if ~all(isfinite(fp.dec(:))) || ~all(isfinite(fp.obj(:)))
        report.issues{end+1} = 'finalPopulation contains non-finite values';
    end
    if ~isfinite(data.IGD) || ~isfinite(data.IGDp)
        report.issues{end+1} = 'IGD/IGDp must be finite';
    end
    if ~isfinite(data.runtime) || ~isfinite(data.auditRuntime)
        report.issues{end+1} = 'runtime/auditRuntime must be finite';
    end

    % ---- verdict ----
    if isempty(report.issues)
        valid = true;
        report.detail = 'OK';
    else
        report.detail = sprintf('%d issue(s)',numel(report.issues));
    end
end
