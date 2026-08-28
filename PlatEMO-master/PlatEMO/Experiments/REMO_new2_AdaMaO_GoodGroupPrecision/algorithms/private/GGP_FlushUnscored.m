function rows = GGP_FlushUnscored(rows,pending)
% GGP_FlushUnscored - Record checkpoints whose window never closed.
%
% The last ggpWindow iterations of a run enqueue checkpoints that the budget
% never gets around to scoring. Dropping them silently would make the CSV
% row count disagree with the iteration count for no visible reason, so they
% are emitted with scored=false and NaN precisions. The analysis script
% filters on scored==1, so they never contaminate a statistic.

    if isempty(pending)
        return;
    end

    for d = 1 : numel(pending)
        row = struct();
        row.iter      = pending(d).iter;
        row.scoreIter = pending(d).scoreIter;
        row.FE        = pending(d).FE;
        row.ratio     = pending(d).ratio;
        row.N         = size(pending(d).snapObj,1);
        row.kTop      = numel(pending(d).groups.hybrid);
        row.scored    = false;

        row.chance_retained = NaN;
        row.chance_front    = NaN;
        row.chance_igdgain  = NaN;

        views  = {'v','anchor','hybrid'};
        truths = {'retained','front','igdgain'};
        for t = 1 : numel(truths)
            for s = 1 : numel(views)
                row.(sprintf('prec_%s_%s',views{s},truths{t})) = NaN;
            end
        end

        if isempty(rows)
            rows = row;
        else
            rows(end+1) = row; %#ok<AGROW>
        end
    end
end
