function ProbeHVAllSnaps()
%ProbeHVAllSnaps Time a full-snapshot HV pass (relaxed ref point, Monte Carlo).
    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    base = 'C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30\REMO_UniformMix_Pruned_Weighted_Lambdat030';
    probs = {'DTLZ2','DTLZ7','WFG1','WFG4','WFG6'};
    SampleNum = 1e6;
    fprintf('%-6s %8s %8s %9s %9s %11s\n', 'prob','nSnap','tTotal','t/snap','nNDavg','HVend');
    for k = 1:numel(probs)
        f = fullfile(base, sprintf('REMO_UniformMix_Pruned_Weighted_Lambdat030_%s_M10_D30_1.mat', probs{k}));
        S = load(f); md = S.metadata;
        pro = feval(md.problem,'N',md.N,'M',md.M,'D',md.D,'maxFE',md.maxFE);
        r = S.result; n = size(r,1);
        % relaxed reference point from this run's own snapshots
        allMax = zeros(1, md.M); nND = 0;
        for i = 1:n
            o = r{i,2}.best.objs; allMax = max(allMax, max(o,[],1)); nND = nND + size(o,1);
        end
        fmax = max(allMax, max(pro.optimum,[],1)) * 1.1;
        rng(20260912,'twister');
        t = tic; hv = zeros(n,1);
        for i = 1:n
            hv(i) = localHV(r{i,2}.best.objs, fmax, SampleNum);
        end
        el = toc(t);
        fprintf('%-6s %8d %8.2f %9.3f %9.1f %11.5g\n', probs{k}, n, el, el/n, nND/n, hv(end));
    end
    fprintf('PROBE HV SNAPS DONE\n');
end

function s = localHV(PopObj, fmax, SampleNum)
%localHV Monte Carlo HV with an explicit reference point (same scheme as PlatEMO).
    [N, M] = size(PopObj);
    fmin = min(min(PopObj,[],1), zeros(1,M));
    P = (PopObj - repmat(fmin,N,1)) ./ repmat(fmax-fmin,N,1);
    P(any(P>1,2),:) = [];
    if isempty(P), s = 0; return; end
    MinValue = min(P,[],1);
    Samples = unifrnd(repmat(MinValue,SampleNum,1), ones(SampleNum,M));
    for i = 1:size(P,1)
        domi = true(size(Samples,1),1);
        m = 1;
        while m <= M && any(domi)
            domi = domi & P(i,m) <= Samples(:,m);
            m = m + 1;
        end
        Samples(domi,:) = [];
    end
    s = prod(ones(1,M)-MinValue) * (1 - size(Samples,1)/SampleNum);
end
