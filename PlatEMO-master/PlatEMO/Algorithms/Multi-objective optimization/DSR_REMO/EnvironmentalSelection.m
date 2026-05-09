function Population = EnvironmentalSelection(Population, N)
% EnvironmentalSelection - Standard NSGA-II selection to trim population
% Copyright (c) 2025 BIMK Group.

    PopObj = Population.objs;[FrontNo, MaxFNo] = NDSort(PopObj, N);
    Next = FrontNo < MaxFNo;
    
    % Calculate crowding distance
    CrowdDis = CrowdingDistance(PopObj, FrontNo);
    
    Last = find(FrontNo == MaxFNo);
    [~, Rank] = sort(CrowdDis(Last), 'descend');
    Next(Last(Rank(1 : N - sum(Next)))) = true;
    
    % Return the surviving population
    Population = Population(Next);
end