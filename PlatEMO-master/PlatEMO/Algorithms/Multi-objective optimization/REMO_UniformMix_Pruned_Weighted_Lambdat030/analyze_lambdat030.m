function analysis = analyze_lambdat030()
%analyze_lambdat030 Compare the Lambdat030 runs with their matched-pair controls.
%   DTLZ2/4/5/7, M=10, D=30, N=100, maxFE=300, ten runs each, run IDs 19..28.
%   Primary comparison: the in-session baseline arm, which shares the seed, the
%   source revision, the session and the process pool with the Lambdat030 runs.
%   Secondary comparison: the stored baseline controls of the paper dataset,
%   which come from a different session and therefore carry extra context noise.
%   The exact two-sided sign test and an exact Wilcoxon signed-rank test are both
%   computed without the Statistics Toolbox: the sign test from binomial
%   coefficients and the Wilcoxon null distribution by dynamic programming.
%   Diagnostics report the effective reward weight, how often the reward moved
%   the batch and how much the batches overlapped. Nothing is overwritten.

    cfg = configuration();
    outDir = fullfile(cfg.logs,'analysis');
    if ~isfolder(outDir), mkdir(outDir); end
    algorithm = 'REMO_UniformMix_Pruned_Weighted_Lambdat030';

    rows = struct([]);
    missing = {};
    for p = 1:numel(cfg.problems)
        problem = cfg.problems{p};
        for ri = cfg.runIds
            newFile = fullfile(cfg.dataFolder,sprintf('%s_%s_M%d_D%d_%d.mat', ...
                algorithm,problem,cfg.M,cfg.D,ri));
            ctlFile = fullfile(cfg.controlInSessionFolder,sprintf( ...
                '%s_%s_M%d_D%d_%d.mat',cfg.baseline,problem,cfg.M,cfg.D,ri));
            storedFile = fullfile(cfg.storedControlFolder,sprintf( ...
                '%s_%s_M%d_D%d_%d.mat',cfg.baseline,problem,cfg.M,cfg.D,ri));
            if ~isfile(newFile) || ~isfile(ctlFile)
                missing{end+1} = sprintf('%s run %d',problem,ri); %#ok<AGROW>
                continue;
            end
            N = load(newFile,'metric','metadata');
            C = load(ctlFile,'metric');
            storedIGD = NaN;
            if isfile(storedFile)
                S = load(storedFile,'metric');
                storedIGD = S.metric.IGD(end);
            end
            d = N.metadata.diagnostics;
            row = struct('problem',problem,'runId',ri, ...
                'lambdaT',N.metadata.lambdaT, ...
                'IGD',N.metric.IGD(end),'controlIGD',C.metric.IGD(end), ...
                'storedIGD',storedIGD, ...
                'delta',N.metric.IGD(end)-C.metric.IGD(end), ...
                'deltaStored',N.metric.IGD(end)-storedIGD, ...
                'relChange',(N.metric.IGD(end)-C.metric.IGD(end))/C.metric.IGD(end), ...
                'exploreRounds',d.exploreRounds,'indicatorRounds',d.indicatorRounds, ...
                'meanLambdaT',d.meanLambdaT,'meanRetained',d.meanRetained, ...
                'firstChangedShare',d.firstChangedShare, ...
                'setChangedShare',d.setChangedShare, ...
                'orderChangedShare',d.orderChangedShare, ...
                'meanOverlap',d.meanOverlap, ...
                'meanAbsRankShift',d.meanAbsRankShift, ...
                'runtimeSeconds',N.metadata.runtimeSeconds, ...
                'file',newFile,'controlFile',ctlFile);
            if isempty(rows), rows = row; else, rows(end+1) = row; end %#ok<AGROW>
        end
    end
    if isempty(rows)
        error('AdaMaO:NoResult','No matched pair is available; run the experiment first.');
    end
    runs = struct2table(rows);
    writetable(runs,fullfile(outDir,'runs.csv'),'Encoding','UTF-8');

    [primaryTable,primaryPooled] = summarizeArm(runs,'delta','controlIGD');
    secondary = runs(~isnan(runs.deltaStored),:);
    if isempty(secondary)
        secondaryTable = table();
        secondaryPooled = struct('n',0,'meanDelta',NaN,'medianDelta',NaN, ...
            'improved',0,'worsened',0,'tied',0,'signP',NaN,'rankP',NaN, ...
            'meanRelChange',NaN);
    else
        [secondaryTable,secondaryPooled] = summarizeArm(secondary,'deltaStored','storedIGD');
        writetable(secondaryTable,fullfile(outDir,'problem_summary_vs_stored.csv'), ...
            'Encoding','UTF-8');
    end
    writetable(primaryTable,fullfile(outDir,'problem_summary.csv'),'Encoding','UTF-8');

    [byRound,recordFiles] = readAllRecords(cfg);
    analysis = struct();
    analysis.algorithm = algorithm;
    analysis.runsPresent = height(runs);
    analysis.runsMissing = missing;
    analysis.problems = cfg.problems;
    analysis.runIds = cfg.runIds;
    analysis.settings = cfg.settings;
    analysis.recordFiles = recordFiles;
    analysis.primaryVsInSessionControl = primaryPooled;
    analysis.secondaryVsStoredControl = secondaryPooled;
    analysis.problemSummary = table2struct(primaryTable);
    if isempty(secondaryTable)
        analysis.problemSummaryStored = struct([]);
    else
        analysis.problemSummaryStored = table2struct(secondaryTable);
    end
    analysis.reward = summarizeReward(byRound);
    writeReport(outDir,analysis,cfg);
    fid = fopen(fullfile(outDir,'analysis.json'),'w','n','UTF-8');
    assert(fid >= 0,'Cannot write the analysis summary.');
    fwrite(fid,jsonencode(analysis));
    fclose(fid);
    fprintf('Analysis written to %s\n',outDir);
    disp(primaryTable);
    if ~isempty(analysis.reward.buckets)
        disp(struct2table(analysis.reward.buckets));
    end
