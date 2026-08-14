function rows = ComputeLabelPerturbationStability(snap, meta, catalogs, scores)
%ComputeLabelPerturbationStability Drop-point stability for L1,L2,L3,L7,L8.
%   rows = ComputeLabelPerturbationStability(snap, meta, catalogs, scores)
%   performs 5% and 10% solution-drop stability, 100 replicates each, for
%   variants L1, L2, L3, L7 and L8. All random draws use the offline seed
%   rule (snapshotSeed + variantCode*100 + replicate) and restore the
%   global RNG afterwards.
%
%   For each replicate the comparison is done only on retained solutions:
%     - RetainedJaccard: Jaccard between the original TopQ restricted to
%       the retained set and the TopQ recomputed on the retained set.
%     - RetainedRankSpearman: Spearman between the original scores of
%       retained solutions and their ranks in the recomputed selection.
%     - DirectionSourceAfterDrop: the direction source used after dropping
%       (L7 -> 2 uniform; L8 -> recomputed; others -> snapshot source).
%
%   Output: struct array with fields
%     VariantName, DropFraction, Replicate,
%     RetainedJaccard, RetainedRankSpearman, DirectionSourceAfterDrop

    rows = struct('VariantName',{},'DropFraction',{},'Replicate',{}, ...
        'RetainedJaccard',{},'RetainedRankSpearman',{}, ...
        'DirectionSourceAfterDrop',{});

    N = numel(snap.PopulationEvalID);
    M = meta.M;
    theta  = snap.Theta;
    ratio  = snap.Ratio;
    kEff   = snap.kEff;
    rGood  = meta.rGood;
    Nref   = snap.Nref;
    PopObj = snap.PopulationObj;
    labelDyn = logical(snap.LabelDyn(:));
    scoreV   = double(snap.ScoreV(:));
    anchorG  = double(snap.AnchorNormalizedG(:));

    snapshotSeed = meta.seed*1000 + snap.SnapshotID;

    variantNames = {'L1','L2','L3','L7','L8'};
    dropFractions = [0.05, 0.10];

    for v = 1:numel(variantNames)
        vname = variantNames{v};
        code  = find(strcmp({ 'L0','L1','L2','L3','L4','L5','L6','L7','L8'},vname)) - 1;
        baseScore = scores.(vname)(:,1);   % N x 1 original score
        for f = 1:numel(dropFractions)
            dropFrac = dropFractions(f);
            nRetain  = round(N * (1 - dropFrac));
            kRetain  = ceil(nRetain * rGood);
            for r = 1:100
                offSeed = snapshotSeed + code*100 + r;
                saved   = rng;
                rng(offSeed,'twister');
                retainIdx = sort(randperm(N, nRetain));
                rng(saved);

                % original TopQ restricted to retained set
                origCat = logical(catalogs.(vname)(:,1));
                origRet = origCat(retainIdx);

                % recompute score on retained solutions
                switch vname
                    case 'L1'
                        scRet = 1 - anchorG(retainIdx);
                    case 'L2'
                        scRet = scoreV(retainIdx);
                    case 'L3'
                        scRet = (1-ratio)*scoreV(retainIdx) + ratio*double(labelDyn(retainIdx));
                    case 'L7'
                        scRet = ComputeUniformDirectionScore( ...
                            PopObj(retainIdx,:), theta, Nref);
                    case 'L8'
                        scRet = ComputeReducedNDDirectionScore( ...
                            PopObj(retainIdx,:), kEff, theta, offSeed);
                    otherwise
                        error('ComputePerturbation:BadVariant','%s',vname);
                end
                [newCat, ~] = LVTopQDeterministic(scRet, rGood);
                newCat = logical(newCat);

                % direction source after drop
                switch vname
                    case 'L7'
                        dsAfter = 2;
                    case 'L8'
                        % recompute direction source only (cheap wrapper)
                        [~,~,~,dsAfter] = ComputeReducedNDDirectionScore( ...
                            PopObj(retainIdx,:), kEff, theta, offSeed);
                    otherwise
                        dsAfter = snap.DirectionSource;
                end

                % Jaccard on retained set (both restricted to retainIdx)
                inter = sum(origRet & newCat);
                uni   = sum(origRet | newCat);
                jac   = inter / max(uni,1);

                % rank spearman: original retained scores vs recomputed
                if std(baseScore(retainIdx))==0 || std(scRet)==0
                    sp = NaN;
                else
                    sp = corr(baseScore(retainIdx), scRet, 'Type','Spearman');
                end

                row = struct( ...
                    'VariantName',vname,'DropFraction',dropFrac, ...
                    'Replicate',r,'RetainedJaccard',jac, ...
                    'RetainedRankSpearman',sp, ...
                    'DirectionSourceAfterDrop',dsAfter);
                if isempty(rows)
                    rows = row;
                else
                    rows(end+1) = row; %#ok<AGROW>
                end
            end
        end
    end
end
