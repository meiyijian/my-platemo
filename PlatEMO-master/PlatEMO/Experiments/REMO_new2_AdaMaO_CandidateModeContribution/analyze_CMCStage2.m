function outputs = analyze_CMCStage2(profile,varargin)
%ANALYZE_CMCSTAGE2 Analyze endpoint screening.
    if nargin < 1, profile = 'screening'; end
    outputs = analyze_CandidateModeContribution('stage2',profile,varargin{:});
end
