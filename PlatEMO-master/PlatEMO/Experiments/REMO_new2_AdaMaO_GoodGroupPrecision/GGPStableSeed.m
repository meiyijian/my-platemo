function seed = GGPStableSeed(problemIndex, objectiveCount, runNumber)
%GGPSTABLESEED Return the fixed seed shared by paired experiment jobs.
%   SEED = GGPSTABLESEED(PROBLEMINDEX, OBJECTIVECOUNT, RUNNUMBER) uses
%   problemIndex*10000 + objectiveCount*100 + runNumber.

    validateattributes(problemIndex, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'problemIndex');
    validateattributes(objectiveCount, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'objectiveCount');
    validateattributes(runNumber, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'runNumber');

    seed = problemIndex*10000 + objectiveCount*100 + runNumber;
end
