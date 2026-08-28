function manifest = run_CMCStage1(profile,varargin)
%RUN_CMCSTAGE1 Run same-state counterfactual audit.
    if nargin < 1, profile = 'pilot'; end
    manifest = run_CandidateModeContribution('stage1',profile,varargin{:});
end
