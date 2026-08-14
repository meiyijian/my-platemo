function rows = ComputeLabelOverlapMetrics(catalogs, scores)
%ComputeLabelOverlapMetrics Pairwise overlap among single-valued variants.
%   rows = ComputeLabelOverlapMetrics(catalogs, scores) computes, for every
%   unordered pair of the SINGLE-valued variants (L0..L5, L7, L8; L6 is
%   excluded because it is a 100-replicate distribution handled by the
%   shuffle envelope), the fixed overlap/divergence set statistics.
%
%   catalogs: struct with fields L0..L8 (N x R logical; L6 ignored here)
%   scores:   struct with fields L0..L8 (N x R double; L6 ignored here)
%
%   Each output row (struct array):
%     VariantA, VariantB          - names 'L1', ...
%     Jaccard, IntersectionCount, UnionCount
%     SpearmanScore               - NaN when either side is binary (L0)
%     CatalogAgreement            - mean(catalogA == catalogB)
%     AOnlyCount, BOnlyCount      - symmetric difference counts

    rows = struct('VariantA',{},'VariantB',{},'Replicate',{}, ...
        'Jaccard',{},'IntersectionCount',{},'UnionCount',{}, ...
        'SpearmanScore',{},'CatalogAgreement',{}, ...
        'AOnlyCount',{},'BOnlyCount',{});

    names = {'L0','L1','L2','L3','L4','L5','L7','L8'};
    for i = 1:numel(names)
        for j = i+1:numel(names)
            A = names{i};
            B = names{j};
            catA = logical(catalogs.(A)(:,1));
            catB = logical(catalogs.(B)(:,1));
            inter = sum(catA & catB);
            uni   = sum(catA | catB);
            jac   = inter / max(uni,1);

            scA = scores.(A)(:,1);
            scB = scores.(B)(:,1);
            % L0 is binary: no internal ranking -> Spearman NaN is legal
            if strcmp(A,'L0') || strcmp(B,'L0')
                sp = NaN;
            elseif std(scA)==0 || std(scB)==0
                sp = NaN;
            else
                sp = corr(scA,scB,'Type','Spearman');
            end

            row = struct( ...
                'VariantA',A,'VariantB',B,'Replicate',0, ...
                'Jaccard',jac,'IntersectionCount',inter,'UnionCount',uni, ...
                'SpearmanScore',sp,'CatalogAgreement',mean(catA==catB), ...
                'AOnlyCount',sum(catA & ~catB),'BOnlyCount',sum(~catA & catB));
            if isempty(rows)
                rows = row;
            else
                rows(end+1) = row; %#ok<AGROW>
            end
        end
    end
end
