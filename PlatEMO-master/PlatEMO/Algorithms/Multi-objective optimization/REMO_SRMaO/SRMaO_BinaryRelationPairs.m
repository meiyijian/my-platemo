function [XXs, Ls, Ws] = SRMaO_BinaryRelationPairs(Input, Catalog, confidence)
% Build weighted binary preference pairs.
%
% Label 1 means the first solution is preferred to the second solution;
% label 0 means the reverse ordering.

    Catalog    = logical(Catalog(:));
    confidence = confidence(:);
    if isempty(confidence)
        confidence = ones(size(Catalog));
    end

    G = find(Catalog);
    B = find(~Catalog);
    if isempty(G) || isempty(B)
        XXs = [];
        Ls  = [];
        Ws  = [];
        return;
    end

    [Ggrid,Bgrid] = meshgrid(G,B);
    Ggrid = Ggrid(:);
    Bgrid = Bgrid(:);

    XXsGB = [Input(Ggrid,:),Input(Bgrid,:)];
    XXsBG = [Input(Bgrid,:),Input(Ggrid,:)];
    LsGB  = ones(size(XXsGB,1),1);
    LsBG  = zeros(size(XXsBG,1),1);

    pairW = sqrt(max(confidence(Ggrid),0) .* max(confidence(Bgrid),0));
    pairW = max(0.20,pairW);

    XXs = [XXsGB;XXsBG];
    Ls  = [LsGB;LsBG];
    Ws  = [pairW;pairW];

    rp  = randperm(size(XXs,1));
    XXs = XXs(rp,:);
    Ls  = Ls(rp);
    Ws  = Ws(rp);
end
