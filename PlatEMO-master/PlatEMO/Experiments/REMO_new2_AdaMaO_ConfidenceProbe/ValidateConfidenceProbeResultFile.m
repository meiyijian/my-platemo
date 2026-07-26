function [valid,message,metrics] = ValidateConfidenceProbeResultFile( ...
    resultFile,protocol,job)
%VALIDATECONFIDENCEPROBERESULTFILE Validate a resumable probe run.
%   Invalid existing files are deliberately not overwritten by the runner.

    valid = false;
    metrics = struct('IGD',nan,'IGDp',nan,'runtime',nan);
    if ~isfile(resultFile)
        message = 'result file does not exist';
        return;
    end

    try
        variables = whos('-file',resultFile);
        variableNames = {variables.name};
        required = {'metadata','confidenceProbe','finalPopulation', ...
            'IGD','IGDp','runtime'};
        missing = required(~ismember(required,variableNames));
        if ~isempty(missing)
            message = sprintf('missing variable(s): %s', ...
                strjoin(missing,', '));
            return;
        end
        loaded = load(resultFile,required{:});
    catch exception
        message = sprintf('unreadable MAT file: %s',exception.message);
        return;
    end

    [ok,message] = validateMetadata(loaded.metadata,protocol,job);
    if ~ok
        return;
    end
    [ok,message] = validateProbe( ...
        loaded.confidenceProbe,loaded.metadata.maxFE);
    if ~ok
        return;
    end
    [ok,message] = validateFinalPopulation( ...
        loaded.finalPopulation,loaded.metadata.maxFE);
    if ~ok
        return;
    end

    metricNames = {'IGD','IGDp','runtime'};
    for i = 1:numel(metricNames)
        name = metricNames{i};
        value = loaded.(name);
        if ~(isnumeric(value) && isreal(value) && isscalar(value) && ...
                isfinite(value) && value >= 0)
            message = sprintf( ...
                '%s must be a finite nonnegative numeric scalar',name);
            return;
        end
        metrics.(name) = double(value);
    end
    valid = true;
end

function [valid,message] = validateMetadata(metadata,protocol,job)
    valid = false;
    message = '';
    if ~(isstruct(metadata) && isscalar(metadata))
        message = 'metadata is not a scalar struct';
        return;
    end
    expected = struct( ...
        'schemaVersion',protocol.schemaVersion, ...
        'profile',protocol.profile, ...
        'problem',char(job.Problem), ...
        'M',job.M, ...
        'requestedD',job.RequestedD, ...
        'actualD',job.ActualD, ...
        'N',job.N, ...
        'maxFE',job.MaxFE, ...
        'completedFE',job.MaxFE, ...
        'gmax',job.Gmax, ...
        'run',job.Run, ...
        'seed',job.Seed, ...
        'algorithmLabel',char(job.Algorithm), ...
        'algorithmClass',char(job.AlgorithmClass), ...
        'jobID',char(job.JobID));
    names = fieldnames(expected);
    for i = 1:numel(names)
        name = names{i};
        if ~isfield(metadata,name)
            message = sprintf('metadata missing field %s',name);
            return;
        end
        if ~sameScalar(metadata.(name),expected.(name))
            message = sprintf( ...
                'metadata field %s does not match current job',name);
            return;
        end
    end
    if metadata.completedFE ~= metadata.maxFE
        message = 'metadata completedFE does not equal maxFE';
        return;
    end
    valid = true;
end

