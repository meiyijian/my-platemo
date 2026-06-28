function Ref = CARefSelect(Population,k)
% Select representative solutions by nondominated sorting and radar grids.

    k      = min(k,length(Population));
    PopObj = Population.objs;
    [FrontNO,MaxFNO] = NDSort(PopObj,k);
    Next = find(FrontNO<=MaxFNO);

    Pmin = min(PopObj,[],1);
    Pmax = max(PopObj,[],1);
    PopObj = (PopObj-repmat(Pmin,size(PopObj,1),1))./repmat(max(Pmax-Pmin,eps),size(PopObj,1),1);

    Choose = LastSelection(PopObj(Next,:),ismember(Next,find(FrontNO<MaxFNO)),ceil(sqrt(k)),k);
    Ref = Population(Next(Choose));
end

function Choose = LastSelection(PopObj,Choose,div,k)
    if isempty(PopObj)
        return;
    end

    [~,Extreme] = min(PopObj,[],1);
    Choose = Choose | ismember(1:size(PopObj,1),unique(Extreme));
    if sum(Choose) >= k
        selected = find(Choose);
        Choose(:) = false;
        Choose(selected(1:k)) = true;
        return;
    end

    Con = sum(PopObj,2);
    if max(Con) > 0
        Con = Con./max(Con);
    end

    [Site,RLoc] = RadarGrid(PopObj,div);
    RDis = pdist2(RLoc,RLoc);
    RDis(logical(eye(length(RDis)))) = inf;

    CrowdG = zeros(1,max(Site));
    temp = tabulate(Site(Choose));
    if ~isempty(temp)
        CrowdG(temp(:,1)) = temp(:,2);
    end

    while sum(Choose) < k
        remainS = find(~Choose);
        remainG = unique(Site(remainS));
        bestG = CrowdG(remainG) == min(CrowdG(remainG));
        current = remainS(ismember(Site(remainS),remainG(bestG)));
        fitness = 0.1.*size(PopObj,2).*Con(current) - min(RDis(current,Choose),[],2);
        [~,best] = min(fitness);
        Choose(current(best)) = true;
        CrowdG(Site(current(best))) = CrowdG(Site(current(best))) + 1;
    end
end

function [Site,RLoc] = RadarGrid(P,div)
    [N,M] = size(P);
    theta = 0 : 2*pi/M : 2*pi/M*(M-1);
    denom = sum(P,2);
    denom(denom==0) = eps;
    RLoc(:,1) = sum(P.*repmat(cos(theta),N,1),2)./denom;
    RLoc(:,2) = sum(P.*repmat(sin(theta),N,1),2)./denom;
    RLoc = (RLoc+1)/2;

    YL = min(RLoc,[],1);
    YU = max(RLoc,[],1);
    NRLoc = (RLoc-repmat(YL,N,1))./repmat(max(YU-YL,eps),N,1);
    GLoc = floor(NRLoc.*div);
    GLoc(GLoc>=div) = div - 1;
    UniqueGLoc = sortrows(unique(GLoc,'rows'));
    [~,Site] = ismember(GLoc,UniqueGLoc,'rows');
end
