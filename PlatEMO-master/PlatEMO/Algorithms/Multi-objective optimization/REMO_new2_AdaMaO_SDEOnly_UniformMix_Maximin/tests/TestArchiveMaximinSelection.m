classdef TestArchiveMaximinSelection < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addAlgorithmPath(testCase)
            folder = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
        end
    end
    methods (Test)
        function updatesDistanceAfterEachSelection(testCase)
            actual = ArchiveMaximinSelection([0.5;0.9;0.25;0.75], ...
                [0;1],0,1,[0;100;0;1],3);
            testCase.verifyEqual(actual,[0.5;0.75;0.25]);
        end
        function usesBoundsInsteadOfRawUnits(testCase)
            actual = ArchiveMaximinSelection([90,0;0,1], ...
                [0,0],[0,0],[100,1],[100;0],1);
            testCase.verifyEqual(actual,[0,1]);
        end
        function excludesArchiveAndRepeatedRows(testCase)
            [actual,indices] = ArchiveMaximinSelection([0;0.5;0.5;1], ...
                [0;1],0,1,[9;0;1;9],6);
            testCase.verifyEqual(actual,0.5);
            testCase.verifyEqual(indices,2);
        end
        function tiesUseScoreThenOriginalOrder(testCase)
            actual = ArchiveMaximinSelection([0.25;0.75], ...
                [0;1],0,1,[1;2],1);
            stable = ArchiveMaximinSelection([0.75;0.25], ...
                [0;1],0,1,[2;2],1);
            testCase.verifyEqual(actual,0.75);
            testCase.verifyEqual(stable,0.75);
        end
        function ignoresFixedVariables(testCase)
            actual = ArchiveMaximinSelection([0.25,7;0.5,7], ...
                [0,7;1,7],[0,7],[1,7],[100;0],1);
            testCase.verifyEqual(actual,[0.5,7]);
        end
        function handlesEmptyAndExhaustedCandidates(testCase)
            empty = ArchiveMaximinSelection(zeros(0,2),[0,0], ...
                [0,0],[1,1],zeros(0,1),6);
            exhausted = ArchiveMaximinSelection([0;1],[0;1],0,1,[0;0],6);
            testCase.verifySize(empty,[0,2]);
            testCase.verifySize(exhausted,[0,1]);
        end
        function respectsBudgetCap(testCase)
            actual = ArchiveMaximinSelection([0.25;0.5;0.75], ...
                [0;1],0,1,[0;0;0],1);
            none = ArchiveMaximinSelection(0.5,[0;1],0,1,0,0);
            testCase.verifyEqual(actual,0.5);
            testCase.verifyEmpty(none);
        end
        function emptyArchiveUsesScoresToSeed(testCase)
            actual = ArchiveMaximinSelection([0;0.5;1], ...
                zeros(0,1),0,1,[0;1;0],2);
            testCase.verifyEqual(actual,[0.5;0]);
        end
    end
end
