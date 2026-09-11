classdef PrunedWeightedTest < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addPlatform(testCase)
            folder = fileparts(fileparts(mfilename('fullpath')));
            platform = fileparts(fileparts(fileparts(folder)));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture( ...
                platform,'IncludingSubfolders',true));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(folder));
        end
    end
    methods (TestMethodSetup)
        function preserveRandomState(testCase)
            old = rng;
            testCase.addTeardown(@() rng(old));
            rng(17,'twister');
        end
    end
    methods (Test)
        function qualityCanOutweighDistance(testCase)
            [~,indices] = PrunedWeightedBatchSelection( ...
                [0;0.1;1],[1;0.99;0.8],0,2);
            testCase.verifyEqual(indices,[1;2]);
        end
        function distanceStillBreaksQualityPlateau(testCase)
            [~,indices] = PrunedWeightedBatchSelection( ...
                [0;0.1;0.2;1],[1;0.8;0.8;0.8],0,2);
            testCase.verifyEqual(indices,[1;4]);
        end
        function usesEuclideanNotSquaredDistanceInWeightedSum(testCase)
            [~,indices] = PrunedWeightedBatchSelection( ...
                [0;1;4;9],[2;0;1;0.75],0,2);
            testCase.verifyEqual(indices,[1;3]);
        end
        function scarceQualityPoolIsNotCompleted(testCase)
            [~,indices] = PrunedWeightedBatchSelection( ...
                (1:10)',(1:10)',1,6);
            testCase.verifyEqual(indices,10);
        end
        function tiesFollowOriginalInputOrder(testCase)
            [~,indices] = PrunedWeightedBatchSelection( ...
                [0;-1;1],ones(3,1),0.7,2);
            testCase.verifyEqual(indices,[1;2]);
        end
        function takingWholePoolKeepsOriginalScoreOrder(testCase)
            [~,indices] = PrunedWeightedBatchSelection( ...
                (1:3)',[1;3;2],0,6);
            testCase.verifyEqual(indices,[2;3;1]);
        end
        function zeroBudgetReturnsEmpty(testCase)
            next = PrunedWeightedBatchSelection((1:10)',(1:10)',0.7,0);
            testCase.verifyEmpty(next);
        end
        function indicatorShortlistStillHasNoCountFloor(testCase)
            [~,indices] = PrunedIndicatorSelection((1:10)',(1:10)',[],6);
            testCase.verifyEqual(indices,[10;9;8]);
        end
        function exploreRespectsRemainingBudget(testCase)
            problem = DTLZ2('N',20,'M',3,'D',5,'maxFE',61);
            algorithm = REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted( ...
                'parameter',{150,0,0.25,0.70,6},'run',1,'save',-100, ...
                'outputFcn',@(a,p) []);
            algorithm.Solve(problem);
            testCase.verifyEqual(problem.FE,61);
            testCase.verifyEqual(cell2mat(algorithm.result(:,1)),[54;60;61]);
        end
        function pureIndicatorRunMatchesFrozenPruned(testCase)
            p1 = DTLZ2('N',20,'M',3,'D',5,'maxFE',61);
            p2 = DTLZ2('N',20,'M',3,'D',5,'maxFE',61);
            base = REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned( ...
                'parameter',{150,1,0.25,0.70,6},'run',1,'save',-100, ...
                'outputFcn',@(a,p) []);
            control = REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted( ...
                'parameter',{150,1,0.25,0.70,6},'run',1,'save',-100, ...
                'outputFcn',@(a,p) []);
            rng(23,'twister');base.Solve(p1);
            rng(23,'twister');control.Solve(p2);
            testCase.verifyEqual(p1.FE,61);
            testCase.verifyEqual(p2.FE,61);
            testCase.verifyEqual(control.result{end,2}.decs,base.result{end,2}.decs);
            testCase.verifyEqual(control.result{end,2}.objs,base.result{end,2}.objs);
        end
    end
end
