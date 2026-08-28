function outputs = analyze_CMCStage1(profile,varargin)
%ANALYZE_CMCSTAGE1 Analyze same-state counterfactual audit.
    if nargin < 1, profile = 'pilot'; end
    outputs = analyze_CandidateModeContribution('stage1',profile,varargin{:});
end
