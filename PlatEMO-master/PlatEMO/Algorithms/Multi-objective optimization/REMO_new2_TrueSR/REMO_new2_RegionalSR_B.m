classdef REMO_new2_RegionalSR_B < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% Regional soft ranking route B: one local soft-ranking model per region.
% k           ---     6 --- Number of reference solutions for variation
% gmax        ---  3000 --- Number of surrogate evaluations
% pairMax     --- 12000 --- Maximum total training pairs
% alphaSoft   ---     6 --- Slope of soft ranking probability
% anchorNum   ---    12 --- Anchors per local model
% Nref        ---   100 --- Number of reference vectors
% neighborNum ---     2 --- Neighbor regions used to expand local pools
% maxModels   ---    20 --- Maximum number of local region models

    methods
        function main(Algorithm,Problem)
            [k,gmax,pairMax,alphaSoft,anchorNum,Nref,neighborNum,maxModels] = ...
                Algorithm.ParameterSet(6,3000,12000,6,12,100,2,20);

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

                [Models,pErr] = TrainRegionalSoftModels_B(Input,Info,W,...
                    'Alpha',alphaSoft,'MaxPairs',pairMax,'AnchorNum',anchorNum,...
                    'NeighborNum',neighborNum,'MaxModels',maxModels);

                Smodel.X       = Input;
                Smodel.W       = W;
                Smodel.Info    = Info;
                Smodel.Models  = Models;
                Smodel.p_err   = pErr;

                Next = RSurrogateAssistedSelection_RegionalSR_B(Problem,Ref,Input,gmax,Smodel);
                if ~isempty(Next)
                    Archive = [Archive,Problem.Evaluation(Next)];
                end
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end
