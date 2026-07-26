function bins = AssignConfidenceProbeBins(values,strata,binCount)
%ASSIGNCONFIDENCEPROBEBINS Stable balanced quantile bins within strata.
%   Ties are ordered by original row index. No random numbers are used.

    if nargin < 3 || isempty(binCount)
        binCount = 5;
    end
    if ~(isnumeric(values) && isvector(values))
        error('AdaMaO:InvalidConfidenceValues', ...
            'values must be a numeric vector.');
    end
    values = values(:);
    if any(~isfinite(values))
        error('AdaMaO:InvalidConfidenceValues', ...
            'values must contain only finite values.');
    end
    if ~(isnumeric(binCount) && isscalar(binCount) && ...
            isfinite(binCount) && binCount >= 1 && ...
            binCount == floor(binCount))
        error('AdaMaO:InvalidConfidenceBinCount', ...
            'binCount must be a positive integer scalar.');
    end

    strataTable = normalizeStrata(strata,numel(values));
    group = findgroups(strataTable);
    bins = zeros(numel(values),1);
    for groupIndex = 1:max(group)
        rows = find(group == groupIndex);
        [~,order] = sortrows([values(rows),rows],[1,2]);
        sortedRows = rows(order);
        count = numel(sortedRows);
        if count >= binCount
            baseSize = floor(count/binCount);
            extra = mod(count,binCount);
            sizes = baseSize*ones(1,binCount);
            sizes(1:extra) = sizes(1:extra) + 1;
            first = 1;
            for bin = 1:binCount
                last = first + sizes(bin) - 1;
                bins(sortedRows(first:last)) = bin;
                first = last + 1;
            end
        elseif count == 1
            bins(sortedRows) = 3;
        else
            sparseBins = round(linspace(1,binCount,count));
            bins(sortedRows) = sparseBins(:);
        end
    end
end

function strataTable = normalizeStrata(strata,rowCount)
    if istable(strata)
        strataTable = strata;
    elseif isvector(strata)
        strataTable = table(strata(:),'VariableNames',{'Stratum'});
    elseif isnumeric(strata) || islogical(strata) || isstring(strata) || ...
            iscategorical(strata)
        strataTable = array2table(strata);
    elseif iscell(strata)
        strataTable = cell2table(strata);
    else
        error('AdaMaO:InvalidConfidenceStrata', ...
            'strata must be a table or row-aligned array.');
    end
    if height(strataTable) ~= rowCount
        error('AdaMaO:InvalidConfidenceStrata', ...
            'strata must have one row per confidence value.');
    end
end
