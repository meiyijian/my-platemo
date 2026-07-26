function probe = UpdateSDEConfidenceProbe( ...
    probe,generation,activeEvalIDs,currentNDEvalIDs,isFinal)
%UpdateSDEConfidenceProbe Fill observable horizons without uncensoring H3.

    if nargin < 5 || isempty(isFinal)
        isFinal = false;
    end
    validateProbe(probe,generation,activeEvalIDs,currentNDEvalIDs,isFinal);
    activeEvalIDs = activeEvalIDs(:);
    currentNDEvalIDs = currentNDEvalIDs(:);

    probe.solutionRows = updateSolutions( ...
        probe,probe.solutionRows,generation,activeEvalIDs, ...
        currentNDEvalIDs,isFinal);
    probe.pbiPairRows = updatePBIPairs( ...
        probe,probe.pbiPairRows,generation,activeEvalIDs, ...
        currentNDEvalIDs,isFinal);
    probe.networkPairRows = updateNetworkPairs( ...
        probe,probe.networkPairRows,generation,activeEvalIDs, ...
        currentNDEvalIDs,isFinal);
    probe.candidateRows = updateCandidates( ...
        probe,probe.candidateRows,generation,activeEvalIDs, ...
        currentNDEvalIDs,isFinal);
end

function rows = updateSolutions(probe,rows,generation,activeIDs,finalIDs,isFinal)
    generationColumn = col(probe,'solutionRows','Generation');
    evalColumn = col(probe,'solutionRows','EvalID');
    h1 = rows(:,generationColumn) == generation;
    rows(h1,col(probe,'solutionRows','SurviveH1')) = ...
        double(ismember(rows(h1,evalColumn),activeIDs));
    h3 = rows(:,generationColumn) == generation-2;
    rows(h3,col(probe,'solutionRows','SurviveH3')) = ...
        double(ismember(rows(h3,evalColumn),activeIDs));
    if isFinal
        rows(:,col(probe,'solutionRows','FinalND')) = ...
            double(ismember(rows(:,evalColumn),finalIDs));
    end
end

function rows = updatePBIPairs(probe,rows,generation,activeIDs,finalIDs,isFinal)
    generationColumn = col(probe,'pbiPairRows','Generation');
    leftID = col(probe,'pbiPairRows','LeftEvalID');
    rightID = col(probe,'pbiPairRows','RightEvalID');
    h1 = rows(:,generationColumn) == generation;
    rows(h1,col(probe,'pbiPairRows','LeftSurviveH1')) = ...
        double(ismember(rows(h1,leftID),activeIDs));
    rows(h1,col(probe,'pbiPairRows','RightSurviveH1')) = ...
        double(ismember(rows(h1,rightID),activeIDs));
    h3 = rows(:,generationColumn) == generation-2;
    rows(h3,col(probe,'pbiPairRows','LeftSurviveH3')) = ...
        double(ismember(rows(h3,leftID),activeIDs));
    rows(h3,col(probe,'pbiPairRows','RightSurviveH3')) = ...
        double(ismember(rows(h3,rightID),activeIDs));
    if isFinal
        rows(:,col(probe,'pbiPairRows','LeftFinalND')) = ...
            double(ismember(rows(:,leftID),finalIDs));
        rows(:,col(probe,'pbiPairRows','RightFinalND')) = ...
            double(ismember(rows(:,rightID),finalIDs));
    end
end

function rows = updateNetworkPairs( ...
    probe,rows,generation,activeIDs,finalIDs,isFinal)
    generationColumn = col(probe,'networkPairRows','Generation');
    evalColumn = col(probe,'networkPairRows','CandidateEvalID');
    h1 = rows(:,generationColumn) == generation;
    rows(h1,col(probe,'networkPairRows','CandidateSurviveH1')) = ...
        double(ismember(rows(h1,evalColumn),activeIDs));
    h3 = rows(:,generationColumn) == generation-2;
    rows(h3,col(probe,'networkPairRows','CandidateSurviveH3')) = ...
        double(ismember(rows(h3,evalColumn),activeIDs));
    if isFinal
        rows(:,col(probe,'networkPairRows','CandidateFinalND')) = ...
            double(ismember(rows(:,evalColumn),finalIDs));
    end
end

function rows = updateCandidates( ...
    probe,rows,generation,activeIDs,currentNDIDs,isFinal)
    generationColumn = col(probe,'candidateRows','Generation');
    evalColumn = col(probe,'candidateRows','EvalID');
    h1 = rows(:,generationColumn) == generation;
    rows(h1,col(probe,'candidateRows','SurviveH1')) = ...
        double(ismember(rows(h1,evalColumn),activeIDs));
    rows(h1,col(probe,'candidateRows','ArchiveNDNext')) = ...
        double(ismember(rows(h1,evalColumn),currentNDIDs));
    h3 = rows(:,generationColumn) == generation-2;
    rows(h3,col(probe,'candidateRows','SurviveH3')) = ...
        double(ismember(rows(h3,evalColumn),activeIDs));
    if isFinal
        rows(:,col(probe,'candidateRows','FinalND')) = ...
            double(ismember(rows(:,evalColumn),currentNDIDs));
    end
end

function validateProbe(probe,generation,activeIDs,currentNDIDs,isFinal)
    template = SDEConfidenceProbeSchema();
    tableNames = fieldnames(template.columns);
    valid = isstruct(probe) && isscalar(probe) && ...
        isfield(probe,'version') && probe.version == template.version && ...
        isfield(probe,'columns');
    for i = 1:numel(tableNames)
        name = tableNames{i};
        valid = valid && isfield(probe,name) && isnumeric(probe.(name)) && ...
            size(probe.(name),2) == numel(template.columns.(name)) && ...
            isfield(probe.columns,name) && ...
            isequal(probe.columns.(name),template.columns.(name));
    end
    validActiveIDs = validPositiveIntegerIDs(activeIDs);
    validCurrentNDIDs = validPositiveIntegerIDs(currentNDIDs);
    valid = valid && isnumeric(generation) && isreal(generation) && ...
        isscalar(generation) && isfinite(generation) && generation >= 1 && ...
        generation == floor(generation) && validActiveIDs && ...
        validCurrentNDIDs && islogical(isFinal) && isscalar(isFinal);
    if ~valid
        error('AdaMaO:InvalidConfidenceProbeUpdate', ...
            'Probe schema or horizon update inputs are invalid.');
    end
end

function valid = validPositiveIntegerIDs(ids)
    valid = isnumeric(ids) && isreal(ids) && ...
        (isempty(ids) || isvector(ids)) && all(isfinite(ids(:))) && ...
        all(ids(:) > 0) && all(ids(:) == floor(ids(:))) && ...
        numel(unique(ids(:))) == numel(ids);
end

function index = col(probe,rowName,columnName)
    index = find(strcmp(probe.columns.(rowName),columnName),1);
end
