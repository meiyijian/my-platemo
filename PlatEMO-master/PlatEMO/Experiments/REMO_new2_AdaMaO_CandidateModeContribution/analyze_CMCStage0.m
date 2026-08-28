function outputs = analyze_CMCStage0(profile,varargin)
%ANALYZE_CMCSTAGE0 Analyze behavioral activity audit.
    if nargin < 1, profile = 'pilot'; end
    outputs = analyze_CandidateModeContribution('stage0',profile,varargin{:});
end
