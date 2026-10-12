classdef TestREMONoCDIS < matlab.unittest.TestCase
%TestREMONoCDIS Public-entry regression checks for the CDIS replacement.
    properties (TestParameter)
        configuration = struct( ...
            'tenObjectivesDefaultSearch',struct('M',10,'D',30,'maxFE',103, ...
                'parameter',{{3000,0.25,6}},'initialFE',100,'cap',6), ...
            'twentyObjectives',struct('M',20,'D',30,'maxFE',105, ...
                'parameter',{{90,0.25,6}},'initialFE',100,'cap',6), ...
            'twoPointCap',struct('M',10,'D',30,'maxFE',105, ...
                'parameter',{{90,0.25,2}},'initialFE',100,'cap',2), ...
            'initializationOnly',struct('M',3,'D',5,'maxFE',7, ...
                'parameter',{{90,0.25,6}},'initialFE',7,'cap',6));
    end

    methods (TestClassSetup)
        function configurePath(testCase)
            algorithmDir = fileparts(fileparts(mfilename('fullpath')));
            root = fileparts(fileparts(fileparts(algorithmDir)));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'Algorithms')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'Algorithms','Utility functions')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'Problems')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(root,'Problems','Multi-objective optimization','DTLZ')));
            % A global homonym is present: the algorithm must still resolve
            % its private REMO snapshot and its private Full-derived helpers.
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                fullfile(fileparts(algorithmDir),'REMO')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(algorithmDir));
        end
    end

    methods (TestMethodSetup)
        function preserveRandomState(testCase)
            originalState = rng;
            testCase.addTeardown(@() rng(originalState));
            rng(20261008,'twister');
        end
    end

    methods (Test)
        function respectsActualEvaluationBudget(testCase,configuration)
            problem = DTLZ2('N',100,'M',configuration.M, ...
                'D',configuration.D,'maxFE',configuration.maxFE);
            history = zeros(0,1);
            algorithm = REMO_NoCDIS_REMOSelection( ...
                'parameter',configuration.parameter,'save',-30,'run',1, ...
                'outputFcn',@recordFE);

            algorithm.Solve(problem);

            testCase.verifyEqual(problem.FE,configuration.maxFE);
            testCase.verifyEqual(history(1),configuration.initialFE);
            testCase.verifyEqual(history(end),configuration.maxFE);
            testCase.verifyTrue(all(diff(history)>0));
            testCase.verifyTrue(all(diff(history)<=configuration.cap));
            testCase.verifyTrue(all(isfinite(algorithm.result{end,2}.objs),'all'));
            testCase.verifyEqual(size(algorithm.result{end,2}.decs,2),configuration.D);
            fprintf('FE_CHECK M=%d D=%d gmax=%d cap=%d FE=%s\n', ...
                configuration.M,configuration.D,configuration.parameter{1}, ...
                configuration.cap,mat2str(history'));

            function recordFE(~,currentProblem)
                history(end+1,1) = currentProblem.FE;
            end
        end

        function rejectsFullParameterVector(testCase)
            problem = DTLZ2('N',100,'M',10,'D',30,'maxFE',103);
            algorithm = REMO_NoCDIS_REMOSelection( ...
                'parameter',{3000,0.50,0.25,0.70,6}, ...
                'outputFcn',@(~,~) []);
            testCase.verifyError(@() algorithm.Solve(problem), ...
                'REMO_NoCDIS_REMOSelection:InvalidParameterCount');
            testCase.verifyEqual(problem.FE,0);
        end

        function rejectsInvalidBatchCap(testCase)
            problem = DTLZ2('N',100,'M',10,'D',30,'maxFE',103);
            algorithm = REMO_NoCDIS_REMOSelection( ...
                'parameter',{3000,0.25,0},'outputFcn',@(~,~) []);
            testCase.verifyError(@() algorithm.Solve(problem), ...
                'REMO_NoCDIS_REMOSelection:InvalidParameter');
            testCase.verifyEqual(problem.FE,0);
        end
    end
end
