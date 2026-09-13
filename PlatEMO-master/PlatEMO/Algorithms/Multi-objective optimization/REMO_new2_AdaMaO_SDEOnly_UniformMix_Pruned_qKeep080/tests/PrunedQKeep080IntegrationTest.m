classdef PrunedQKeep080IntegrationTest < matlab.unittest.TestCase
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
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080( ...
                'parameter',{150,0,0.25,0.8,6},'run',1,'save',-100, ...
                'outputFcn',@(a,p) []);
            algorithm.Solve(problem);
            testCase.verifyEqual(problem.FE,61);
            testCase.verifyEqual(cell2mat(algorithm.result(:,1)),[54;60;61]);
        end
        function indicatorConfigurationRespectsBudget(testCase)
            problem = DTLZ2('N',20,'M',3,'D',5,'maxFE',61);
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080( ...
                'parameter',{150,1,0.25,0.8,6},'run',1,'save',-100, ...
                'outputFcn',@(a,p) []);
            algorithm.Solve(problem);
            testCase.verifyEqual(problem.FE,61);
            testCase.verifyEqual(cell2mat(algorithm.result(:,1)),[54;60;61]);
        end
        function initializationRespectsSmallBudget(testCase)
            problem = DTLZ2('N',20,'M',3,'D',5,'maxFE',10);
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080( ...
                'run',1,'save',-1,'outputFcn',@(a,p) []);
            algorithm.Solve(problem);
            testCase.verifyEqual(problem.FE,10);
        end
        function rejectsLegacySevenParameterCall(testCase)
            problem = DTLZ2('N',20,'M',3,'D',5,'maxFE',10);
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080( ...
                'parameter',{3000,0.5,0.25,0.8,0.35,4,6}, ...
                'outputFcn',@(a,p) []);
            testCase.verifyError(@() algorithm.Solve(problem), ...
                'AdaMaO:InvalidParameterCount');
        end
    end
end
