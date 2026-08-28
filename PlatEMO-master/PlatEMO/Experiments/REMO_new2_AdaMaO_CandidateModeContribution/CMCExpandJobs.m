function jobs = CMCExpandJobs(protocol,arms)
%CMCEXPANDJOBS Expand a protocol and arm table into paired jobs.

    total = numel(protocol.Problems)*numel(protocol.Objectives)* ...
        numel(protocol.Runs)*height(arms);
    names = {'Stage','Profile','Problem','Family','M','RequestedD', ...
        'ActualD','Run','SearchSeed','RoutingSeed','RandomControlSeed', ...
        'Arm','ArmID','AlgorithmClass','JobID','PairedKey','ProtocolHash'};
    types = {'string','string','string','string','double','double', ...
        'double','double','double','double','double','string','double', ...
        'string','string','string','string'};
    jobs = table('Size',[total,numel(names)],'VariableTypes',types, ...
        'VariableNames',names);
    row = 0;
    for problem = protocol.Problems
        family = extractBefore(problem,find(isstrprop(char(problem),'digit'),1));
        for M = protocol.Objectives
            actualD = actualDimension(problem,protocol.RequestedD,M);
            for run = protocol.Runs
                seed = CMCStableSeed(protocol.Stage,problem,M,run);
                for armIndex = 1:height(arms)
                    row = row + 1;
                    arm = arms(armIndex,:);
                    pairedKey = sprintf('%s_M%d_run%03d_seed%d', ...
                        problem,M,run,seed.Search);
                    jobs(row,:) = {protocol.Stage,protocol.Profile,problem, ...
                        family,M,protocol.RequestedD,actualD,run,seed.Search, ...
                        seed.Routing,seed.RandomControl,arm.Arm,arm.ArmID, ...
                        arm.AlgorithmClass, ...
                        string(sprintf('%s_M%d_%s_run%03d', ...
                            problem,M,arm.Arm,run)), ...
                        string(pairedKey),protocol.ProtocolHash};
                end
            end
        end
    end
end

function D = actualDimension(problem,requestedD,M)
    D = requestedD;
    if ismember(problem,["WFG2","WFG3"]) && mod(D-(M-1),2) ~= 0
        D = D + 1;
    end
end