function [valid,message] = validateProbe(probe,maxFE)
    valid = false;
    if ~(isstruct(probe) && isscalar(probe))
        message = 'confidenceProbe is not a scalar struct';
        return;
    end
    schema = SDEConfidenceProbeSchema();
    if ~isfield(probe,'version') || ~sameScalar(probe.version,1)
        message = 'confidenceProbe schema version must be 1';
        return;
    end
    if ~isfield(probe,'columns') || ~isstruct(probe.columns)
        message = 'confidenceProbe is missing columns';
        return;
    end

    tableNames = fieldnames(schema.columns);
    for i = 1:numel(tableNames)
        tableName = tableNames{i};
        if ~isfield(probe.columns,tableName) || ...
                ~isequal(probe.columns.(tableName), ...
                schema.columns.(tableName))
            message = sprintf( ...
                '%s column schema does not match version 1',tableName);
            return;
        end
        if ~isfield(probe,tableName)
            message = sprintf('confidenceProbe missing %s',tableName);
            return;
        end
        rows = probe.(tableName);
        if ~(isnumeric(rows) && isreal(rows) && ismatrix(rows) && ...
                size(rows,2) == numel(schema.columns.(tableName)))
            message = sprintf( ...
                '%s must be a real numeric matrix with %d columns', ...
                tableName,numel(schema.columns.(tableName)));
            return;
        end
        if isempty(rows)
            message = sprintf('%s is empty',tableName);
            return;
        end
    end

    rangeColumns = { ...
        'solutionRows',{'PBIConfidence'}; ...
        'pbiPairRows',{'PairConfidence'}; ...
        'networkPairRows',{'ProbabilityLeftBetter', ...
            'ProbabilitySame','ProbabilityRightBetter', ...
            'NetworkConfidence'}; ...
        'candidateRows',{'NetworkConfidence','PredictedBetterRate'}};
    for i = 1:size(rangeColumns,1)
        tableName = rangeColumns{i,1};
        rows = probe.(tableName);
        for j = 1:numel(rangeColumns{i,2})
            name = rangeColumns{i,2}{j};
            values = rows(:,column(schema,tableName,name));
            if any(~isfinite(values) | values < 0 | values > 1)
                message = sprintf( ...
                    '%s.%s must be finite and in [0,1]', ...
                    tableName,name);
                return;
            end
        end
    end

    probabilities = probe.networkPairRows(:, ...
        column(schema,'networkPairRows',{ ...
        'ProbabilityLeftBetter','ProbabilitySame', ...
        'ProbabilityRightBetter'}));
    if any(abs(sum(probabilities,2)-1) > 1e-8)
        message = 'network pair probabilities must sum to one';
        return;
    end
    [maximumProbability,classIndex] = max(probabilities,[],2);
    relationCodes = [1;0;-1];
    expectedRelation = relationCodes(classIndex);
    predictedRelation = probe.networkPairRows(:, ...
        column(schema,'networkPairRows','PredictedRelation'));
    if any(predictedRelation ~= expectedRelation)
        message = [ ...
            'networkPairRows.PredictedRelation must match the ', ...
            'probability argmax'];
        return;
    end
    networkConfidence = probe.networkPairRows(:, ...
        column(schema,'networkPairRows','NetworkConfidence'));
    if any(abs(networkConfidence-maximumProbability) > 1e-10)
        message = [ ...
            'networkPairRows.NetworkConfidence must equal the ', ...
            'maximum class probability'];
        return;
    end

    idColumns = { ...
        'solutionRows',{'EvalID'}; ...
        'pbiPairRows',{'LeftEvalID','RightEvalID'}; ...
        'networkPairRows',{'CandidateEvalID','AnchorEvalID'}; ...
        'candidateRows',{'EvalID'}};
    for i = 1:size(idColumns,1)
        tableName = idColumns{i,1};
        rows = probe.(tableName);
        for j = 1:numel(idColumns{i,2})
            values = rows(:,column(schema,tableName,idColumns{i,2}{j}));
            if any(~isfinite(values) | values <= 0 | ...
                    values ~= floor(values) | values > maxFE)
                message = sprintf('%s.%s contains invalid EvalID values', ...
                    tableName,idColumns{i,2}{j});
                return;
            end
        end
    end
    [valid,message] = validateDiscreteProbeColumns(probe,schema,maxFE);
    if ~valid
        return;
    end
    valid = true;
end