end

function [summaryTable,pooled] = summarizeArm(runs,deltaVar,controlVar)
%summarizeArm Per-problem paired statistics for one control arm.
    problems = unique(runs.problem,'stable');
    summary = struct([]);
    allDelta = zeros(0,1);
    controlAll = zeros(0,1);
    for p = 1:numel(problems)
        sel = strcmp(runs.problem,problems{p});
        delta = runs.(deltaVar)(sel);
        control = runs.(controlVar)(sel);
        test = pairedExact(delta);
        entry = struct('problem',problems{p},'n',numel(delta), ...
            'meanIGD',mean(runs.IGD(sel)),'medianIGD',median(runs.IGD(sel)), ...
            'meanControlIGD',mean(control),'medianControlIGD',median(control), ...
            'meanDelta',mean(delta),'medianDelta',median(delta), ...
            'meanRelChange',mean(delta./control), ...
            'improved',sum(delta < 0),'worsened',sum(delta > 0), ...
            'tied',sum(delta == 0),'signP',test.signP,'rankP',test.rankP, ...
            'meanChangedShare',mean(runs.setChangedShare(sel)), ...
            'meanOverlap',mean(runs.meanOverlap(sel)), ...
            'meanLambdaT',mean(runs.meanLambdaT(sel)), ...
            'meanExploreRounds',mean(runs.exploreRounds(sel)), ...
            'meanIndicatorRounds',mean(runs.indicatorRounds(sel)));
        if isempty(summary), summary = entry; else, summary(end+1) = entry; end %#ok<AGROW>
        allDelta = [allDelta;delta]; %#ok<AGROW>
        controlAll = [controlAll;control]; %#ok<AGROW>
    end
    summaryTable = struct2table(summary);
    test = pairedExact(allDelta);
    pooled = struct('n',numel(allDelta),'meanDelta',mean(allDelta), ...
        'medianDelta',median(allDelta),'improved',sum(allDelta < 0), ...
        'worsened',sum(allDelta > 0),'tied',sum(allDelta == 0), ...
        'signP',test.signP,'rankP',test.rankP, ...
        'meanRelChange',mean(allDelta./controlAll));
end

