function seed = CVPStableSeed(problemIndex, objectiveCount, runNumber)
%CVPSTABLESEED Fixed seed shared by all arms of one paired job.
%   SEED = CVPSTABLESEED(PROBLEMINDEX, OBJECTIVECOUNT, RUNNUMBER) returns
%   problemIndex*10000 + objectiveCount*100 + runNumber.
%
%   The arm identifier is deliberately NOT part of the seed: every arm of a
%   paired key starts from the same initial population and the same global
%   random stream, which is what licenses the paired analysis.

    validateattributes(problemIndex, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'problemIndex');
    validateattributes(objectiveCount, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'objectiveCount');
    validateattributes(runNumber, {'numeric'}, ...
        {'scalar', 'integer', 'positive', 'finite'}, mfilename, 'runNumber');

    seed = problemIndex*10000 + objectiveCount*100 + runNumber;
end
