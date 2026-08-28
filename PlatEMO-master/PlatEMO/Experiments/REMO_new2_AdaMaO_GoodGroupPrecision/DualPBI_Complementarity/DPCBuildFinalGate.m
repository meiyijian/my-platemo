function gate = DPCBuildFinalGate(coverage, replay, fusionTests, ...
        uniqueTests, decisions, expectedRuns, expectedConfigs)
%DPCBuildFinalGate - Build the single final data-integrity gate
%   GATE = DPCBuildFinalGate(COVERAGE,REPLAY,FUSIONTESTS,UNIQUETESTS,
%   DECISIONS,EXPECTEDRUNS,EXPECTEDCONFIGS) returns PASS only when run
%   coverage, replay equivalence, and all primary analysis cells are
%   complete. Scientific effect directions are deliberately ignored.
%
%   See also analyze_DualPBIComplementarity

    arguments
        coverage table
        replay table
        fusionTests table
        uniqueTests table
        decisions table
        expectedRuns (1,1) double {mustBeInteger,mustBePositive}
        expectedConfigs (1,1) double {mustBeInteger,mustBePositive}
    end

    requiredCoverage = ["Problem", "M", "ExpectedRuns", ...
        "ValidRuns", "Complete"];
    requiredReplay = "EquivalencePass";
    if ~all(ismember(requiredCoverage, ...
            string(coverage.Properties.VariableNames)))
        error("DPC:InvalidCoverageTable", ...
            "Coverage table does not contain the final-gate fields.");
    end
    if ~all(ismember(requiredReplay, ...
            string(replay.Properties.VariableNames)))
        error("DPC:InvalidReplayTable", ...
            "Replay table does not contain EquivalencePass.");
    end

    expectedPrimaryCells = expectedConfigs*4;
    fusionCellCount = height(fusionTests);
    uniqueCellCount = height(uniqueTests);
    decisionCellCount = height(decisions);
    validReplayRuns = nnz(replay.EquivalencePass);
    equivalenceFailures = height(replay) - validReplayRuns;
    completeConfigs = nnz(coverage.Complete);
    coveragePass = height(coverage) == expectedConfigs && ...
        completeConfigs == expectedConfigs && ...
        sum(coverage.ExpectedRuns) == expectedRuns && ...
        sum(coverage.ValidRuns) == expectedRuns && ...
        all(coverage.ValidRuns == coverage.ExpectedRuns);
    replayPass = height(replay) == expectedRuns && ...
        validReplayRuns == expectedRuns && equivalenceFailures == 0;
    fusionCellPass = hasCompletePrimaryCells( ...
        fusionTests, ["AvailableRuns", "ValidPairs"], coverage);
    uniqueCellPass = hasCompletePrimaryCells( ...
        uniqueTests, ["AvailableRuns", "ValidRuns"], coverage);
    decisionCellPass = hasCompleteDecisionCells(decisions, coverage);
    cellPass = fusionCellPass && uniqueCellPass && decisionCellPass;
    pass = coveragePass && replayPass && cellPass;

    reasons = strings(0, 1);
    if ~coveragePass
        reasons(end + 1) = "INCOMPLETE_COVERAGE";
    end
    if ~replayPass
        reasons(end + 1) = "REPLAY_EQUIVALENCE_FAILURE";
    end
    if ~cellPass
        reasons(end + 1) = "INCOMPLETE_PRIMARY_CELLS";
    end
    if isempty(reasons)
        reasons = "NONE";
    end

    gate = table( ...
        "FINAL_INTEGRITY_GATE", string(ternary(pass, "PASS", "FAIL")), ...
        expectedRuns, height(replay), validReplayRuns, ...
        equivalenceFailures, expectedConfigs, completeConfigs, ...
        expectedPrimaryCells, fusionCellCount, uniqueCellCount, ...
        decisionCellCount, fusionCellPass, uniqueCellPass, ...
        decisionCellPass, strjoin(reasons, ";"), ...
        'VariableNames', {'Gate','Status','ExpectedRuns','ObservedReplayFiles', ...
        'ValidReplayRuns','ReplayEquivalenceFailures','ExpectedConfigs', ...
        'CompleteConfigs','ExpectedPrimaryCells','FusionCells', ...
        'UniqueCells','DecisionCells','FusionRunComplete', ...
        'UniqueRunComplete','DecisionKeyComplete','FailureReasons'});
end

function isComplete = hasCompletePrimaryCells(data, runFields, coverage)
    required = ["Problem", "M", "Stage", runFields];
    if ~hasColumns(data, required)
        isComplete = false;
        return;
    end
    isComplete = hasCompleteKeys(data, coverage);
    if ~isComplete
        return;
    end
    for rowIndex = 1:height(data)
        configuration = coverage.Problem == data.Problem(rowIndex) & ...
            coverage.M == data.M(rowIndex);
        if nnz(configuration) ~= 1
            isComplete = false;
            return;
        end
        expected = coverage.ExpectedRuns(configuration);
        if any(data{rowIndex, cellstr(runFields)} ~= expected)
            isComplete = false;
            return;
        end
    end
end

function isComplete = hasCompleteDecisionCells(data, coverage)
    required = ["Problem", "M", "Stage"];
    isComplete = hasColumns(data, required) && ...
        hasCompleteKeys(data, coverage);
end

function isComplete = hasCompleteKeys(data, coverage)
    expectedStages = ["S1_[0,0.25]", "S2_(0.25,0.50]", ...
        "S3_(0.50,0.75]", "S4_(0.75,1.00]"];
    expectedRows = height(coverage)*numel(expectedStages);
    if height(data) ~= expectedRows || ...
            height(unique(data(:, ["Problem", "M", "Stage"]), ...
            "rows")) ~= expectedRows || ...
            ~all(ismember(data.Stage, expectedStages))
        isComplete = false;
        return;
    end
    isComplete = true;
    for configIndex = 1:height(coverage)
        member = data.Problem == coverage.Problem(configIndex) & ...
            data.M == coverage.M(configIndex);
        if nnz(member) ~= numel(expectedStages) || ...
                ~all(ismember(expectedStages, data.Stage(member)))
            isComplete = false;
            return;
        end
    end
end

function tf = hasColumns(data, required)
    tf = all(ismember(required, string(data.Properties.VariableNames)));
end

function value = ternary(condition, trueValue, falseValue)
    if condition
        value = trueValue;
    else
        value = falseValue;
    end
end