function cfg = configuration()
%configuration Fixed paths and settings of this comparison.
    root = fileparts(mfilename('fullpath'));
    cfg.root = root;
    cfg.dataFolder = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/10目标/n30/' ...
        'REMO_UniformMix_Pruned_Weighted_Lambdat030']);
    cfg.storedControlFolder = fullfile(['C:/Users/lsx/Desktop/REMOandDREMO测试集/' ...
        '10目标/n30/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted']);
    % Products of this experiment live inside the dataset algorithm folder.
    cfg.logs = fullfile(cfg.dataFolder,'diagnostics');
    cfg.recordsFolder = fullfile(cfg.logs,'records');
    cfg.controlInSessionFolder = fullfile(cfg.dataFolder,'control_in_session');
    cfg.baseline = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted';
    cfg.problems = {'DTLZ2','DTLZ4','DTLZ5','DTLZ7'};
    cfg.runIds = 19:28;
    cfg.M = 10;
    cfg.D = 30;
    cfg.settings = ['qKeep=0.70 (relation-score quantile), nMax=6, lambdaT=0.30, ' ...
        'no p_err gate, no minimum batch completion, no second indicator filter, ' ...
        'pMix=0.50, gmax=3000, rGood=0.25'];
end

function [byRound,fileCount] = readAllRecords(cfg)
%readAllRecords Concatenate every per-round diagnostics CSV of the experiment.
    files = dir(fullfile(cfg.recordsFolder,'*_records.csv'));
    byRound = struct('ratio',{},'lambdaT',{},'setChanged',{},'firstChanged',{}, ...
        'overlap',{},'nRetained',{},'target',{},'meanAbsRankShift',{}, ...
        'problem',{});
    for i = 1:numel(files)
        T = readtable(fullfile(files(i).folder,files(i).name),'Encoding','UTF-8');
        problem = regexp(files(i).name,'_(DTLZ\d+)_','tokens');
        if isempty(problem), problem = {{'unknown'}}; end
        for k = 1:height(T)
            rec = struct('ratio',1-T.FEbefore(k)/300, ...
                'lambdaT',T.lambdaT(k),'setChanged',logical(T.setChanged(k)), ...
                'firstChanged',logical(T.firstChanged(k)), ...
                'overlap',T.overlap(k),'nRetained',T.nRetained(k), ...
                'target',T.target(k), ...
                'meanAbsRankShift',T.meanAbsRankShift(k), ...
                'problem',problem{1}{1});
            byRound(end+1) = rec; %#ok<AGROW>
        end
    end
    fileCount = numel(files);
end

function reward = summarizeReward(byRound)
%summarizeReward Aggregate the reward diagnostics overall and by time bucket.
    reward = struct('records',numel(byRound));
    reward.buckets = struct([]);
    if isempty(byRound)
        return;
    end
    ratio = [byRound.ratio]';
    lambdaT = [byRound.lambdaT]';
    setChanged = [byRound.setChanged]';
    firstChanged = [byRound.firstChanged]';
    overlap = [byRound.overlap]';
    retained = [byRound.nRetained]';
    target = [byRound.target]';
    rankShift = [byRound.meanAbsRankShift]';
    reward.meanLambdaT = mean(lambdaT);
    reward.maxLambdaT = max(lambdaT);
    reward.minLambdaT = min(lambdaT);
    reward.setChangedShare = mean(setChanged);
    reward.firstChangedShare = mean(firstChanged);
    reward.meanOverlap = mean(overlap);
    reward.meanRetained = mean(retained);
    reward.meanTarget = mean(target);
    reward.meanAbsRankShift = mean(rankShift);
    edges = [0 0.25 0.50 0.75 1.0001];
    labels = {'FE 0-25%','FE 25-50%','FE 50-75%','FE 75-100%'};
    bucket = strings(numel(ratio),1);
    for b = 1:numel(labels)
        bucket(ratio >= edges(b) & ratio < edges(b+1)) = labels{b};
    end
    names = unique(bucket,'stable');
    B = struct([]);
    for b = 1:numel(names)
        sel = bucket == names(b);
        entry = struct('bucket',char(names(b)),'rounds',sum(sel), ...
            'meanLambdaT',mean(lambdaT(sel)),'setChangedShare',mean(setChanged(sel)), ...
            'meanOverlap',mean(overlap(sel)),'meanRetained',mean(retained(sel)), ...
            'meanTarget',mean(target(sel)),'meanAbsRankShift',mean(rankShift(sel)));
        if isempty(B), B = entry; else, B(end+1) = entry; end %#ok<AGROW>
    end
    reward.buckets = B;
end

