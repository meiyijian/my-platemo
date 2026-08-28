function [rows,pending] = GGP_ScoreMatured(rows,pending,iter,Population,Archive,Problem,rGood)
% GGP_ScoreMatured - Score every pending checkpoint whose window has closed.
%
% A checkpoint recorded at iteration i is scored once the loop reaches
% iteration i + ggpWindow, so that the "was this nomination right" question
% is answered by search that happened strictly after the nomination.
%
% Scored checkpoints are removed from the pending queue, keeping its length
% bounded by ggpWindow rather than growing with the run.

    if isempty(pending)
        return;
    end

    due = find([pending.scoreIter] <= iter);
    if isempty(due)
        return;
    end

    for d = due
        row = GGP_ScoreCheckpoint(pending(d),Population,Archive,Problem,rGood);
        if isempty(rows)
            rows = row;
        else
            rows(end+1) = row; %#ok<AGROW>
        end
    end

    pending(due) = [];
end
