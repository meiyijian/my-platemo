function seeds = CMCStableSeed(stage,problem,M,run)
%CMCSTABLESEED Return independent paired search, route, and control seeds.

    stageNumber = find(["stage0","stage1","stage2","stage3"] == ...
        lower(string(stage)),1)-1;
    problem = upper(string(problem));
    number = str2double(regexprep(problem,'\D',''));
    if startsWith(problem,"DTLZ")
        family = 1;
    elseif startsWith(problem,"WFG")
        family = 2;
    else
        error('CMC:UnsupportedProblem','Unsupported problem: %s.',problem);
    end
    base = (stageNumber+1)*100000000 + family*1000000 + ...
        number*10000 + M*100 + run;
    seeds = struct('Search',base,'Routing',base+25000000, ...
        'RandomControl',base+50000000);
end
