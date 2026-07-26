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
    [ok,message,archive] = validateFinalPopulation( ...
        loaded.finalPopulation,loaded.metadata.maxFE);
    if ~ok
        return;
    end
    [ok,message] = validateCrossTableConsistency( ...
        loaded.confidenceProbe,loaded.metadata,archive);
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
        'initialFE',job.InitialFE, ...
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

function [valid,message,archive] = validateFinalPopulation(population,maxFE)
    valid = false;
    message = '';
    archive = struct('ids',zeros(0,1),'objs',zeros(0,0), ...
        'cons',zeros(0,0));
    if isempty(population)
        message = 'finalPopulation is empty';
        return;
    end
    try
        if isa(population,'SOLUTION')
            evalIDs = population.adds;
            objectives = population.objs;
            constraints = population.cons;
        elseif isstruct(population) && isfield(population,'add')
            evalIDs = [population.add];
            if ~isfield(population,'obj') || ~isfield(population,'con')
                message = ...
                    'finalPopulation must expose obj/con for audit';
                return;
            end
            objectives = vertcat(population.obj);
            if all(arrayfun(@(solution)isempty(solution.con),population))
                constraints = zeros(numel(population),0);
            else
                constraints = vertcat(population.con);
            end
        elseif isstruct(population) && isfield(population,'adds')
            evalIDs = [population.adds];
            if ~isfield(population,'objs') || ~isfield(population,'cons')
                message = ...
                    'finalPopulation must expose objs/cons for audit';
                return;
            end
            objectives = vertcat(population.objs);
            constraints = vertcat(population.cons);
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
    if ~(isnumeric(objectives) && isreal(objectives) && ...
            size(objectives,1) == maxFE && ...
            size(objectives,2) >= 1 && all(isfinite(objectives),'all'))
        message = 'final Archive objectives are incomplete or invalid';
        return;
    end
    if ~(isnumeric(constraints) && isreal(constraints) && ...
            size(constraints,1) == maxFE && ...
            all(isfinite(constraints),'all'))
        message = 'final Archive constraints are incomplete or invalid';
        return;
    end
    [evalIDs,order] = sort(evalIDs);
    archive.ids = evalIDs;
    archive.objs = objectives(order,:);
    archive.cons = constraints(order,:);
    valid = true;
end

function [valid,message] = validateCrossTableConsistency( ...
    probe,metadata,archive)
    valid = false;
    schema = SDEConfidenceProbeSchema();
    [ok,message,generationMap] = validateGenerationCoverage( ...
        probe,schema,metadata.initialFE);
    if ~ok
        return;
    end
    [ok,message] = validateEvaluationCoverage( ...
        probe,schema,metadata,generationMap);
    if ~ok
        return;
    end
    [ok,message] = validateGenerationRelations( ...
        probe,schema,archive,generationMap);
    if ~ok
        return;
    end
    [ok,message] = validateFinalAndFutureOutcomes( ...
        probe,schema,archive,generationMap);
    if ~ok
        return;
    end
    valid = true;
end

function [valid,message,generationMap] = validateGenerationCoverage( ...
    probe,schema,initialFE)
    valid = false;
    message = '';
    generationMap = zeros(0,2);
    tableNames = fieldnames(schema.columns);
    for i = 1:numel(tableNames)
        tableName = tableNames{i};
        rows = probe.(tableName);
        generation = rows(:,column(schema,tableName,'Generation'));
        fe = rows(:,column(schema,tableName,'FE'));
        generations = unique(generation);
        currentMap = zeros(numel(generations),2);
        for j = 1:numel(generations)
            values = unique(fe(generation == generations(j)));
            if numel(values) ~= 1
                message = sprintf( ...
                    '%s Generation %d maps to multiple FE values', ...
                    tableName,generations(j));
                return;
            end
            currentMap(j,:) = [generations(j),values];
        end
        currentMap = sortrows(currentMap,1);
        if any(diff(currentMap(:,2)) < 0)
            message = sprintf('%s FE decreases across Generation values', ...
                tableName);
            return;
        end
        if isempty(generationMap)
            generationMap = currentMap;
        elseif ~isequal(generationMap,currentMap)
            message = sprintf( ...
                '%s Generation/FE coverage differs across probe tables', ...
                tableName);
            return;
        end
    end
    if isempty(generationMap) || generationMap(1,2) ~= initialFE
        message = sprintf( ...
            'probe first FE does not match metadata.initialFE=%d', ...
            initialFE);
        return;
    end
    valid = true;
end

