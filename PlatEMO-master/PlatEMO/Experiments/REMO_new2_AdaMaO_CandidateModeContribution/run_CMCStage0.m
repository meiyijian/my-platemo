function manifest = run_CMCStage0(profile,varargin)
%RUN_CMCSTAGE0 Run behavioral activity audit.
    if nargin < 1, profile = 'pilot'; end
    manifest = run_CandidateModeContribution('stage0',profile,varargin{:});
end
