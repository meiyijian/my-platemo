classdef LVUniformMixAudit_AnchorNative < LVUniformMixAuditBase
%LVUniformMixAudit_AnchorNative Same-runtime anchor-label baseline.
%   Training catalog = logical(LabelDyn), the original reference-solution
%   binary labels whose positive rate is set by the adaptive delta
%   (target 0.30-0.70). Everything else - initialization, RefSelect,
%   relation-pair generation, the unweighted relation network, SDE model,
%   UniformMix mode stream, candidate generation, real evaluation counts
%   and environmental selection - is identical to the Hybrid audit entry.
%   ScoreV is still computed (but not used as the catalog), so the
%   K-means call and random-number consumption match Hybrid exactly.

    methods
        function Catalog = selectTrainingCatalog(obj, views) %#ok<INUSL>
            Catalog = logical(views.LabelDyn);
        end
    end
end
