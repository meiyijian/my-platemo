function out = ReconstructFutureLabelOutcomes(snapshots, trajectory, evaluations, snapIdx)
%ReconstructFutureLabelOutcomes Rebuild H1/H3/FINAL future outcomes (§5.3).
%   out = ReconstructFutureLabelOutcomes(snapshots, trajectory, evaluations, snapIdx)
%   snapshots/trajectory/evaluations come straight from a Stage-1 MAT.
%   snapIdx is the index (1-based) of the current checkpoint snapshot.
%
%   For each solution of the current snapshot's population this returns:
%     InPopulationH1/H3/Final        : logical (is the EvalID in the future
%                                      population snapshot)
%     NondominatedInArchiveH1/H3/Final: logical (is the solution's real
%                                      objective vector non-dominated in
%                                      the future archive, rebuilt from
%                                      evaluations with EvalID <= futureFE)
%   Missing future snapshots produce NaN + a censor flag (NOT 0).
%
%   The next 1st/3rd *actual training* snapshots (CandidateMode ~= 'fallback')
%   define H1/H3; the final population is the last trajectory row's
%   PopulationEvalIDAfter.

    nSnap = numel(snapshots);
    curPopIDs = snapshots(snapIdx).PopulationEvalID(:);
    curObjs   = snapshots(snapIdx).PopulationObj;
    N = numel(curPopIDs);

    % training (non-fallback) snapshot indices, in generation order
    trainIdx = find(arrayfun(@(t)~strcmp(t.CandidateMode,'fallback'), trajectory));

    % ---- H1 / H3 ----
    after = trainIdx(trainIdx > snapIdx);
    [h1,h3] = deal(NaN, NaN);
    if numel(after) >= 1, h1 = after(1); end
    if numel(after) >= 3, h3 = after(3); end

    % ---- FINAL population ----
    finalIDs = trajectory(end).PopulationEvalIDAfter(:);

    out = struct();
    % censored until proven observable: H1/H3 stay NaN when no future
    % training snapshot exists (plan §3: NaN, never 0 or "did not survive")
    out.InPopulationH1   = NaN(N,1);
    out.InPopulationH3   = NaN(N,1);
    out.InFinalPopulation = ismember(curPopIDs, finalIDs);
    out.NondominatedInArchiveH1   = NaN(N,1);
    out.NondominatedInArchiveH3   = NaN(N,1);
    out.NondominatedInFinalArchive = NaN(N,1);
    out.censoredH1 = isnan(h1);
    out.censoredH3 = isnan(h3);
    out.H1FE = NaN; out.H3FE = NaN;
    out.H1snapIdx = NaN; out.H3snapIdx = NaN;

    ev = evaluations;
    evObj = ev.Objective;
    evID  = ev.EvalID(:);

    % ---- H1 ----
    if ~isnan(h1)
        out.H1FE = snapshots(h1).FE;
        out.H1snapIdx = h1;
        fIDs = snapshots(h1).PopulationEvalID(:);
        out.InPopulationH1 = ismember(curPopIDs, fIDs);
        arch = evObj(evID <= snapshots(h1).FE, :);
        out.NondominatedInArchiveH1 = isNondominatedSet(curObjs, arch);
    end

    % ---- H3 ----
    if ~isnan(h3)
        out.H3FE = snapshots(h3).FE;
        out.H3snapIdx = h3;
        fIDs = snapshots(h3).PopulationEvalID(:);
        out.InPopulationH3 = ismember(curPopIDs, fIDs);
        arch = evObj(evID <= snapshots(h3).FE, :);
        out.NondominatedInArchiveH3 = isNondominatedSet(curObjs, arch);
    end

    % ---- FINAL archive (all evaluated objectives up to completedFE) ----
    maxFE = max(evID);
    archFinal = evObj(evID <= maxFE, :);
    out.NondominatedInFinalArchive = isNondominatedSet(curObjs, archFinal);
end

%% ============ non-domination against an archive (minimization) ============
function nd = isNondominatedSet(sols, arch)
%isNondominatedSet For each row of sols, is it non-dominated within arch?
    ns = size(sols,1);
    nd = true(ns,1);
    for i = 1:ns
        s = sols(i,:);
        domBy = all(arch <= s,2) & any(arch < s,2);
        nd(i) = ~any(domBy);
    end
end