function [valid,message] = validateDiscreteProbeColumns(probe,schema,maxFE)
    valid = false;
    message = '';
    tableNames = fieldnames(schema.columns);
    for i = 1:numel(tableNames)
        name = tableNames{i};
        rows = probe.(name);
        generation = rows(:,column(schema,name,'Generation'));
        fe = rows(:,column(schema,name,'FE'));
        if any(~isfinite(generation) | generation < 1 | ...
                generation ~= floor(generation))
            message = sprintf('%s.Generation must contain positive integers', ...
                name);
            return;
        end
        if any(~isfinite(fe) | fe < 0 | fe > maxFE | fe ~= floor(fe))
            message = sprintf('%s.FE contains invalid completed-FE values', ...
                name);
            return;
        end
    end

    exactColumns = { ...
        'solutionRows','RelationMode',0:3; ...
        'solutionRows','CandidateMode',0:2; ...
        'solutionRows','Catalog',[0,1]; ...
        'solutionRows','CurrentND',[0,1]; ...
        'solutionRows','SurviveH1',[0,1]; ...
        'solutionRows','FinalND',[0,1]; ...
        'pbiPairRows','PairType',1:3; ...
        'pbiPairRows','PredictedRelation',[-1,0,1]; ...
        'pbiPairRows','ParetoRelation',[-1,0,1]; ...
        'pbiPairRows','SDERelation',[-1,0,1]; ...
        'pbiPairRows','LeftSurviveH1',[0,1]; ...
        'pbiPairRows','RightSurviveH1',[0,1]; ...
        'pbiPairRows','LeftFinalND',[0,1]; ...
        'pbiPairRows','RightFinalND',[0,1]; ...
        'networkPairRows','AnchorCatalog',[0,1]; ...
        'networkPairRows','PredictedRelation',[-1,0,1]; ...
        'networkPairRows','ParetoRelation',[-1,0,1]; ...
        'networkPairRows','SDERelation',[-1,0,1]; ...
        'networkPairRows','CandidateSurviveH1',[0,1]; ...
        'networkPairRows','CandidateFinalND',[0,1]; ...
        'candidateRows','RelationMode',0:3; ...
        'candidateRows','CandidateMode',0:2; ...
        'candidateRows','DominatesAny',[0,1]; ...
        'candidateRows','DominatedByAny',[0,1]; ...
        'candidateRows','IsNondominated',[0,1]; ...
        'candidateRows','MarginalIGDPositive',[0,1]; ...
        'candidateRows','SurviveH1',[0,1]; ...
        'candidateRows','ArchiveNDNext',[0,1]; ...
        'candidateRows','FinalND',[0,1]};
    for i = 1:size(exactColumns,1)
        tableName = exactColumns{i,1};
        columnName = exactColumns{i,2};
        allowed = exactColumns{i,3};
        values = probe.(tableName)(:, ...
            column(schema,tableName,columnName));
        if any(~isfinite(values) | ~ismember(values,allowed))
            message = sprintf('%s.%s contains invalid completed values', ...
                tableName,columnName);
            return;
        end
    end

    censoredColumns = { ...
        'solutionRows','SurviveH3'; ...
        'pbiPairRows','LeftSurviveH3'; ...
        'pbiPairRows','RightSurviveH3'; ...
        'networkPairRows','CandidateSurviveH3'; ...
        'candidateRows','SurviveH3'};
    for i = 1:size(censoredColumns,1)
        tableName = censoredColumns{i,1};
        columnName = censoredColumns{i,2};
        values = probe.(tableName)(:, ...
            column(schema,tableName,columnName));
        if any(~isnan(values) & ~ismember(values,[0,1]))
            message = sprintf( ...
                '%s.%s must be binary or right-censored NaN', ...
                tableName,columnName);
            return;
        end
    end

    finiteColumns = { ...
        'solutionRows','SDEFitness'; ...
        'candidateRows','MarginalIGD'};
    for i = 1:size(finiteColumns,1)
        tableName = finiteColumns{i,1};
        columnName = finiteColumns{i,2};
        values = probe.(tableName)(:, ...
            column(schema,tableName,columnName));
        if any(~isfinite(values))
            message = sprintf('%s.%s must be finite', ...
                tableName,columnName);
            return;
        end
    end
    valid = true;
end

function [valid,message] = validateFinalPopulation(population,maxFE)
    valid = false;
    message = '';
    if isempty(population)
        message = 'finalPopulation is empty';
        return;
    end
    try
        if isa(population,'SOLUTION')
            evalIDs = population.adds;
        elseif isstruct(population) && isfield(population,'add')
            evalIDs = [population.add];
        elseif isstruct(population) && isfield(population,'adds')
            evalIDs = [population.adds];
        else
            message = 'finalPopulation does not expose EvalID additions';
            return;
        end
    catch exception
        message = sprintf('cannot read final Archive EvalID values: %s', ...
            exception.message);
        return;
    end
    evalIDs = evalIDs(:);
    if any(~isfinite(evalIDs) | evalIDs <= 0 | ...
            evalIDs ~= floor(evalIDs))
        message = 'final Archive EvalID values must be positive integers';
        return;
    end
    if numel(unique(evalIDs)) ~= numel(evalIDs)
        message = 'final Archive EvalID values are not unique';
        return;
    end
    if ~isequal(sort(evalIDs),(1:maxFE)')
        message = 'final Archive EvalID values are not continuous 1:maxFE';
        return;
    end
    valid = true;
end

function equal = sameScalar(actual,expected)
    if ischar(expected) || (isstring(expected) && isscalar(expected))
        equal = (ischar(actual) || ...
            (isstring(actual) && isscalar(actual))) && ...
            strcmp(char(actual),char(expected));
    else
        equal = isnumeric(actual) && isreal(actual) && ...
            isscalar(actual) && double(actual) == double(expected);
    end
end

function indices = column(schema,tableName,columnNames)
    if ischar(columnNames)
        columnNames = {columnNames};
    end
    indices = zeros(1,numel(columnNames));
    for i = 1:numel(columnNames)
        indices(i) = find(strcmp( ...
            schema.columns.(tableName),columnNames{i}),1);
    end
end
