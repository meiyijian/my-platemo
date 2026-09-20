function probe_FE500_M20()
%PROBE_FE500_M20 Stage-1 health check for the seven-algorithm FE500 sweep.
%
%   Runs NO optimisation. Answers, before a single hour is spent:
%     1. does every registry class resolve, and to which file?
%     2. are the parameter cells legal for the shared harness (cell, <= 5)?
%     3. which of each algorithm's OWN helper files are shadowed by same-named
%        files elsewhere in the PlatEMO tree? ALGORITHM.Solve does
%        addpath(fileparts(which(class(obj)))) with the default -begin, so the
%        resolution STEPS UP after Solve starts. Only the post-Solve column
%        counts; a file that is still shadowed afterwards is a real defect.
%     4. what D does each of the 16 problems actually report at M=20 / D=30?
%        (WFG2 and WFG3 must come out D=31, everything else D=30.)
%
%   Usage:  matlab -batch "addpath('<thisFolder>'); probe_FE500_M20"

    here = fileparts(mfilename('fullpath'));
    platform = fileparts(fileparts(here));
    addpath(genpath(platform));

    reg = fe500_m20_registry();
    fprintf('==== registry (%d algorithms) ====\n',numel(reg));
    for k = 1:numel(reg)
        R = reg(k);
        fprintf('%-7s cls=%-56s folder=%s\n',R.key,R.cls,R.folder);
        fprintf('        params: iscell=%d numel=%d\n', ...
            iscell(R.params),numel(R.params));
        assert(iscell(R.params),'FE500_M20:BadParams','%s params is not a cell',R.key);
        assert(numel(R.params)<=5,'FE500_M20:BadParams','%s has %d params (>5)',R.key,numel(R.params));
        assert(exist(R.cls,'class')==8,'FE500_M20:NoClass','Cannot find class %s',R.cls);
    end

    fprintf('\n==== helper shadowing (%s) ====\n','post-Solve resolution is what matters');
    nShadow = 0;
    for k = 1:numel(reg)
        R = reg(k);
        algDir = fileparts(which(R.cls));
        own = dir(fullfile(algDir,'*.m'));
        fprintf('--- %-7s %s\n',R.key,algDir);
        names = {own.name};
        before = cellfun(@which,names,'UniformOutput',false);
        addpath(algDir);                      % what ALGORITHM.Solve does
        after  = cellfun(@which,names,'UniformOutput',false);
        for i = 1:numel(names)
            if ~strcmp(before{i},after{i})
                fprintf('      [shadowed then fixed] %-32s -> %s\n',names{i},after{i});
            end
        end
        for i = 1:numel(names)
            if ~strcmp(fileparts(after{i}),algDir)
                fprintf('      [STILL ELSEWHERE]     %-32s -> %s\n',names{i},after{i});
                nShadow = nShadow + 1;
            end
        end
    end

    fprintf('\n==== problem D at M=20, D requested 30, N=100, maxFE=500 ====\n');
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    want = [30 30 30 30 30 30 30, 30 31 31 30 30 30 30 30 30];
    ok = true;
    for i = 1:numel(problems)
        P = feval(problems{i},'N',100,'M',20,'D',30,'maxFE',500);
        flag = '';
        if P.D ~= want(i), flag = '   <-- UNEXPECTED'; ok = false; end
        fprintf('  idx %2d  %-6s M=%2d D=%2d maxFE=%d N=%d%s\n', ...
            i,problems{i},P.M,P.D,P.maxFE,P.N,flag);
    end

    fprintf('\n==== verdict ====\n');
    fprintf('  helpers still shadowed after Solve : %d\n',nShadow);
    fprintf('  problem D table                    : %s\n',ternary(ok,'as expected','MISMATCH'));
    if nShadow == 0 && ok
        fprintf('  PROBE OK - safe to run the timing stage.\n');
    else
        fprintf('  PROBE FLAGS ISSUES - read the lines above before running.\n');
    end
end

function out = ternary(c,a,b)
    if c, out = a; else, out = b; end
end
