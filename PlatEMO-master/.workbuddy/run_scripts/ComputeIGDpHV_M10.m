function ComputeIGDpHV_M10(workers)
%ComputeIGDpHV_M10 IGD+ and HV (relaxed reference point) for every stored run.
%   Read-only with respect to the dataset. For each problem of the sixteen
%   problem list the reference point of the hypervolume is fixed per problem,
%   refPoint = 1.1 * max( max over all runs and all snapshots of every
%   objective , nadir of the true optimum ), so that every stored solution is
%   retained and the values of different runs are comparable. IGD+ uses the
%   official metric with the same optimum set that produced the stored IGD.
%   Results are written per problem, one .mat file each, plus a reference
%   point table and a final-value table. Existing result files are skipped.

    if nargin < 1, workers = 5; end
    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    alg      = 'REMO_UniformMix_Pruned_Weighted_Lambdat030';
    srcDir   = fullfile('C:\Users\lsx\Desktop\REMOandDREMO测试集\10目标\n30', alg);
    outDir   = fullfile('C:\Users\lsx\Desktop\AdaMao实验表\IGDplus_HV_M10', alg);
    problems = {'DTLZ1','DTLZ2','DTLZ3','DTLZ4','DTLZ5','DTLZ6','DTLZ7', ...
                'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};
    SampleNum = 1e6;

    addpath(genpath(platform));
    assert(isfolder(srcDir), 'Missing dataset folder: %s', srcDir);
    if ~isfolder(outDir), mkdir(outDir); end

    pool = gcp('nocreate');
    if isempty(pool), pool = parpool('Processes', workers); end
    fprintf('Using %d process workers.\n', pool.NumWorkers);
    setup = parfevalOnAll(pool, @() addpath(genpath(platform)), 0);
    fetchOutputs(setup);

    refRows = {}; finalRows = {}; nDone = 0; tAll = tic;
    for p = 1:numel(problems)
        prob = problems{p};
        d = dir(fullfile(srcDir, sprintf('%s_%s_M10_D*_*.mat', alg, prob)));
        assert(~isempty(d), 'No result file for %s.', prob);
        files = cell(numel(d), 1); runIds = zeros(numel(d), 1);
        for i = 1:numel(d)
            tok = regexp(d(i).name, '_M10_D(\d+)_(\d+)\.mat$', 'tokens', 'once');
            assert(~isempty(tok), 'Unexpected file name: %s', d(i).name);
            files{i} = fullfile(srcDir, d(i).name);
            runIds(i) = str2double(tok{2});
        end
        [runIds, order] = sort(runIds); files = files(order);

        outFile = fullfile(outDir, sprintf('%s_metrics_M10.mat', prob));
        if isfile(outFile)
            fprintf('[%2d/%2d] %-6s already present, skipped.\n', p, numel(problems), prob);
            continue;
        end
        tProb = tic;

        % ---- Stage A: per-problem reference point -------------------------
        mx = zeros(numel(files), 10);
        parfor i = 1:numel(files)
            S = load(files{i});
            r = S.result; m = zeros(1, 10);
            for k = 1:size(r, 1)
                m = max(m, max(r{k,2}.objs, [], 1));
            end
            mx(i,:) = m;
        end
        md = load(files{1}, 'metadata'); md = md.metadata;
        pro = feval(md.problem, 'N', md.N, 'M', md.M, 'D', md.D, 'maxFE', md.maxFE);
        refPoint = max(max(mx, [], 1), max(pro.optimum, [], 1)) * 1.1;
        tA = toc(tProb);

        % ---- Stage B: IGD+ and HV on every snapshot -----------------------
        tmpSnap = load(files{1}, 'result');
        nSnap = size(tmpSnap.result, 1);
        clear tmpSnap
        IGDp = nan(numel(files), nSnap);
        HV   = nan(numel(files), nSnap);
        FE   = nan(numel(files), nSnap);
        parfor i = 1:numel(files)
            S = load(files{i});
            pr = feval(md.problem, 'N', md.N, 'M', md.M, 'D', md.D, 'maxFE', md.maxFE);
            r = S.result;
            gp = nan(1, nSnap); hv = nan(1, nSnap); fe = nan(1, nSnap);
            rng(20260912 + p*1000 + runIds(i), 'twister');
            for k = 1:nSnap
                pop = r{k,2};
                gp(k) = pr.CalMetric('IGDp', pop);
                hv(k) = localHV(pop.best.objs, refPoint, SampleNum);
                fe(k) = r{k,1};
            end
            IGDp(i,:) = gp; HV(i,:) = hv; FE(i,:) = fe;
        end
        tB = toc(tProb) - tA;

        meta = struct('algorithm', alg, 'problem', prob, 'M', 10, 'D', md.D, ...
            'N', md.N, 'maxFE', md.maxFE, 'save', md.save, ...
            'metric', {{'IGDp','HV'}}, 'referencePoint', refPoint, ...
            'hvSampleNum', SampleNum, 'hvSeedBase', 20260912 + p*1000, ...
            'hvReferenceScheme', ['relaxed: 1.1*max(per-problem max over all ' ...
            'runs and snapshots, nadir of true optimum)'], ...
            'igdReferenceSet', 'problem.optimum (7007 points, UniformPoint)', ...
            'source', srcDir, 'created', char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
        save(outFile, 'IGDp', 'HV', 'FE', 'runIds', 'refPoint', 'meta', '-v7');
        nDone = nDone + 1;
        fprintf('[%2d/%2d] %-6s %2d runs x %2d snaps | ref=[%s] | A %.1fs B %.1fs (%.2f s/snap) | IGDp %.4g HV %.4g\n', ...
            p, numel(problems), prob, numel(files), nSnap, ...
            strjoin(arrayfun(@(v) sprintf('%.3g', v), refPoint, 'UniformOutput', false), ','), ...
            tA, tB, tB/numel(files)/nSnap, IGDp(1,end), HV(1,end));
        refRows{end+1} = [table({prob}, 'VariableNames', {'problem'}), ...
            array2table(round(refPoint, 6), 'VariableNames', ...
            arrayfun(@(k) sprintf('f%d', k), 1:10, 'UniformOutput', false))]; %#ok<AGROW>
        for i = 1:numel(files)
            finalRows{end+1} = table({prob}, runIds(i), IGDp(i,end), HV(i,end), ...
                'VariableNames', {'problem', 'runId', 'IGDp_final', 'HV_final'}); %#ok<AGROW>
        end
    end

    if ~isempty(refRows)
        writetable(vertcat(refRows{:}), fullfile(outDir, 'reference_points.csv'), 'Encoding', 'UTF-8');
    end
    if ~isempty(finalRows)
        writetable(vertcat(finalRows{:}), fullfile(outDir, 'summary_final.csv'), 'Encoding', 'UTF-8');
    end
    fprintf('\nCOMPLETE: %d problem file(s) written in %.1f min.\n', nDone, toc(tAll)/60);
    fprintf('Output: %s\n', outDir);
end

function s = localHV(PopObj, refPoint, SampleNum)
%localHV Monte Carlo hypervolume, same estimator as the PlatEMO metric but
%   with an explicit reference point that keeps every solution of the front.
    [N, M] = size(PopObj);
    fmin   = min(min(PopObj, [], 1), zeros(1, M));
    P      = (PopObj - repmat(fmin, N, 1)) ./ repmat(refPoint - fmin, N, 1);
    P(any(P > 1, 2), :) = [];
    if isempty(P), s = 0; return; end
    MinValue = min(P, [], 1);
    Samples  = unifrnd(repmat(MinValue, SampleNum, 1), ones(SampleNum, M));
    for i = 1:size(P, 1)
        domi = true(size(Samples, 1), 1);
        m = 1;
        while m <= M && any(domi)
            domi = domi & P(i, m) <= Samples(:, m);
            m = m + 1;
        end
        Samples(domi, :) = [];
    end
    s = prod(ones(1, M) - MinValue) * (1 - size(Samples, 1) / SampleNum);
end