function [valid,message] = validateEvaluationCoverage( ...
    probe,schema,metadata,generationMap)
    valid = false;
    message = '';
    candidateIDs = probe.candidateRows(:, ...
        column(schema,'candidateRows','EvalID'));
    expectedCandidates = (metadata.initialFE+1:metadata.maxFE)';
    if numel(unique(candidateIDs)) ~= numel(candidateIDs) || ...
            ~isequal(sort(candidateIDs),expectedCandidates)
        message = [ ...
            'candidateRows EvalID coverage must equal ', ...
            'initialFE+1:maxFE exactly'];
        return;
    end
    for i = 1:size(generationMap,1)
        generation = generationMap(i,1);
        fe = generationMap(i,2);
        solutionRows = rowsForGeneration( ...
            probe,schema,'solutionRows',generation);
        candidateRows = rowsForGeneration( ...
            probe,schema,'candidateRows',generation);
        networkRows = rowsForGeneration( ...
            probe,schema,'networkPairRows',generation);
        solutionIDs = solutionRows(:, ...
            column(schema,'solutionRows','EvalID'));
        generationCandidateIDs = candidateRows(:, ...
            column(schema,'candidateRows','EvalID'));
        if numel(unique(solutionIDs)) ~= numel(solutionIDs)
            message = sprintf( ...
                'solutionRows Generation %d contains duplicate EvalID', ...
                generation);
            return;
        end
        expectedIDs = fe + (1:size(candidateRows,1))';
        if ~isequal(sort(generationCandidateIDs),expectedIDs)
            message = sprintf( ...
                'candidateRows Generation %d EvalID values do not ', ...
                'equal FE+(1:n)',generation);
            return;
        end
        networkCandidateIDs = unique(networkRows(:, ...
            column(schema,'networkPairRows','CandidateEvalID')));
        if ~isequal(sort(networkCandidateIDs), ...
                sort(generationCandidateIDs))
            message = sprintf( ...
                'network candidate coverage differs in Generation %d', ...
                generation);
            return;
        end
        [ok,message] = validateNetworkRectangle( ...
            schema,solutionRows,candidateRows,networkRows,generation);
        if ~ok
            return;
        end
    end
    valid = true;
end

function [valid,message] = validateNetworkRectangle( ...
    schema,solutionRows,candidateRows,networkRows,generation)
    valid = false;
    message = '';
    solutionIDs = solutionRows(:,column(schema,'solutionRows','EvalID'));
    candidateIDs = candidateRows(:,column(schema,'candidateRows','EvalID'));
    candidateColumn = column( ...
        schema,'networkPairRows','CandidateEvalID');
    anchorColumn = column(schema,'networkPairRows','AnchorEvalID');
    actualPairs = networkRows(:,[candidateColumn,anchorColumn]);
    expectedPairs = [ ...
        repelem(candidateIDs(:),numel(solutionIDs),1), ...
        repmat(solutionIDs,numel(candidateIDs),1)];
    if size(unique(actualPairs,'rows'),1) ~= size(actualPairs,1) || ...
            ~isequal(sortrows(actualPairs),sortrows(expectedPairs))
        message = sprintf( ...
            ['networkPairRows Generation %d is not the complete ', ...
            'candidate-by-solution rectangle'],generation);
        return;
    end
    [anchorFound,anchorIndex] = ismember( ...
        networkRows(:,anchorColumn),solutionIDs);
    solutionCatalog = solutionRows(:, ...
        column(schema,'solutionRows','Catalog'));
    anchorCatalog = networkRows(:, ...
        column(schema,'networkPairRows','AnchorCatalog'));
    if ~all(anchorFound) || ...
            any(anchorCatalog ~= solutionCatalog(anchorIndex))
        message = sprintf( ...
            'network AnchorCatalog differs from solutionRows in Generation %d', ...
            generation);
        return;
    end
    candidateConfidence = candidateRows(:, ...
        column(schema,'candidateRows','NetworkConfidence'));
    predictedBetterRate = candidateRows(:, ...
        column(schema,'candidateRows','PredictedBetterRate'));
    networkConfidence = networkRows(:, ...
        column(schema,'networkPairRows','NetworkConfidence'));
    predictedRelation = networkRows(:, ...
        column(schema,'networkPairRows','PredictedRelation'));
    for i = 1:numel(candidateIDs)
        mask = networkRows(:,candidateColumn) == candidateIDs(i);
        if abs(candidateConfidence(i)-mean(networkConfidence(mask))) > ...
                1e-10
            message = sprintf( ...
                ['candidateRows NetworkConfidence disagrees with ', ...
                'network rows for EvalID %d'],candidateIDs(i));
            return;
        end
        if abs(predictedBetterRate(i)- ...
                mean(predictedRelation(mask) == 1)) > 1e-10
            message = sprintf( ...
                ['candidateRows PredictedBetterRate disagrees with ', ...
                'network rows for EvalID %d'],candidateIDs(i));
            return;
        end
    end
    valid = true;
