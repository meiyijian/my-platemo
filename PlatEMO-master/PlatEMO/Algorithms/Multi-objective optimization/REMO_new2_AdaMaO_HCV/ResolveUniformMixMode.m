function [mode,pInd] = ResolveUniformMixMode(indicatorAvailable,u,pMix)
%ResolveUniformMixMode Resolve the configured UniformMix candidate mode.

    if ~isscalar(pMix) || ~isnumeric(pMix) || ~isfinite(pMix) || ...
            pMix < 0 || pMix > 1
        error('AdaMaO:InvalidCandidateMixProbability', ...
            'pMix must be a finite scalar in [0,1].');
    end
    if ~isscalar(u) || ~isnumeric(u) || ~isfinite(u) || u < 0 || u >= 1
        error('AdaMaO:InvalidCandidateModeDraw', ...
            'The candidate-mode draw must be a finite scalar in [0,1).');
    end
    if ~isscalar(indicatorAvailable) || ~logical(indicatorAvailable)
        indicatorAvailable = false;
    end

    pInd = pMix;
    mode = 'explore';
    if indicatorAvailable && u < pMix
        mode = 'indicator';
    end
end