function test = pairedExact(delta)
%pairedExact Exact paired tests for the matched-pair differences.
%   signP  : two-sided sign test ignoring ties.
%   rankP  : two-sided exact Wilcoxon signed-rank test.
    delta = delta(:);
    nonzero = delta(delta ~= 0);
    n = numel(nonzero);
    test = struct('n',numel(delta),'nNonzero',n,'signP',NaN,'rankP',NaN);
    if n == 0, return; end
    nPositive = sum(nonzero > 0);
    counts = zeros(n+1,1);
    for k = 0:n
        counts(k+1) = nchoosek(n,k);
    end
    probs = counts/2^n;
    observed = min(nPositive,n-nPositive);
    test.signP = min(1,sum(probs(abs((0:n)-n/2) >= abs(observed-n/2))));
    % Wilcoxon signed-rank: exact null distribution of the positive-rank sum.
    % Averaged ranks are doubled to stay integral; the distribution is built by
    % dynamic programming, so any number of pairs is handled.
    ranks = tiedRank(abs(nonzero));
    w = round(2*ranks);
    maxSum = sum(w);
    dp = zeros(maxSum+1,1);
    dp(1) = 1;
    for i = 1:n
        step = w(i);
        nxt = dp;
        nxt(step+1:end) = nxt(step+1:end) + dp(1:end-step);
        dp = nxt;
    end
    sums = (0:maxSum)';
    wPlus = sum(w(nonzero > 0));
    centre = maxSum/2;
    test.rankP = min(1,sum(dp(abs(sums-centre) >= abs(wPlus-centre)))/2^n);
end

function r = tiedRank(values)
%tiedRank Average ranks, so that tied differences share the same rank.
    values = values(:);
    [sorted,order] = sort(values);
    r = zeros(size(values));
    i = 1;
    while i <= numel(sorted)
        j = i;
        while j < numel(sorted) && sorted(j+1) == sorted(i)
            j = j + 1;
        end
        r(order(i:j)) = (i+j)/2;
        i = j + 1;
    end
end