end

function [valid,message] = validateGenerationRelations( ...
    probe,schema,archive,generationMap)
    valid = false;
    message = '';
    for i = 1:size(generationMap,1)
        generation = generationMap(i,1);
        fe = generationMap(i,2);
        solutionRows = rowsForGeneration( ...
            probe,schema,'solutionRows',generation);
        pbiRows = rowsForGeneration( ...
            probe,schema,'pbiPairRows',generation);
        solutionIDs = solutionRows(:, ...
            column(schema,'solutionRows','EvalID'));
        [found,archiveIndex] = ismember(solutionIDs,archive.ids);
        if ~all(found)
            message = sprintf( ...
                'solutionRows Generation %d references unknown EvalID', ...
                generation);
            return;
        end
        relationMode = unique(solutionRows(:, ...
            column(schema,'solutionRows','RelationMode')));
        candidateMode = unique(solutionRows(:, ...
            column(schema,'solutionRows','CandidateMode')));
        if numel(relationMode) ~= 1 || numel(candidateMode) ~= 1
            message = sprintf( ...
                'solutionRows Generation %d has inconsistent mode codes', ...
                generation);
            return;
        end
        [rebuiltSolutions,rebuiltPairs] = ...
            BuildSDEConfidencePairAudit( ...
            generation,fe,solutionIDs,archive.objs(archiveIndex,:), ...
            archive.cons(archiveIndex,:),solutionRows(:, ...
            column(schema,'solutionRows','Catalog')),solutionRows(:, ...
            column(schema,'solutionRows','PBIConfidence')), ...
            solutionRows(:,column(schema,'solutionRows','SDEFitness')), ...
            'RelationMode',relationMode, ...
            'CandidateMode',candidateMode);
        actualCurrentND = solutionRows(:, ...
            column(schema,'solutionRows','CurrentND'));
        rebuiltCurrentND = rebuiltSolutions(:, ...
            column(schema,'solutionRows','CurrentND'));
        if ~numericEqual(actualCurrentND,rebuiltCurrentND,0)
            message = sprintf( ...
                'solutionRows CurrentND cannot be rebuilt in Generation %d', ...
                generation);
            return;
        end
        coreEnd = column(schema,'pbiPairRows','SDERelation');
        if ~numericEqual(pbiRows(:,1:coreEnd), ...
                rebuiltPairs(:,1:coreEnd),1e-12)
            message = sprintf( ...
                ['PBI core rows cannot be rebuilt in Generation %d ', ...
                '(endpoint/type/direction/confidence/truth mismatch)'], ...
                generation);
            return;
        end
    end
    valid = true;
end

function [valid,message] = validateFinalAndFutureOutcomes( ...
    probe,schema,archive,generationMap)
    valid = false;
    if isempty(archive.cons)
        finalFront = NDSort(archive.objs,1) == 1;
    else
        finalFront = NDSort(archive.objs,archive.cons,1) == 1;
    end
    finalFront = finalFront(:);
    for i = 1:size(generationMap,1)
        generation = generationMap(i,1);
        solutionRows = rowsForGeneration( ...
            probe,schema,'solutionRows',generation);
        pbiRows = rowsForGeneration( ...
            probe,schema,'pbiPairRows',generation);
        candidateRows = rowsForGeneration( ...
            probe,schema,'candidateRows',generation);
        networkRows = rowsForGeneration( ...
            probe,schema,'networkPairRows',generation);
        [ok,message] = validatePBIFutureColumns( ...
            schema,solutionRows,pbiRows,generation);
        if ~ok
            return;
        end
        [ok,message] = validateNetworkFutureColumns( ...
            schema,candidateRows,networkRows,generation);
        if ~ok
            return;
        end
        checks = { ...
            solutionRows,'solutionRows','EvalID','FinalND'; ...
            pbiRows,'pbiPairRows','LeftEvalID','LeftFinalND'; ...
            pbiRows,'pbiPairRows','RightEvalID','RightFinalND'; ...
            candidateRows,'candidateRows','EvalID','FinalND'; ...
            networkRows,'networkPairRows','CandidateEvalID', ...
                'CandidateFinalND'};
        for j = 1:size(checks,1)
            rows = checks{j,1};
            tableName = checks{j,2};
            ids = rows(:,column(schema,tableName,checks{j,3}));
            values = rows(:,column(schema,tableName,checks{j,4}));
            [found,index] = ismember(ids,archive.ids);
            if ~all(found) || any(values ~= finalFront(index))
                message = sprintf( ...
                    '%s.%s does not match final Archive NDSort', ...
                    tableName,checks{j,4});
                return;
            end
        end
    end
    [valid,message] = validateH3Censoring( ...
        probe,schema,generationMap(:,1));
