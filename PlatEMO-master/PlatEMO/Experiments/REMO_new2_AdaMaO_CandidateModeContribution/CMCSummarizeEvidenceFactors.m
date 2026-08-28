function [qualified,dropped,assessed] = ...
        CMCSummarizeEvidenceFactors(armDecision)
%CMCSUMMARIZEEVIDENCEFACTORS Aggregate arm evidence at the factor level.
%   A factor is qualified only when every preregistered evidence arm for
%   that factor is present and qualified. In particular, G requires both
%   route controls. Candidate, module-control, and external-anchor rows are
%   not factor evidence.

    qualified = strings(0,1);
    dropped = strings(0,1);
    assessed = strings(0,1);
    if ~istable(armDecision) || isempty(armDecision) || ...
            ~all(ismember(["Arm","Qualified"], ...
            string(armDecision.Properties.VariableNames)))
        return;
    end
    catalog = CMCArmCatalog();
    evidenceRoles = ["drop_one","negative_control","route_control"];
    evidence = catalog(ismember(catalog.Role,evidenceRoles),:);
    assessed = unique(evidence.Factor( ...
        ismember(evidence.Arm,armDecision.Arm)),'stable');
    for index = 1:numel(assessed)
        factor = assessed(index);
        required = evidence.Arm(evidence.Factor == factor);
        rows = armDecision(ismember(armDecision.Arm,required),:);
        if height(rows) == numel(required) && all(rows.Qualified)
            qualified(end+1,1) = factor; %#ok<AGROW>
        else
            dropped(end+1,1) = factor; %#ok<AGROW>
        end
    end
end
