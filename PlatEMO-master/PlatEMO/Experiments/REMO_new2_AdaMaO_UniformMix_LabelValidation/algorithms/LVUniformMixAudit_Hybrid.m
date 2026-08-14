classdef LVUniformMixAudit_Hybrid < LVUniformMixAuditBase
%LVUniformMixAudit_Hybrid Audit entry with the frozen hybrid behavior.
%   Training catalog = views.CatalogCurrent (topQ of alpha*ScoreV +
%   (1-alpha)*LabelDyn). The optimization trajectory must be identical to
%   the frozen REMO_new2_AdaMaO_SDEOnly_UniformMix_Original up to
%   floating-point round-off.

    methods
        function Catalog = selectTrainingCatalog(obj, views) %#ok<INUSL>
            Catalog = views.CatalogCurrent;
        end
    end
end
