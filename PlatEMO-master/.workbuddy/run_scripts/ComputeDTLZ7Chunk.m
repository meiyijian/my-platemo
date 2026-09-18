function ComputeDTLZ7Chunk(alg, M, runLo, runHi, partId)
%ComputeDTLZ7Chunk One slice of the DTLZ7 serial pass, for running several
%   independent MATLAB processes side by side.
%   Each process computes a disjoint range of run ids and writes
%   - the metric.IGDp field of its own raw files (no overlap between slices), and
%   - a part file holding the traces, which the caller merges afterwards.
%   Using separate processes instead of a pool is deliberate: the pool crashed
%   reproducibly on this problem, while a plain serial loop does not.

    if nargin < 1 || isempty(alg)
        alg = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    end
    if nargin < 2 || isempty(M), M = 20; end
    if nargin < 3 || isempty(runLo), runLo = 1; end
    if nargin < 4 || isempty(runHi), runHi = 20; end
    if nargin < 5 || isempty(partId), partId = 0; end

    addpath(genpath('D:\PlatEMO-master\PlatEMO-master\PlatEMO'));
    rawRoot = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    outBase = 'C:\Users\lsx\Desktop\AdaMao实验表';
    rawDir  = fullfile(rawRoot, sprintf('%d目标', M), alg);
    outDir  = fullfile(outBase, sprintf('IGDplus_M%d', M), alg);
    if ~isfolder(outDir), mkdir(outDir); end

    problems = {'DTLZ7','WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    t0 = tic;
    for p = 1:numel(problems)
        prob = problems{p};
        d = dir(fullfile(rawDir, sprintf('%s_%s_M%d_D*_*.mat', alg, prob, M)));
        if isempty(d), continue; end
        files = cell(numel(d),1); runIds = zeros(numel(d),1); Ds = zeros(numel(d),1);
        for i = 1:numel(d)
            tok = regexp(d(i).name, sprintf('_M%d_D(\\d+)_(\\d+)\\.mat$', M), 'tokens', 'once');
            files{i} = fullfile(rawDir, d(i).name);
            Ds(i) = str2double(tok{1}); runIds(i) = str2double(tok{2});
        end
        [runIds, ord] = sort(runIds); files = files(ord); Ds = Ds(ord);
        sel = runIds >= runLo & runIds <= runHi;
        if ~any(sel), continue; end
        D = Ds(1);

        pro = feval(prob, 'M', M, 'D', D, 'N', 100, 'maxFE', 300);
        opt = pro.optimum;

        idx = find(sel);
        IGDpCell = cell(numel(idx),1); FECell = cell(numel(idx),1); partIds = zeros(numel(idx),1);
        for j = 1:numel(idx)
            i = idx(j);
            S = load(files{i});
            r = S.result; n = size(r,1);
            gp = nan(1,n); fe = nan(1,n);
            for k = 1:n
                gp(k) = IGDpFast(r{k,2}, opt);
                fe(k) = r{k,1};
            end
            IGDpCell{j} = gp; FECell{j} = fe; partIds(j) = runIds(i);
            fprintf('[p%d] %-6s run %02d  done (%d snaps, total %.1f min)\n', ...
                partId, prob, runIds(i), n, toc(t0)/60);
        end

        % write back into the raw files of this slice only
        nw = 0;
        for j = 1:numel(idx)
            f = files{idx(j)};
            want = IGDpCell{j}(:);
            Sm = load(f, 'metric');
            if isfield(Sm.metric,'IGDp') && isequal(Sm.metric.IGDp(:), want), continue; end
            metric = Sm.metric; %#ok<NASGU>
            metric.IGDp = want;
            save(f, 'metric', '-append');
            V = load(f, 'metric');
            assert(isequal(V.metric.IGDp(:), want), 'verify failed: %s', f);
            nw = nw + 1;
        end
        partFile = fullfile(outDir, sprintf('part_%s_p%d.mat', prob, partId));
        save(partFile, 'IGDpCell', 'FECell', 'partIds', 'prob', 'M', 'D', 'runLo', 'runHi', '-v7');
        fprintf('[p%d] %-6s written %d, part saved\n', partId, prob, nw);
    end
    fprintf('[p%d] CHUNK DONE in %.1f min\n', partId, toc(t0)/60);
end
