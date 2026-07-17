function [mode,pInd,progress] = ResolveSDECandidateMode( ...
    policy,indicatorAvailable,FE,InitFE,maxFE,u)
%ResolveSDECandidateMode Resolve an SDE candidate-selection policy.
%   The mode progress excludes the evaluations consumed by initialization.

    if isstring(policy) && isscalar(policy)
        policy = char(policy);
    end
    if ~ischar(policy) || ~isrow(policy)
        error('AdaMaO:UnknownCandidatePolicy', ...
            'Candidate policy must be a character vector or scalar string.');
    end
    policy = lower(strtrim(policy));

    if maxFE <= InitFE
        progress = 1;
    else
        progress = (FE-InitFE)/(maxFE-InitFE);
        progress = min(1,max(0,progress));
    end

    isRandomPolicy = false;
    switch policy
        case 'always_explore'
            pInd = 0;
        case 'always_indicator'
            pInd = 1;
        case 'uniform_mix'
            pInd = 0.5;
            isRandomPolicy = true;
        case 'linear_schedule'
            pInd = progress;
            isRandomPolicy = true;
        otherwise
            error('AdaMaO:UnknownCandidatePolicy', ...
                'Unknown candidate policy: %s',policy);
    end

    if isRandomPolicy && (~isscalar(u) || ~isnumeric(u) || ...
            ~isfinite(u) || u < 0 || u >= 1)
        error('AdaMaO:InvalidCandidateModeDraw', ...
            'The candidate-mode draw must be a finite scalar in [0,1).');
    end

    mode = 'explore';
    if ~isscalar(indicatorAvailable) || ~logical(indicatorAvailable)
        return;
    end

    switch policy
        case 'always_indicator'
            mode = 'indicator';
        case {'uniform_mix','linear_schedule'}
            if u < pInd
                mode = 'indicator';
            end
    end
end
