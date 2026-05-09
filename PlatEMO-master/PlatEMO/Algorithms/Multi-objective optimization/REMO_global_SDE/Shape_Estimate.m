function p= Shape_Estimate(Population,N)
    [FrontNo,~] = NDSort(Population.objs,N);
    Population  = Population(FrontNo<=1);
    if length(Population) < 20
        p = 1;
        return;
    end
    PopObj = Population.objs ;
    [N,~]  = size(PopObj);
    PopObj = normalization(PopObj);
    k      = 1.5;
    
    CP = [ 0.27 0.36 0.43 0.5 0.57 0.66 0.75 0.86 1 1.15 1.35 1.6 2 2.4 3.1 4.2 6.5];
    Vp = zeros(1,length(CP));
    for i = 1 : length(CP)
        Gp   = (sum(PopObj.^CP(i),2)).^(1/CP(i));
        temp = sort(Gp);
        Q1   = temp(max(fix(N*0.25),1));
        Q3   = temp(max(fix(N*0.75),1));
        Max  = Q3+k*(Q3-Q1);
        Gp(Gp>Max) = [];
        Vp(i) = std(Gp./max(Gp));
    end
    [~,index] = min(Vp);
    p = CP(index);
end

function PopObj = normalization(PopObj)
    fmin = min(PopObj,[],1);
    fmax = max(PopObj,[],1);
    PopObj = (PopObj - repmat(fmin,size(PopObj,1),1))./repmat(fmax-fmin,size(PopObj,1),1);
end
