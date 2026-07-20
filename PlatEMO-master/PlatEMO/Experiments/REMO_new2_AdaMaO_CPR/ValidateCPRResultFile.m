function [valid,message,metrics] = ValidateCPRResultFile(resultFile,protocol,job)
%VALIDATECPRRESULTFILE Check whether a run file matches its current job.
%   A file is resumable only when all required outputs exist, metrics are
%   finite, and protocol-defining metadata exactly match the requested job.

    valid = false;
    message = '';
    metrics = struct('IGD',nan,'IGDp',nan,'runtime',nan);
    if ~isfile(resultFile)
        message = 'result file does not exist';
        return;
    end
    try
        variables = whos('-file',resultFile);
        variableNames = {variables.name};
        requiredVariables = {'metadata','IGD','IGDp','runtime','finalPopulation'};
        missing = requiredVariables(~ismember(requiredVariables,variableNames));
        if ~isempty(missing)
            message = sprintf('missing variable(s): %s',strjoin(missing,', '));
            return;
        end
        populationInfo = variables(strcmp(variableNames,'finalPopulation'));
        if isempty(populationInfo) || prod(populationInfo.size) == 0
            message = 'finalPopulation is empty';
            return;
        end
        loaded = load(resultFile,'metadata','IGD','IGDp','runtime');
    catch exception
        message = sprintf('unreadable MAT file: %s',exception.message);
        return;
    end

    if ~isstruct(loaded.metadata) || ~isscalar(loaded.metadata)
        message = 'metadata is not a scalar struct';
        return;
    end
    expected = expectedMetadata(protocol,job);
    fieldNames = fieldnames(expected);
    for index = 1:numel(fieldNames)
        fieldName = fieldNames{index};
        if ~isfield(loaded.metadata,fieldName)
            message = sprintf('metadata missing field %s',fieldName);
            return;
        end
        if ~sameValue(loaded.metadata.(fieldName),expected.(fieldName))
            message = sprintf('metadata field %s does not match current job',fieldName);
            return;
        end
    end

    metricNames = {'IGD','IGDp','runtime'};
    for index = 1:numel(metricNames)
        metricName = metricNames{index};
        value = loaded.(metricName);
        if ~(isnumeric(value) && isreal(value) && isscalar(value) && ...
                isfinite(value) && value >= 0)
            message = sprintf('%s must be a finite nonnegative numeric scalar', ...
                metricName);
            return;
        end
        metrics.(metricName) = double(value);
    end
    valid = true;
end

function expected = expectedMetadata(protocol,job)
    expected = struct( ...
        'profile',protocol.profile, ...
        'problem',char(job.Problem), ...
        'M',job.M, ...
        'requestedD',job.RequestedD, ...
        'actualD',job.ActualD, ...
        'maxFE',protocol.maxFE, ...
        'run',job.Run, ...
        'seed',job.Seed, ...
        'algorithmLabel',char(job.Algorithm), ...
        'algorithmClass',char(job.AlgorithmClass));
end

function equal = sameValue(actual,expected)
    if ischar(expected) || (isstring(expected) && isscalar(expected))
        equal = (ischar(actual) || (isstring(actual) && isscalar(actual))) && ...
            strcmp(char(actual),char(expected));
    else
        equal = isnumeric(actual) && isscalar(actual) && ...
            double(actual) == double(expected);
    end
end
