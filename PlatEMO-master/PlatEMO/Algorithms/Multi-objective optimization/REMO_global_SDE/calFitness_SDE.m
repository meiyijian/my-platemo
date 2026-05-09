function Fitness = calFitness_SDE(PopObj,Lp)
    N      = size(PopObj,1);
    fmax   = max(PopObj,[],1);
    fmin   = min(PopObj,[],1);
    PopObj = (PopObj-repmat(fmin,N,1))./repmat(fmax-fmin,N,1);
    Dis    = inf(N);
    for i = 1 : N
        SPopObj = max(PopObj,repmat(PopObj(i,:),N,1));
        for j = [1:i-1,i+1:N]
            Dis(i,j) = norm(PopObj(i,:)-SPopObj(j,:));
        end
    end
    Fitness = min(Dis,[],2);
    Fitness = 3/(max(Fitness)+eps-min(Fitness))*(Fitness-min(Fitness));
    dis = pdist2(PopObj, min(PopObj), 'minkowski', Lp);
    dis = -3/(max(dis)+eps-min(dis))*(dis-min(dis));
    Fitness(Fitness<10^-4) = dis(Fitness<10^-4);
    Fitness = tansig(Fitness);
end
