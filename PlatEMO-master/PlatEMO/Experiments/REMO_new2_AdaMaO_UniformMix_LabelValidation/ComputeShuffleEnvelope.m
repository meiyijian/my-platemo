function rows = ComputeShuffleEnvelope(catalogs)
%ComputeShuffleEnvelope L3-vs-L6 Jaccard for the permutation envelope.
%   rows = ComputeShuffleEnvelope(catalogs) computes, for each of the 100
%   L6 replicates, the TopQ Jaccard between L3 (current hybrid catalog)
%   and the shuffled hybrid catalog. The 100 values per snapshot form the
%   permutation envelope (mean + 2.5%/97.5% quantiles) used to test
%   whether the score-to-solution correspondence creates non-random
%   structure (Stage 2 analysis item 4).
%
%   Output rows (struct array):
%     VariantA='L3', VariantB='L6', Replicate=1..100,
%     Jaccard, IntersectionCount, UnionCount,
%     SpearmanScore=NaN (L6 scores are re-shuffled), CatalogAgreement,
%     AOnlyCount, BOnlyCount

    rows = struct('VariantA',{},'VariantB',{},'Replicate',{}, ...
        'Jaccard',{},'IntersectionCount',{},'UnionCount',{}, ...
        'SpearmanScore',{},'CatalogAgreement',{}, ...
        'AOnlyCount',{},'BOnlyCount',{});

    cat3 = logical(catalogs.L3(:,1));
    cat6 = logical(catalogs.L6);   % N x 100
    R = size(cat6,2);
    for r = 1:R
        c6 = cat6(:,r);
        inter = sum(cat3 & c6);
        uni   = sum(cat3 | c6);
        row = struct('VariantA','L3','VariantB','L6','Replicate',r, ...
            'Jaccard',inter/max(uni,1), ...
            'IntersectionCount',inter,'UnionCount',uni, ...
            'SpearmanScore',NaN, ...
            'CatalogAgreement',mean(cat3==c6), ...
            'AOnlyCount',sum(cat3 & ~c6),'BOnlyCount',sum(~cat3 & c6));
        if isempty(rows)
            rows = row;
        else
            rows(end+1) = row; %#ok<AGROW>
        end
    end
end
