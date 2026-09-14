classdef Lambdat030Test < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addAlgorithmPath(testCase)
            root = fileparts(fileparts(mfilename('fullpath')));
            platform = fileparts(fileparts(fileparts(root)));
            previousPath = path;
            testCase.addTeardown(@path,previousPath);
            addpath(genpath(platform));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
        end
    end
    methods (Test)
        function fixedRewardChangesPriority(testCase)
            [next,info] = Lambdat030WeightedBatchSelection([10;20;30], ...
                [0;0.8;1],[0;1;0],0,1,1/3);
            testCase.verifyEqual(next,20);
            testCase.verifyEqual(info.lambdaT,0.30);
            testCase.verifyTrue(info.firstChanged);
        end
        function rewardDoesNotDecay(testCase)
            [early,a] = Lambdat030WeightedBatchSelection([10;20;30], ...
                [0;0.8;1],[0;1;0],0,2,0);
            [late,b] = Lambdat030WeightedBatchSelection([10;20;30], ...
                [0;0.8;1],[0;1;0],0,2,1);
            testCase.verifyEqual(early,late);
            testCase.verifyEqual([a.lambdaT,b.lambdaT],[0.30,0.30]);
        end
        function qualityScreenCannotBeBypassed(testCase)
            [next,info] = Lambdat030WeightedBatchSelection([10;20;30], ...
                [0;0.8;1],[1;0;0],0.70,6,0.9);
            testCase.verifyEqual(next,30);
            testCase.verifyEqual(info.nRetained,1);
        end
        function zeroBudgetReturnsEmpty(testCase)
            next = Lambdat030WeightedBatchSelection([10;20;30], ...
                [0;0.8;1],[0;1;0],0,0,0.5);
            testCase.verifyEmpty(next);
        end
        function sixthParameterRejected(testCase)
            alg = REMO_UniformMix_Pruned_Weighted_Lambdat030( ...
                'parameter',{120,0,0.25,0.70,6,0.30});
            pro = DTLZ2('N',100,'M',10,'D',30,'maxFE',107);
            testCase.verifyError(@()alg.main(pro),'AdaMaO:InvalidParameterCount');
            testCase.verifyEqual(pro.FE,0);
        end
        function explorationHonorsActualBudget(testCase)
            global ADAMAO_LAMBDAT030_DIAG
            rng(20260914,'twister');
            alg = REMO_UniformMix_Pruned_Weighted_Lambdat030( ...
                'parameter',{120,0,0.25,0.70,6},'save',2,'outputFcn',@(~,~)[]);
            pro = DTLZ2('N',100,'M',10,'D',30,'maxFE',107);
            alg.Solve(pro);
            records = [ADAMAO_LAMBDAT030_DIAG.records{:}];
            testCase.verifyEqual(pro.FE,107);
            testCase.verifyEqual(alg.result{end,1},107);
            testCase.verifyGreaterThanOrEqual(numel(records),2);
            testCase.verifyEqual([records.lambdaT],0.30*ones(1,numel(records)));
            testCase.verifyLessThanOrEqual([records.target],[records.batchSize]);
        end
        function indicatorHonorsActualBudget(testCase)
            rng(20260915,'twister');
            alg = REMO_UniformMix_Pruned_Weighted_Lambdat030( ...
                'parameter',{120,1,0.25,0.70,6},'save',2,'outputFcn',@(~,~)[]);
            pro = DTLZ2('N',100,'M',10,'D',30,'maxFE',107);
            alg.Solve(pro);
            testCase.verifyEqual(pro.FE,107);
            testCase.verifyEqual(alg.result{end,1},107);
        end
    end
end
