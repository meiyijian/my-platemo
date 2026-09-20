function ProfileCIEMO()
%ProfileCIEMO  Where does a CI-EMO main iteration actually spend its time?
%   Runs the ORIGINAL CIEMO with a shortened budget under the profiler and
%   prints the top functions by total time, so the hotspot can be identified
%   instead of guessed.

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    maxNumCompThreads(1);
    warning('off','all');

    rng(22260912 + 1000*2 + 1,'twister');
    P = feval('DTLZ2','M',20,'D',30,'maxFE',76,'N',100);
    Alg = feval('CIEMO','save',0,'run',1);

    t0 = tic;
    profile on
    Alg.Solve(P);
    profile off
    el = toc(t0);

    st = profile('info');
    T  = st.FunctionTable;
    tot = [T.TotalTime];
    [tot,idx] = sort(tot,'descend');
    fprintf('\nCIEMO DTLZ2 M=20 maxFE=76 : %.1f s total, FE=%d\n', el, P.FE);
    fprintf('%-42s %10s %10s %8s\n','function','total_s','self_s','calls');
    for k = 1:min(18,numel(idx))
        f = T(idx(k));
        childT = 0;
        if ~isempty(f.Children)
            childT = sum([f.Children.TotalTime]);
        end
        fprintf('%-42s %10.2f %10.2f %8d\n', f.FunctionName, f.TotalTime, ...
            max(f.TotalTime-childT,0), f.NumCalls);
    end
    fprintf('PROFILE DONE\n');
end
