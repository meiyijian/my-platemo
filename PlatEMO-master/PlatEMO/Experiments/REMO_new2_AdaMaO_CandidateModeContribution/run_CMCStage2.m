function manifest = run_CMCStage2(profile,varargin)
%RUN_CMCSTAGE2 Run paired endpoint screening.
    if nargin < 1, profile = 'screening'; end
    manifest = run_CandidateModeContribution('stage2',profile,varargin{:});
end
