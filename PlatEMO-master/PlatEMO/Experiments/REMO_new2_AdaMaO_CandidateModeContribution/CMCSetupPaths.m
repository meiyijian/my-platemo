function paths = CMCSetupPaths()
%CMCSETUPPATHS Add the experiment and PlatEMO roots and audit resolution.

    experimentDirectory = fileparts(mfilename('fullpath'));
    platemoDirectory = fileparts(fileparts(experimentDirectory));
    repositoryDirectory = fileparts(platemoDirectory);
    addpath(genpath(platemoDirectory));
    addpath(experimentDirectory,'-begin');
    addpath(fullfile(experimentDirectory,'algorithms'),'-begin');

    required = ["REMO_new2_AdaMaO_HCV","CMC_HCV_Audit", ...
        "CMC_HCV_FactorBase","DTLZ2","WFG3"];
    missing = required(arrayfun(@(x)isempty(which(char(x))),required));
    if ~isempty(missing)
        error('CMC:MissingDependency','Missing CMC dependencies: %s.', ...
            strjoin(cellstr(missing),', '));
    end
    assertUniqueResolution("CMC_HCV_Audit",experimentDirectory);
    assertUniqueResolution("CMC_HCV_FactorBase",experimentDirectory);
    assertUniqueResolution("CMCArmCatalog",experimentDirectory);

    hcvMain = fullfile(platemoDirectory,'Algorithms', ...
        'Multi-objective optimization','REMO_new2_AdaMaO_HCV', ...
        'REMO_new2_AdaMaO_HCV.m');
    hcvSelection = fullfile(fileparts(hcvMain),'private','AdaMaOSelection.m');
    sourceLock = table( ...
        ["HCV_MAIN";"HCV_SELECTION"], ...
        [string(hcvMain);string(hcvSelection)], ...
        ["BD51B71976C31AD8172B00A6675A73710C475689A6906B4FDD70D10E0A920566"; ...
         "ABE4DD8ED74157C544899AFA73136F95851DB913CB6B14DFA3B09BABE725AED0"], ...
        'VariableNames',{'Source','Path','ExpectedSHA256'});
    for row = 1:height(sourceLock)
        actual = fileHash(sourceLock.Path(row));
        if ~strcmpi(actual,sourceLock.ExpectedSHA256(row))
            error('CMC:FrozenSourceDrift', ...
                'Frozen source drift for %s. Expected %s, found %s.', ...
                sourceLock.Source(row),sourceLock.ExpectedSHA256(row),actual);
        end
    end

    paths = struct('ExperimentDirectory',experimentDirectory, ...
        'PlatEMODirectory',platemoDirectory, ...
        'RepositoryDirectory',repositoryDirectory, ...
        'DefaultResultRoot',fullfile(experimentDirectory,'results'), ...
        'SourceLock',sourceLock);
end

function assertUniqueResolution(name,expectedRoot)
    matches = string(which(char(name),'-all'));
    if numel(matches) ~= 1 || ~startsWith(lower(matches(1)),lower(string(expectedRoot)))
        error('CMC:AmbiguousResolution', ...
            '%s must resolve uniquely inside the CMC experiment.',name);
    end
end

function value = fileHash(pathValue)
    bytes = fileread(char(pathValue));
    value = CMCTextHash(bytes);
end