function writeReport(outDir,analysis,cfg)
%writeReport Markdown report with the decision-relevant numbers first.
    file = fullfile(outDir,'Lambdat030_M10_10runs_分析报告.md');
    fid = fopen(file,'w','n','UTF-8');
    assert(fid >= 0,'Cannot write the report.');
    ps = struct2table(analysis.problemSummary);
    fprintf(fid,'# Lambdat030（lambdaT=0.30）十目标 10 次配对实验\n\n');
    fprintf(fid,'生成时间：%s\n\n',char(datetime('now','Format','yyyy-MM-dd HH:mm:ss')));
    fprintf(fid,'## 1. 结论先行\n\n');
    fprintf(fid,'- 有效配对：%d 组（%s，M=%d，D=%d，N=100，maxFE=300，每题 10 次）。\n', ...
        analysis.runsPresent,strjoin(cfg.problems,'/'),cfg.M,cfg.D);
    prim = analysis.primaryVsInSessionControl;
    fprintf(fid,'- 主比较（同会话同进程池的 baseline 对照）：平均差值 %+.4g，中位 %+.4g，', ...
        prim.meanDelta,prim.medianDelta);
    fprintf(fid,'改善 %d / 变差 %d / 持平 %d，平均相对变化 %+.2f%%。\n', ...
        prim.improved,prim.worsened,prim.tied,100*prim.meanRelChange);
    fprintf(fid,'- 主比较显著性：符号检验 p=%.4g，精确 Wilcoxon p=%.4g（n=%d）。\n', ...
        prim.signP,prim.rankP,prim.n);
    sec = analysis.secondaryVsStoredControl;
    if sec.n > 0
        fprintf(fid,'- 次比较（与存盘对照，跨会话上下文）：平均差值 %+.4g，改善 %d / 变差 %d / 持平 %d，', ...
            sec.meanDelta,sec.improved,sec.worsened,sec.tied);
        fprintf(fid,'符号检验 p=%.4g。\n',sec.signP);
    end
    improved = ps(ps.meanDelta < 0,:);
    worsened = ps(ps.meanDelta > 0,:);
    if isempty(improved)
        fprintf(fid,'- 均值意义上无改善的问题。\n');
    else
        fprintf(fid,'- 均值有改善的问题：%s。\n',strjoin(cellstr(improved.problem),'、'));
    end
    if isempty(worsened)
        fprintf(fid,'- 均值变差的问题：无。\n');
    else
        fprintf(fid,'- 均值变差的问题：%s。\n',strjoin(cellstr(worsened.problem),'、'));
    end
    fprintf(fid,'\n## 2. 逐题配对结果（主比较）\n\n');
    fprintf(fid,'| 问题 | n | 均值 IGD | 对照均值 | 均值差 | 差值/对照 | 改善/变差/持平 | 符号 p | Wilcoxon p |\n');
    fprintf(fid,'|---|---:|---:|---:|---:|---:|---|---:|---:|\n');
    for i = 1:height(ps)
        fprintf(fid,'| %s | %d | %.6g | %.6g | %+.4g | %+.2f%% | %d/%d/%d | %.3g | %.3g |\n', ...
            ps.problem{i},ps.n(i),ps.meanIGD(i),ps.meanControlIGD(i), ...
            ps.meanDelta(i),100*ps.meanRelChange(i),ps.improved(i), ...
            ps.worsened(i),ps.tied(i),ps.signP(i),ps.rankP(i));
    end
    sst = struct2table(analysis.problemSummaryStored);
    if ~isempty(sst) && height(sst) > 0
        fprintf(fid,'\n## 3. 与存盘对照的比较（跨会话上下文，仅供参考）\n\n');
        fprintf(fid,'| 问题 | n | Lambdat030 均值 | 存盘对照均值 | 均值差 | 改善/变差/持平 | 符号 p |\n');
        fprintf(fid,'|---|---:|---:|---:|---:|---|---:|\n');
        for i = 1:height(sst)
            fprintf(fid,'| %s | %d | %.6g | %.6g | %+.4g | %d/%d/%d | %.3g |\n', ...
                sst.problem{i},sst.n(i),sst.meanIGD(i),sst.meanControlIGD(i), ...
                sst.meanDelta(i),sst.improved(i),sst.worsened(i),sst.tied(i), ...
                sst.signP(i));
        end
    end
    r = analysis.reward;
    fprintf(fid,'\n## 4. 奖励机制的实际作用\n\n');
    fprintf(fid,'- 探索轮次记录：%d 条（指标准则轮次不计入）。\n',r.records);
    fprintf(fid,'- 有效奖励权重 lambda_t = 0.30 (fixed)：平均 %.4g，范围 %.4g ~ %.4g。\n', ...
        r.meanLambdaT,r.minLambdaT,r.maxLambdaT);
    fprintf(fid,'- 奖励改变批次的轮次比例：%.1f%%（首个候选改变 %.1f%%）。\n', ...
        100*r.setChangedShare,100*r.firstChangedShare);
    fprintf(fid,'- 奖励前后批次重叠率：%.3f；保留集合平均 %.1f 个，平均取 %.2f 个。\n', ...
        r.meanOverlap,r.meanRetained,r.meanTarget);
    fprintf(fid,'\n| 阶段 | 轮次 | 平均 lambda_t | 批次被改变比例 | 平均重叠 | 平均保留数 | 平均取数 |\n');
    fprintf(fid,'|---|---:|---:|---:|---:|---:|---:|\n');
    b = r.buckets;
    for i = 1:numel(b)
        fprintf(fid,'| %s | %d | %.4f | %.1f%% | %.3f | %.1f | %.2f |\n', ...
            b(i).bucket,b(i).rounds,b(i).meanLambdaT, ...
            100*b(i).setChangedShare,b(i).meanOverlap,b(i).meanRetained, ...
            b(i).meanTarget);
    end
    fprintf(fid,'\n## 5. 固定设置与对照说明\n\n');
    fprintf(fid,'算法：`%s`\n\n',analysis.algorithm);
    fprintf(fid,'参数：%s\n\n',cfg.settings);
    fprintf(fid,'运行编号：%d..%d；种子 20260912+M*1e5+pi*1e3+runId，两臂完全一致。\n\n', ...
        cfg.runIds(1),cfg.runIds(end));
    fprintf(fid,'对照说明：同一份源码、同一个种子，在本机不同执行上下文下会给出不同轨迹，\n');
    fprintf(fid,'因此主比较使用本会话内重跑的 baseline 对照；存盘对照仅作参考。\n');
    if ~isempty(analysis.runsMissing)
        fprintf(fid,'\n缺失配对（未纳入统计）：%s\n',strjoin(analysis.runsMissing,'、'));
    end
    fclose(fid);
end
