function value = CMCComparePaired(a,b)
%CMCCOMPAREPAIRED Summarize paired A-minus-B effects.

    a = a(:); b = b(:);
    valid = isfinite(a) & isfinite(b);
    a = a(valid); b = b(valid);
    difference = a-b;
    value = struct('NumberOfPairs',numel(difference),'MeanA',NaN, ...
        'MeanB',NaN,'MeanDelta',NaN,'MedianDelta',NaN, ...
        'HodgesLehmann',NaN,'PValueRaw',NaN,'RankBiserial',NaN, ...
        'PairedWinProbability',NaN);
    if isempty(difference)
        return;
    end
    value.MeanA = mean(a);
    value.MeanB = mean(b);
    value.MeanDelta = mean(difference);
    value.MedianDelta = median(difference);
    pairAverages = (difference+difference')/2;
    value.HodgesLehmann = median(pairAverages(triu(true(size(pairAverages)))));
    value.PairedWinProbability = ...
        (nnz(difference>0)+0.5*nnz(difference==0))/numel(difference);
    nonzero = difference ~= 0;
    if any(nonzero)
        ranks = tiedrank(abs(difference(nonzero)));
        signed = difference(nonzero);
        positive = sum(ranks(signed>0));
        negative = sum(ranks(signed<0));
        value.RankBiserial = (positive-negative)/(positive+negative);
    else
        value.RankBiserial = 0;
    end
    if numel(difference) >= 2
        if all(difference == 0)
            value.PValueRaw = 1;
        else
            value.PValueRaw = signrank(a,b);
        end
    end
end
