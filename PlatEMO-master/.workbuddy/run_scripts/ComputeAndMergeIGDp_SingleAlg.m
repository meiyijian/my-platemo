function ComputeAndMergeIGDp_SingleAlg(alg, M, workers)
%ComputeAndMergeIGDp_SingleAlg IGD+ for one algorithm, then merge into raw .mat.
%   Two products in one pass:
%     1. the standard IGDplus_M<M> product folder, so the algorithm can later
%        be summarised together with the others;
%     2. the metric.IGDp field written back into each raw run file, which is
%        what the user asked for.
%   The merge follows the same safety rules as the multi-algorithm pass: only
%   'metric' is read and written, every file is re-read and compared right
%   after the write, and files that already match are skipped.
%   A problem whose raw files already carry the correct IGDp is skipped whole,
%   so a crashed run can be resumed without recomputing what is already done.

    if nargin < 1 || isempty(alg)
        alg = 'REMO_UniformMix_Pruned_Weighted_Lambdat030_NoBatchDist';
    end
    if nargin < 2 || isempty(M), M = 20; end
    if nargin < 3 || isempty(workers), workers = 6; end

    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    rawRoot  = 'C:\Users\lsx\Desktop\REMOandDREMO测试集';
    outBase  = 'C:\Users\lsx\Desktop\AdaMao实验表';
    if M == 10
        rawDir = fullfile(rawRoot, '10目标', 'n30', alg);
    else
        rawDir = fullfile(rawRoot, sprintf('%d目标', M), alg);
    end
    outDir = fullfile(outBase, sprintf('IGDplus_M%d', M), alg);
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

    addpath(genpath(platform));
    igdpFile = which('IGDp');
    assert(~isempty(igdpFile) && strcmpi(fileparts(igdpFile), fullfile(platform,'Metrics')), ...
        'IGDp resolves to %s.', igdpFile);
    assert(isfolder(rawDir), 'Missing algorithm folder: %s', rawDir);
    if ~isfolder(outDir), mkdir(outDir); end

    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes', workers); end
    fprintf('Algorithm : %s\nM = %d\nUsing %d workers.\n', alg, M, pool.NumWorkers);
    setup = parfevalOnAll(pool, @() addpath(genpath(platform)), 0);
    fetchOutputs(setup);

    nWritten = 0; nSkipped = 0; nChecked = 0; nFile = 0;
    tAll = tic;
    for p = 1:numel(problems)
        prob = problems{p};
        d = dir(fullfile(rawDir, sprintf('%s_%s_M%d_D*_*.mat', alg, prob, M)));
        if isempty(d), fprintf('[%2d] %-6s no file\n', p, prob); continue; end
        files = cell(numel(d), 1); runIds = zeros(numel(d), 1); Ds = zeros(numel(d), 1);
        for i = 1:numel(d)
            tok = regexp(d(i).name, sprintf('_M%d_D(\\d+)_(\\d+)\\.mat$', M), 'tokens', 'once');
            assert(~isempty(tok), 'Unexpected file name: %s', d(i).name);
            files{i} = fullfile(rawDir, d(i).name);
            Ds(i) = str2double(tok{1}); runIds(i) = str2double(tok{2});
        end
        [runIds, ord] = sort(runIds); files = files(ord); Ds = Ds(ord);
        assert(numel(unique(Ds)) == 1, 'Inconsistent D for %s.', prob);
        D = Ds(1);

        % Resume support: if the product exists and every raw file of this
        % problem already carries exactly that trace, there is nothing to do.
        prodFile = fullfile(outDir, sprintf('%s_IGDp_M%d.mat', prob, M));
        if isfile(prodFile)
            P = load(prodFile, 'IGDpCell', 'runIds');
            if numel(P.runIds) == numel(runIds) && isequal(P.runIds(:), runIds(:))
                done = true;
                for i = 1:numel(files)
                    Sm = load(files{i}, 'metric');
                    if ~isfield(Sm.metric, 'IGDp') || ...
                            ~isequal(Sm.metric.IGDp(:), P.IGDpCell{i}(:))
                        done = false; break;
                    end
                end
                if done
                    fprintf('[%2d] %-6s already computed and merged, skipped\n', p, prob);
                    continue;
                end
            end
        end

        tP = tic;
        pro = feval(prob, 'M', M, 'D', D, 'N', 100, 'maxFE', 300);
        opt = pro.optimum;
        nRuns = numel(files);
        IGDpCell = cell(nRuns, 1); FECell = cell(nRuns, 1);
        % The reference set of DTLZ7 at M=20 holds 524288 points (~84 MB).
        % Shipping that as a broadcast variable to every worker is what killed
        % the pool there, so each worker builds its own problem instead: the
        % construction costs ~0.3 s and needs no transfer at all.
        parfor i = 1:nRuns
            S = load(files{i});
            proW = feval(prob, 'M', M, 'D', D, 'N', 100, 'maxFE', 300);
            optW = proW.optimum;
            r = S.result; n = size(r, 1);
            gp = nan(1, n); fe = nan(1, n);
            for k = 1:n
                % IGDpFast is block-wise but numerically identical to the stock
                % metric (verified relDiff = 0). The stock version allocates a
                % temporary per reference point, which is hopeless at 524288.
                gp(k) = IGDpFast(r{k,2}, optW);
                fe(k) = r{k,1};
            end
            IGDpCell{i} = gp; FECell{i} = fe;
        end
        IGDpFinal = cellfun(@(v) v(end), IGDpCell);

        % 1) keep a standard product
        prodFile = fullfile(outDir, sprintf('%s_IGDp_M%d.mat', prob, M));
        meta = struct('algorithm', alg, 'problem', prob, 'M', M, 'D', D, ...
            'N', 100, 'maxFE', 300, 'metric', 'IGDp', ...
            'referenceSet', 'problem.optimum, generated by the problem class', ...
            'nReferencePoints', size(opt, 1), 'snapshotCounts', cellfun(@numel, IGDpCell), ...
            'source', rawDir, 'created', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        save(prodFile, 'IGDpCell', 'FECell', 'runIds', 'IGDpFinal', 'meta', '-v7');
        nFile = nFile + 1;

        % 2) merge into the raw run files
        for i = 1:nRuns
            want = IGDpCell{i}(:);
            Sm = load(files{i}, 'metric');
            if isfield(Sm.metric, 'IGDp') && isequal(Sm.metric.IGDp(:), want)
                nSkipped = nSkipped + 1; continue;
            end
            metric = Sm.metric; %#ok<NASGU>
            metric.IGDp = want;
            save(files{i}, 'metric', '-append');
            V = load(files{i}, 'metric');
            if ~isequal(V.metric.IGDp(:), want)
                error('SingleAlgMerge:verifyFail', 'IGDp mismatch after write: %s', files{i});
            end
            nWritten = nWritten + 1; nChecked = nChecked + 1;
        end
        fprintf('[%2d] %-6s %2d runs x %s snaps | %.1fs | mean IGD+ %.4g\n', ...
            p, prob, nRuns, mat2str(unique(cellfun(@numel, IGDpCell))'), ...
            toc(tP), mean(IGDpFinal));
    end
    fprintf('\nDONE: products %d, raw written %d, skipped %d, verified %d, %.1f min\n', ...
        nFile, nWritten, nSkipped, nChecked, toc(tAll)/60);
end
