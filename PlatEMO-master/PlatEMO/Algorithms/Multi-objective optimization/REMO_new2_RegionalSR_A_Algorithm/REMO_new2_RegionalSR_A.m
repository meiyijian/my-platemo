classdef REMO_new2_RegionalSR_A < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Regional soft ranking route A: one global model with reference-vector context.
% k           ---     6 --- Number of reference solutions for variation
% gmax        ---  3000 --- Number of surrogate evaluations
% pairMax     --- 12000 --- Maximum number of regional training pairs
% alphaSoft   ---     6 --- Slope of soft ranking probability
% anchorNum   ---    12 --- Anchors per active reference region
% Nref        ---   100 --- Number of reference vectors
% neighborNum ---     2 --- Neighbor regions used to expand local pools
% maxRegions  ---    25 --- Maximum active regions used by surrogate selection

    methods
        function main(Algorithm,Problem)
            [k,gmax,pairMax,alphaSoft,anchorNum,Nref,neighborNum,maxRegions] = ...
                Algorithm.ParameterSet(6,3000,12000,6,12,100,2,25);

            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation(repmat(Problem.upper-Problem.lower,N,1).*PopDec + repmat(Problem.lower,N,1));
            Archive    = Population;

            while Algorithm.NotTerminated(Archive)
                ratio = Problem.FE / Problem.maxFE;
                Input = Population.decs;

                Ref = RefSelect(Population,k);
                W   = CreateReferenceVectors_RegionalSR(max(Nref,Problem.N),Problem.M);
                Info = BuildRegionalInfo_RegionalSR(Population.objs,W,ratio);
                activeRegions = SelectActiveRegions_RegionalSR(Info.region,maxRegions);

                [XXs,Ps] = GetRegionalSoftRelationPairs_A(Input,Info,W,activeRegions,...
                    'Alpha',alphaSoft,'MaxPairs',pairMax,'NeighborNum',neighborNum);

                [TrainIn,TrainOut,TestIn,TestOut] = DataProcessSoft(XXs,Ps,0.75);
                [net,mpStruct] = TrainSoftProbabilityNet_RegionalSR(TrainIn,TrainOut);

                if isempty(TestIn)
                    pErr = NaN;
                else
                    TestInNor = mapminmax('apply',TestIn',mpStruct)';
                    TestPred  = net(TestInNor')';
                    pErr      = mean((TestPred - TestOut).^2);
                end

                Smodel.X             = Input;
                Smodel.W             = W;
                Smodel.Info          = Info;
                Smodel.activeRegions = activeRegions;
                Smodel.net           = net;
                Smodel.mp_struct     = mpStruct;
                Smodel.p_err         = pErr;
                Smodel.anchorNum     = anchorNum;
                Smodel.neighborNum   = neighborNum;

                Next = RSurrogateAssistedSelection_RegionalSR_A(Problem,Ref,Input,gmax,Smodel);
                if ~isempty(Next)
                    Archive = [Archive,Problem.Evaluation(Next)];
                end
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end
