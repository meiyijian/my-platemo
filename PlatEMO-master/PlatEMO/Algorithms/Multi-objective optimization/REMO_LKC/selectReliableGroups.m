function [S_easy_group, EasyAggObj] = selectReliableGroups(StructState, minRel)
% selectReliableGroups - Pure reliability-based group selection for the
% sub-network of REMO_LKC.
%
% Keeps ALL groups whose GroupReliability >= minRel and feeds their
% aggregated objectives to the sub-network.  No difficulty ranking,
% downgrading, or redundancy pruning is performed: group selection here is
% driven purely by structural reliability.
%
% Inputs:
%   StructState - struct from BuildObjectiveStructure_LKC, must contain
%                 fields GroupReliability (1xK) and AggregatedObj (NxK).
%   minRel      - minimum group reliability threshold.
%
% Outputs:
%   S_easy_group - 1xG vector of selected group indices (G <= K).
%   EasyAggObj   - NxG aggregated objective matrix for the sub-network.

    if isempty(StructState) || ~isstruct(StructState) ...
            || ~isfield(StructState, 'GroupReliability') ...
            || ~isfield(StructState, 'AggregatedObj')
        S_easy_group = [];
        EasyAggObj = [];
        return;
    end

    reliability = StructState.GroupReliability(:)';
    if isempty(reliability) || isempty(StructState.AggregatedObj)
        S_easy_group = [];
        EasyAggObj = [];
        return;
    end

    selected = find(reliability >= minRel);
    if isempty(selected)
        % Fallback: keep the single most reliable group so the sub-network
        % always has data to train on.
        [~, idx] = max(reliability);
        selected = idx;
    end
    selected = selected(:)';

    S_easy_group = selected;
    EasyAggObj = StructState.AggregatedObj(:, selected);
end
