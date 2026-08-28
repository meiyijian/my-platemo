function adjusted = CMCHolmAdjust(raw,plannedCount)
%CMCHOLMADJUST Holm correction with an optional fixed planned family size.

    if nargin < 2 || isempty(plannedCount)
        plannedCount = nnz(isfinite(raw));
    end
    originalSize = size(raw);
    raw = raw(:);
    adjusted = NaN(size(raw));
    valid = find(isfinite(raw));
    if isempty(valid)
        adjusted = reshape(adjusted,originalSize);
        return;
    end
    [sorted,order] = sort(raw(valid));
    multipliers = (plannedCount:-1:plannedCount-numel(sorted)+1)';
    corrected = min(1,cummax(sorted.*multipliers));
    restored = NaN(numel(valid),1);
    restored(order) = corrected;
    adjusted(valid) = restored;
    adjusted = reshape(adjusted,originalSize);
end