end

function [valid,message] = validatePBIFutureColumns( ...
    schema,solutionRows,pbiRows,generation)
    valid = false;
    message = '';
    solutionIDs = solutionRows(:,column(schema,'solutionRows','EvalID'));
    endpoints = { ...
        'LeftEvalID','LeftSurviveH1','LeftSurviveH3','LeftFinalND'; ...
        'RightEvalID','RightSurviveH1','RightSurviveH3','RightFinalND'};
    sourceColumns = {'SurviveH1','SurviveH3','FinalND'};
    for side = 1:size(endpoints,1)
        ids = pbiRows(:,column( ...
            schema,'pbiPairRows',endpoints{side,1}));
        [found,index] = ismember(ids,solutionIDs);
        if ~all(found)
            message = sprintf( ...
                'PBI Generation %d references an unknown solution endpoint', ...
                generation);
            return;
        end
        for j = 1:numel(sourceColumns)
            actual = pbiRows(:,column( ...
                schema,'pbiPairRows',endpoints{side,j+1}));
            expected = solutionRows(index,column( ...
                schema,'solutionRows',sourceColumns{j}));
            if ~numericEqual(actual,expected,0)
                message = sprintf( ...
                    'PBI %s does not match solution %s in Generation %d', ...
                    endpoints{side,j+1},sourceColumns{j},generation);
                return;
            end
        end
    end
    valid = true;
end

function [valid,message] = validateNetworkFutureColumns( ...
    schema,candidateRows,networkRows,generation)
    valid = false;
    message = '';
    candidateIDs = candidateRows(:,column(schema,'candidateRows','EvalID'));
    networkIDs = networkRows(:,column( ...
        schema,'networkPairRows','CandidateEvalID'));
    [found,index] = ismember(networkIDs,candidateIDs);
    if ~all(found)
        message = sprintf( ...
            'network Generation %d references an unknown candidate', ...
            generation);
        return;
    end
    columns = { ...
        'CandidateSurviveH1','SurviveH1'; ...
        'CandidateSurviveH3','SurviveH3'; ...
        'CandidateFinalND','FinalND'};
    for i = 1:size(columns,1)
        actual = networkRows(:,column( ...
            schema,'networkPairRows',columns{i,1}));
        expected = candidateRows(index,column( ...
            schema,'candidateRows',columns{i,2}));
        if ~numericEqual(actual,expected,0)
            message = sprintf( ...
                'network %s does not match candidate %s in Generation %d', ...
                columns{i,1},columns{i,2},generation);
            return;
        end
    end
    valid = true;
end

function [valid,message] = validateH3Censoring( ...
    probe,schema,generations)
    valid = false;
    message = '';
    auditGenerations = unique(generations(:),'sorted');
    columns = { ...
        'solutionRows',{'SurviveH3'}; ...
        'pbiPairRows',{'LeftSurviveH3','RightSurviveH3'}; ...
        'networkPairRows',{'CandidateSurviveH3'}; ...
        'candidateRows',{'SurviveH3'}};
    for i = 1:size(columns,1)
        tableName = columns{i,1};
        rows = probe.(tableName);
        rowGeneration = rows(:,column(schema,tableName,'Generation'));
        observed = ismember(rowGeneration+2,auditGenerations);
        for j = 1:numel(columns{i,2})
            columnName = columns{i,2}{j};
            values = rows(:,column(schema,tableName,columnName));
            if any(isnan(values(observed))) || ...
                    any(~isnan(values(~observed)))
                message = sprintf( ...
                    ['%s.%s violates H3 observation/right-censoring ', ...
                    'under the exact Generation+2 update rule'], ...
                    tableName,columnName);
                return;
            end
        end
    end
    valid = true;
end

function rows = rowsForGeneration(probe,schema,tableName,generation)
    allRows = probe.(tableName);
    rows = allRows(allRows(:,column( ...
        schema,tableName,'Generation')) == generation,:);
end

function equal = numericEqual(actual,expected,tolerance)
    equal = isequal(size(actual),size(expected)) && ...
        all((isnan(actual) & isnan(expected)) | ...
        (~isnan(actual) & ~isnan(expected) & ...
        abs(actual-expected) <= tolerance),'all');
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
