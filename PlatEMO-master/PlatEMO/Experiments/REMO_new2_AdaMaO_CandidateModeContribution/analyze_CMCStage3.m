function outputs = analyze_CMCStage3(profile,varargin)
%ANALYZE_CMCSTAGE3 Analyze independent formal validation.
    if nargin < 1, profile = 'formal'; end
    outputs = analyze_CandidateModeContribution('stage3',profile,varargin{:});
end
