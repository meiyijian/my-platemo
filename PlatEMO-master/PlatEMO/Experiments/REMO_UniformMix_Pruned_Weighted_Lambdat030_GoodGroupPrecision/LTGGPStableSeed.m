function seed = LTGGPStableSeed(problemIndex, objectiveCount, runNumber)
%LTGGPSTABLESEED Return the fixed seed shared by paired experiment jobs.
%   SEED = LTGGPSTABLESEED(PROBLEMINDEX, OBJECTIVECOUNT, RUNNUMBER) uses
%   problemIndex*10000 + objectiveCount*100 + runNumber. This is identical
%   to PWGGPStableSeed, which keeps every formal run paired with the
%   existing lambda_t = 0.50 PWGGP results.

    validateattributes(problemIndex, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'problemIndex');
    validateattributes(objectiveCount, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'objectiveCount');
    validateattributes(runNumber, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'runNumber');

    seed = problemIndex*10000 + objectiveCount*100 + runNumber;
end
