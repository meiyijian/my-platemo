classdef PrunedSelectionTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addSource(testCase)
            folder = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
        end
    end
    methods (Test)
        function qualityFilterRejectsDistantLowScore(testCase)
            [~,indices] = QualityBatchDistanceSelection( ...
                [0;1;3;100],[10;9;8;0],0.30,6);
            testCase.verifyEqual(indices,[1;3;2]);
        end
        function distancesUpdateAfterEverySelection(testCase)
            [~,indices] = QualityBatchDistanceSelection( ...
                [0;10;9;5],[4;3;2;1],0,3);
            testCase.verifyEqual(indices,[1;2;4]);
        end
        function scarceExplorePoolHasNoMinimumCompletion(testCase)
            [~,indices] = QualityBatchDistanceSelection( ...
                (1:10)',(1:10)',1,6);
            testCase.verifyEqual(indices,10);
        end
        function tiesUseScoreThenInputOrder(testCase)
            [~,indices] = QualityBatchDistanceSelection( ...
                [0;-1;1;2],[4;3;2;1],0,3);
            testCase.verifyEqual(indices,[1;4;2]);
        end
        function allEqualScoresKeepStableDistanceTies(testCase)
            [~,indices] = QualityBatchDistanceSelection( ...
                [0;-1;1],ones(3,1),0.8,3);
            testCase.verifyEqual(indices,[1;2;3]);
        end
        function rawDecisionUnitsArePreserved(testCase)
            [~,indices] = QualityBatchDistanceSelection( ...
                [0,0;1000,0;0,1],[3;1;2],0,2);
            testCase.verifyEqual(indices,[1;2]);
        end
        function indicatorHasNeitherCountFloorNorCompletion(testCase)
            [~,indices] = PrunedIndicatorSelection( ...
                (1:10)',(1:10)',[],6);
            testCase.verifyEqual(indices,[10;9;8]);
        end
        function indicatorDirectlyTakesTopSix(testCase)
            [~,indices] = PrunedIndicatorSelection( ...
                (1:100)',(1:100)',[],6);
            testCase.verifyEqual(indices,(100:-1:95)');
        end
        function indicatorUsesPredictionsForReranking(testCase)
            x = (1:20)';
            model = fitrsvm(x,-x,'KernelFunction','linear', ...
                'BoxConstraint',100,'Epsilon',0);
            [~,indices] = PrunedIndicatorSelection(x,x,model,3);
            testCase.verifyEqual(indices,[15;16;17]);
        end
        function selectorsRespectZeroAndRemainingBudget(testCase)
            a = QualityBatchDistanceSelection((1:10)',(1:10)',0.8,0);
            b = PrunedIndicatorSelection((1:100)',(1:100)',[],1);
            testCase.verifyEmpty(a);
            testCase.verifyEqual(b,100,'AbsTol',1e-12);
        end
    end
end
