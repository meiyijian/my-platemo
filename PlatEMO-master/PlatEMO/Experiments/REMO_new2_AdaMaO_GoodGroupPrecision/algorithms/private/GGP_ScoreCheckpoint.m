function row = GGP_ScoreCheckpoint(cp,Population,Archive,Problem,rGood)
% GGP_ScoreCheckpoint - Score one matured checkpoint against ex-post truth.
%
% A checkpoint recorded, at iteration cp.iter, three candidate positive
% groups (score_v / label_dyn / score_hybrid) nominated from the population
% of that iteration. Enough further iterations have now elapsed that we can
% ask which of those nominations were actually right.
%
% Ground truths (all three are computed for every checkpoint, so no single
% definition can drive the conclusion on its own):
%
%   retained - the nominated solution is still in the CURRENT Population,
%              i.e. it survived RefSelect(Archive,Problem.N) at every
%              intervening generation. Note this is deliberately not
%              "present in the Archive": the frozen loop only ever appends
%              to the Archive and never prunes it, so an Archive-membership
%              truth would be satisfied by every nominee and every signal
%              would score exactly 1.0. Population retention is the real
%              retention bar, and it needs no true Pareto front.
%
%   front    - the nominated solution is in the first nondominated front of
%              the current Archive. Stricter than retention in one sense
%              (it demands nondominance against everything evaluated so
%              far) and weaker in another (a solution RefSelect dropped for
%              crowding can still be nondominated), so it is a genuinely
%              independent reading rather than a harder version of the
%              first.
%
%   igdgain  - the nominated solution is among the top rGood fraction of
%              the snapshot population by IGD+ contribution, measured by
%              leave-one-out against the problem's true optimum. This is
%              the only truth that uses the reference front, and it is the
%              one that speaks directly to convergence quality.
%
% Precision for a signal under a truth is |nominated ∩ true| / |nominated|.
%
% Chance level is reported alongside, because with a positive group of size
% ceil(N*rGood) a signal that nominated uniformly at random would already
% score around the prevalence of the true set. A precision of 0.6 means
% nothing until you know whether chance was 0.25 or 0.55.

    snapObj = cp.snapObj;
    N       = size(snapObj,1);
    kTop    = ceil(N*rGood);

    %% ---- truth 1: retention in the current Population ----
    % Matching is by exact objective row. Solutions are carried by reference
    % from Archive to Population without arithmetic, so a retained solution
    % has a bit-identical objective row; a tolerance would risk crediting a
    % nomination for a *different* nearby solution.
    PopObjNow  = Population.objs;
    aliveMask  = ismember(snapObj,PopObjNow,'rows');

    %% ---- truth 2: first front of the Archive ----
    ArchObj    = Archive.objs;
    frontNo    = NDSort(ArchObj,1);
    ArchFirst  = ArchObj(frontNo==1,:);
    frontMask  = ismember(snapObj,ArchFirst,'rows');

    %% ---- truth 3: top IGD+ contribution within the snapshot ----
    optimum = Problem.optimum;
    if isempty(optimum) || size(optimum,2) ~= size(snapObj,2)
        igdMask   = [];
        igdChance = NaN;
    else
        contrib = GGP_LooIGDpContribution(snapObj,optimum);
        % Larger contribution = removing it hurts more = more valuable.
        % Ties broken by ascending row index, matching LVTopQDeterministic,
        % so a flat contribution vector does not let array order decide.
        [~,ord]              = sortrows([-contrib(:),(1:N)']);
        igdMask              = false(N,1);
        igdMask(ord(1:kTop)) = true;
        igdChance            = sum(igdMask)/N;
    end

    row = struct();
    row.iter      = cp.iter;
    row.scoreIter = cp.scoreIter;
    row.FE        = cp.FE;
    row.ratio     = cp.ratio;
    row.N         = N;
    row.kTop      = kTop;
    row.scored    = true;

    % Chance levels: prevalence of each true set in the snapshot.
    row.chance_retained = sum(aliveMask)/N;
    row.chance_front    = sum(frontMask)/N;
    row.chance_igdgain  = igdChance;

    views  = {'v','anchor','hybrid'};
    truths = {'retained','front','igdgain'};
    masks  = {aliveMask,frontMask,igdMask};

    for t = 1 : numel(truths)
        mask = masks{t};
        for s = 1 : numel(views)
            idx   = cp.groups.(views{s});
            field = sprintf('prec_%s_%s',views{s},truths{t});
            if isempty(mask) || isempty(idx)
                row.(field) = NaN;
            else
                row.(field) = sum(mask(idx))/numel(idx);
            end
        end
    end
end

function contrib = GGP_LooIGDpContribution(PopObj,optimum)
% Leave-one-out IGD+ contribution of every row of PopObj.
%
% contrib(i) = IGDplus(PopObj without i) - IGDplus(PopObj)
%
% IGD+ is a min-over-population aggregate, so removing one solution can
% only leave each reference point's distance unchanged or make it worse;
% contrib is therefore >= 0. Computed from the full pairwise modified
% distance matrix, which makes the leave-one-out sweep a pair of column
% mins rather than N separate recomputations.

    [Nr,M] = size(optimum);
    N      = size(PopObj,1);

    % D(r,i): IGD+ modified distance from reference point r to solution i.
    D = zeros(Nr,N);
    for r = 1 : Nr
        diff   = max(PopObj - repmat(optimum(r,:),N,1),zeros(N,M));
        D(r,:) = sqrt(sum(diff.^2,2))';
    end

    if N == 1
        contrib = 0;
        return;
    end

    % Best and second best per reference point. Dropping solution i changes
    % that row's contribution only when i was the unique argmin, in which
    % case the row falls back to the second best.
    [sortedD,sortIdx] = sort(D,2);
    bestVal   = sortedD(:,1);
    secondVal = sortedD(:,2);
    bestIdx   = sortIdx(:,1);

    % For each i, sum over the reference rows it currently owns of the
    % penalty incurred by handing them to the runner-up. IGDplus without i
    % equals mean(bestVal) + penalty(i)/Nr, so the constant mean(bestVal)
    % cancels in the difference and never needs to be formed.
    penalty = zeros(N,1);
    delta   = secondVal - bestVal;
    for r = 1 : Nr
        penalty(bestIdx(r)) = penalty(bestIdx(r)) + delta(r);
    end

    contrib = penalty / Nr;
end
