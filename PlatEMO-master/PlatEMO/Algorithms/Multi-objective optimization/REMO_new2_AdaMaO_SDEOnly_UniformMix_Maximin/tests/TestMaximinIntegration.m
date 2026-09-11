classdef TestMaximinIntegration < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPlatformPath(testCase)
            folder = fileparts(fileparts(mfilename('fullpath')));
            platform = fileparts(fileparts(fileparts(folder)));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                platform,'IncludingSubfolders',true));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
        end
    end
    methods (TestMethodSetup)
        function preserveRandomState(testCase)
            previous = rng;
            testCase.addTeardown(@() rng(previous));
            rng(17,'twister');
        end
    end
    methods (Test)
        function exploreUsesSixThenRemainingOne(testCase)
            problem = DTLZ2('N',20,'M',3,'D',5,'maxFE',61);
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Maximin( ...
                'parameter',{150,0,0.25},'run',1,'save',-100, ...
                'outputFcn',@(a,p) []);
            algorithm.Solve(problem);
            testCase.verifyEqual(problem.FE,61);
            testCase.verifyEqual(cell2mat(algorithm.result(:,1)),[54;60;61]);
            archive = algorithm.result{end,2}.decs;
            testCase.verifySize(unique(archive,'rows'),[61,5]);
        end
        function indicatorModeStillRuns(testCase)
            problem = DTLZ2('N',20,'M',3,'D',5,'maxFE',55);
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Maximin( ...
                'parameter',{150,1,0.25},'run',1,'save',-100, ...
                'outputFcn',@(a,p) []);
            algorithm.Solve(problem);
            testCase.verifyEqual(problem.FE,55);
            testCase.verifyEqual(cell2mat(algorithm.result(:,1)),[54;55]);
        end
        function initializationRespectsSmallBudget(testCase)
            problem = DTLZ2('N',20,'M',3,'D',5,'maxFE',10);
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Maximin( ...
                'run',1,'save',-1,'outputFcn',@(a,p) []);
            algorithm.Solve(problem);
            testCase.verifyEqual(problem.FE,10);
        end
    end
end
