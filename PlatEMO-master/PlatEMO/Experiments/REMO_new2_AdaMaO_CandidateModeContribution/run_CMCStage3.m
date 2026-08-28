function manifest = run_CMCStage3(profile,varargin)
%RUN_CMCSTAGE3 Run independent formal validation.
    if nargin < 1, profile = 'formal'; end
    manifest = run_CandidateModeContribution('stage3',profile,varargin{:});
end
