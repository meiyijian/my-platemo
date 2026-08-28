function outputFiles = make_GoodGroupPrecisionVisualizations()
%MAKE_GOODGROUPPRECISIONVISUALIZATIONS Export paper-style result figures.
%   The visual style follows a compact academic ablation bar chart: warm
%   white background, serif typography, muted bars, dashed horizontal grids,
%   black error bars, direct value labels, and short explanatory footnotes.

experimentDir = fileparts(mfilename('fullpath'));
formalDir     = fullfile(experimentDir,'results','analysis','formal');
outputDir     = fullfile(formalDir,'visualizations');
pairedFile    = fullfile(formalDir,'GGP_PairedComparisons.csv');
stageFile     = fullfile(formalDir,'GGP_PerRunStage.csv');

assert(isfile(pairedFile),'Missing formal result: %s',pairedFile);
assert(isfile(stageFile),'Missing formal result: %s',stageFile);
if ~isfolder(outputDir)
    mkdir(outputDir);
end

P = readtable(pairedFile,'TextType','string');
S = readtable(stageFile,'TextType','string');

fontName = localPaperFont();
colors.background = [0.984 0.979 0.960];
colors.hybrid     = [0.55 0.72 0.72];
colors.v          = [0.58 0.63 0.67];
colors.anchor     = [0.35 0.46 0.64];
colors.loss       = [0.84 0.46 0.37];
colors.accent     = [0.91 0.40 0.12];
colors.grid       = [0.58 0.61 0.63];
colors.text       = [0.04 0.04 0.035];
colors.muted      = [0.28 0.29 0.29];

outputFiles = strings(3,1);
outputFiles(1) = localOverviewFigure(P,outputDir,fontName,colors);
outputFiles(2) = localStageComparisonFigure(P,S,outputDir,fontName,colors);
outputFiles(3) = localDTLZM20Figure(S,outputDir,fontName,colors);

fprintf('Generated paper-style Good-group Precision visualizations:\n');
fprintf('  %s\n',outputFiles);
end

function outputFile = localOverviewFigure(P,outputDir,fontName,colors)
configs = unique(P(:,{'Problem','M'}),'rows','stable');
n = height(configs);
wins = zeros(n,1);
losses = zeros(n,1);
for i = 1:n
    mask = P.Problem == configs.Problem(i) & P.M == configs.M(i) & ...
        P.Truth == "population_final" & P.ViewA == "score_hybrid" & ...
        P.RejectHolm05 == 1 & P.ValidPairs > 0;
    wins(i)   = sum(mask & P.MeanDelta > 0);
    losses(i) = sum(mask & P.MeanDelta < 0);
end

labels = configs.Problem + "-M" + string(configs.M);

f = figure('Color',colors.background,'Position',[45 45 1950 1050],'Visible','off');
localTitle(f,fontName,colors, ...
    'Good-group Hybrid：各问题配置的显著比较结果', ...
    'population_final；Holm 校正后的显著比较结果（25 次配对运行）');

ax = axes(f,'Position',[0.06 0.25 0.78 0.61]);
data = [wins losses];
b = bar(ax,1:numel(wins),data,0.76,'grouped','EdgeColor','none');
b(1).FaceColor = colors.hybrid;
b(2).FaceColor = colors.loss;
hold(ax,'on');
localPaperAxes(ax,fontName,colors);
ax.XTick = 1:numel(labels);
ax.XTickLabel = labels;
ax.TickLabelInterpreter = 'none';
ax.XTickLabelRotation = 25;
ax.FontSize = 10;
yMax = max([wins;losses]) + 3;
ylim(ax,[0 yMax]);
yticks(ax,0:2:yMax);
ylabel(ax,'显著比较数量','FontName',fontName,'FontSize',14,'FontWeight','bold');

for k = 1:2
    for i = 1:numel(wins)
        value = data(i,k);
        if value > 0
            text(ax,b(k).XEndPoints(i),value+0.28,sprintf('%d',value), ...
                'HorizontalAlignment','center','VerticalAlignment','bottom', ...
                'FontName',fontName,'FontSize',11,'Color',colors.text);
        end
    end
end
localAddAccent(ax,b(1).XEndPoints,wins,0.12,colors.accent);

lg = legend(ax,b,{'Hybrid 显著更好','Hybrid 显著更差'}, ...
    'Position',[0.855 0.67 0.125 0.12],'Box','on','Color',colors.background, ...
    'EdgeColor',colors.text,'FontName',fontName,'FontSize',11);
lg.ItemTokenSize = [22 12];

annotation(f,'textbox',[0.08 0.145 0.84 0.045], ...
    'String','图中纳入正式实验的全部 10 个 Problem-M 配置，并同时统计显著改进与显著退化。', ...
    'EdgeColor','none','FontName',fontName,'FontSize',12, ...
    'FontWeight','bold','Color',colors.text,'HorizontalAlignment','center');
localMetricFootnote(f,fontName,colors,[0.055 0.065 0.89 0.06]);
annotation(f,'textbox',[0.08 0.018 0.84 0.035], ...
    'String','“胜/负”覆盖 S1–S4、Precision/AUC/Lift，以及对 V-score 和 Anchor margin 的比较。', ...
    'EdgeColor','none','FontName',fontName,'FontSize',10, ...
    'Color',colors.muted,'HorizontalAlignment','center');

outputFile = fullfile(outputDir,'GGP_01_all_configs_overview.png');
exportgraphics(f,outputFile,'Resolution',220);
close(f);
end

function outputFile = localStageComparisonFigure(P,S,outputDir,fontName,colors)
metricNames  = ["Precision","AUC","Lift"];
metricVars   = ["MeanPrecision","MeanAUC","MeanLift"];
metricTitles = ["Precision（命中率）","AUC（排序能力）","Lift（相对随机提升）"];
viewNames    = ["score_hybrid","score_v","anchor_margin"];
viewLabels   = ["Hybrid","V-score","Anchor margin"];
barColors    = [colors.hybrid;colors.v;colors.anchor];
means = nan(3,3);
stds  = nan(3,3);
pValues = nan(3,2);

for m = 1:3
    for v = 1:3
        mask = S.Problem == "DTLZ4" & S.M == 20 & startsWith(S.Stage,"S3") & ...
            S.Truth == "population_final" & S.View == viewNames(v) & ...
            S.SelectionRule == "top25";
        values = S.(metricVars(m))(mask);
        means(m,v) = mean(values,'omitnan');
        stds(m,v)  = std(values,'omitnan');
    end
    compareMask = P.Problem == "DTLZ4" & P.M == 20 & startsWith(P.Stage,"S3") & ...
        P.Truth == "population_final" & P.Metric == metricNames(m) & ...
        P.ViewA == "score_hybrid";
    rowV = P(compareMask & P.ViewB == "score_v",:);
    rowA = P(compareMask & P.ViewB == "anchor_margin",:);
    assert(height(rowV) == 1 && height(rowA) == 1, ...
        'Expected one paired-comparison row for each baseline.');
    pValues(m,:) = [rowV.PValueHolm rowA.PValueHolm];
end

f = figure('Color',colors.background,'Position',[35 35 1850 1050],'Visible','off');
localTitle(f,fontName,colors, ...
    'DTLZ4-M20：S3 阶段指标对比', ...
    'population_final；Hybrid、V-score 与 Anchor margin 的配对结果');

axesPos = [0.055 0.32 0.27 0.50; 0.365 0.32 0.27 0.50; 0.675 0.32 0.27 0.50];
for m = 1:3
    ax = axes(f,'Position',axesPos(m,:));
    b = bar(ax,1:3,means(m,:),0.64,'FaceColor','flat','EdgeColor','none');
    b.CData = barColors;
    hold(ax,'on');
    e = errorbar(ax,1:3,means(m,:),stds(m,:),'k','LineStyle','none', ...
        'LineWidth',1.0,'CapSize',8);
    e.HandleVisibility = 'off';
    localPaperAxes(ax,fontName,colors);
    ax.XTick = 1:3;
    ax.XTickLabel = viewLabels;
    ax.TickLabelInterpreter = 'none';
    ylim(ax,localMetricLimit(metricNames(m),means(m,:),stds(m,:)));
    ylabel(ax,'指标值','FontName',fontName,'FontSize',12,'FontWeight','bold');
    title(ax,{metricTitles(m),sprintf('H>V: p=%.4f   |   H>A: p=%.4f', ...
        pValues(m,1),pValues(m,2))},'FontName',fontName,'FontSize',14, ...
        'FontWeight','bold','Color',colors.text);
    localReferenceLine(ax,metricNames(m),fontName,colors);
    yRange = diff(ylim(ax));
    for v = 1:3
        text(ax,v,means(m,v)+stds(m,v)+0.018*yRange,sprintf('%.3f',means(m,v)), ...
            'HorizontalAlignment','center','VerticalAlignment','bottom', ...
            'FontName',fontName,'FontSize',10,'Color',colors.text);
    end
    localAddAccent(ax,1,means(m,1),0.19,colors.accent);
end
annotation(f,'textbox',[0.08 0.205 0.84 0.05], ...
    'String','结果：该配置的 S3 阶段中，Hybrid 在三项指标上均显著优于两个单一视图。', ...
    'EdgeColor','none','FontName',fontName,'FontSize',12, ...
    'FontWeight','bold','Color',colors.text,'HorizontalAlignment','center');
localMetricFootnote(f,fontName,colors,[0.055 0.105 0.89 0.07]);
annotation(f,'textbox',[0.08 0.04 0.84 0.04], ...
    'String','误差线 = 25 次配对运行的 ±1 标准差；p 值经过 Holm 多重比较校正。', ...
    'EdgeColor','none','FontName',fontName,'FontSize',10, ...
    'Color',colors.muted,'HorizontalAlignment','center');

outputFile = fullfile(outputDir,'GGP_02_DTLZ4_M20_S3_comparison.png');
exportgraphics(f,outputFile,'Resolution',220);
close(f);
end

function outputFile = localDTLZM20Figure(S,outputDir,fontName,colors)
problemNames = ["DTLZ4","DTLZ2","DTLZ7"];
mValues = [20 20 20];
configLabels = problemNames + "-M" + string(mValues);
viewNames = ["score_hybrid","score_v","anchor_margin"];
viewLabels = ["Hybrid","V-score","Anchor margin"];
metricNames = ["Precision","AUC","Lift"];
metricVars = ["MeanPrecision","MeanAUC","MeanLift"];
metricTitles = ["Precision（命中率）","AUC（排序能力）","Lift（相对随机提升）"];
barColors = [colors.hybrid;colors.v;colors.anchor];
means = nan(3,3,3);
stds  = nan(3,3,3);

for c = 1:3
    for v = 1:3
        baseMask = S.Problem == problemNames(c) & S.M == mValues(c) & ...
            S.Truth == "population_final" & S.View == viewNames(v) & ...
            S.SelectionRule == "top25";
        runs = unique(S.Run(baseMask));
        assert(numel(runs) == 25,'Expected 25 runs for each selected configuration.');
        for m = 1:3
            runMeans = nan(numel(runs),1);
            for r = 1:numel(runs)
                values = S.(metricVars(m))(baseMask & S.Run == runs(r));
                runMeans(r) = mean(values,'omitnan');
            end
            means(c,v,m) = mean(runMeans,'omitnan');
            stds(c,v,m)  = std(runMeans,'omitnan');
        end
    end
end

f = figure('Color',colors.background,'Position',[35 35 1900 1080],'Visible','off');
localTitle(f,fontName,colors, ...
    'DTLZ 系列 M=20 的阶段平均效果', ...
    'population_final；每次运行先对 S1–S4 取平均，再汇总 25 次运行');

axesPos = [0.055 0.30 0.27 0.43; 0.365 0.30 0.27 0.43; 0.675 0.30 0.27 0.43];
legendHandles = gobjects(1,3);
for m = 1:3
    ax = axes(f,'Position',axesPos(m,:));
    currentMeans = squeeze(means(:,:,m));
    currentStds = squeeze(stds(:,:,m));
    b = bar(ax,currentMeans,0.76,'grouped','EdgeColor','none');
    hold(ax,'on');
    limits = localMetricLimit(metricNames(m),currentMeans,currentStds);
    for v = 1:3
        b(v).FaceColor = barColors(v,:);
        e = errorbar(ax,b(v).XEndPoints,currentMeans(:,v),currentStds(:,v), ...
            'k','LineStyle','none','LineWidth',0.9,'CapSize',6);
        e.HandleVisibility = 'off';
        for c = 1:3
            text(ax,b(v).XEndPoints(c),currentMeans(c,v)+currentStds(c,v)+ ...
                0.014*diff(limits),sprintf('%.3f',currentMeans(c,v)), ...
                'HorizontalAlignment','center','VerticalAlignment','bottom', ...
                'FontName',fontName,'FontSize',8.5,'Color',colors.text);
        end
        if m == 1
            legendHandles(v) = b(v);
        end
    end
    localPaperAxes(ax,fontName,colors);
    ax.XTick = 1:3;
    ax.XTickLabel = configLabels;
    ax.TickLabelInterpreter = 'none';
    ylim(ax,limits);
    ylabel(ax,'阶段平均值','FontName',fontName,'FontSize',12,'FontWeight','bold');
    title(ax,metricTitles(m),'FontName',fontName,'FontSize',15, ...
        'FontWeight','bold','Color',colors.text);
    localReferenceLine(ax,metricNames(m),fontName,colors);
    localAddAccent(ax,b(1).XEndPoints,currentMeans(:,1),0.055,colors.accent);
end

lg = legend(legendHandles,cellstr(viewLabels),'Orientation','horizontal', ...
    'Position',[0.365 0.775 0.28 0.050],'Box','on','Color',colors.background, ...
    'EdgeColor',colors.text,'FontName',fontName,'FontSize',10);
lg.ItemTokenSize = [18 11];
annotation(f,'textbox',[0.065 0.205 0.87 0.055], ...
    'String',['DTLZ4-M20 中 Hybrid 高于两个单一视图；' ...
    'DTLZ2/DTLZ7-M20 中 Hybrid 与 V-score 接近，并高于 Anchor margin。'], ...
    'EdgeColor','none','FontName',fontName,'FontSize',11.5, ...
    'FontWeight','bold','Color',colors.text,'HorizontalAlignment','center');
localMetricFootnote(f,fontName,colors,[0.055 0.105 0.89 0.07]);
annotation(f,'textbox',[0.08 0.04 0.84 0.04], ...
    'String','误差线 = 25 次运行的 ±1 标准差；本图为描述性均值，显著性以配对检验结果为准。', ...
    'EdgeColor','none','FontName',fontName,'FontSize',10, ...
    'Color',colors.muted,'HorizontalAlignment','center');

outputFile = fullfile(outputDir,'GGP_03_DTLZ_M20_metric_comparison.png');
exportgraphics(f,outputFile,'Resolution',220);
close(f);
end

function localTitle(f,fontName,colors,titleText,subtitleText)
annotation(f,'textbox',[0.055 0.925 0.89 0.055], ...
    'String',titleText,'EdgeColor','none','FontName',fontName, ...
    'FontSize',22,'FontWeight','bold','Color',colors.text, ...
    'HorizontalAlignment','center');
annotation(f,'textbox',[0.07 0.885 0.86 0.032], ...
    'String',subtitleText,'EdgeColor','none','FontName',fontName, ...
    'FontSize',11.5,'Color',colors.muted,'HorizontalAlignment','center');
end

function localPaperAxes(ax,fontName,colors)
set(ax,'FontName',fontName,'FontSize',11,'Color',colors.background, ...
    'Box','off','LineWidth',1.15,'TickDir','out','Layer','top', ...
    'XColor',colors.text,'YColor',colors.text,'YGrid','on','XGrid','off', ...
    'GridLineStyle','--','GridColor',colors.grid,'GridAlpha',0.58);
end

function localMetricFootnote(f,fontName,colors,position)
textLine = ['Precision＝Top25 中最终真正保留的比例（越高越好）；' ...
    'AUC＝排序能力（0.5≈随机）；Lift＝Precision/正类比例（>1 优于随机）。'];
annotation(f,'textbox',position,'String',textLine,'EdgeColor','none', ...
    'FontName',fontName,'FontSize',10.5,'Color',colors.text, ...
    'HorizontalAlignment','center','VerticalAlignment','middle');
end

function localReferenceLine(ax,metricName,fontName,colors)
if metricName == "AUC"
    yline(ax,0.5,'--','随机水平 0.5','Color',colors.grid, ...
        'LineWidth',0.9,'LabelHorizontalAlignment','left', ...
        'FontName',fontName,'FontSize',9);
elseif metricName == "Lift"
    yline(ax,1,'--','随机水平 1.0','Color',colors.grid, ...
        'LineWidth',0.9,'LabelHorizontalAlignment','left', ...
        'FontName',fontName,'FontSize',9);
end
end

function limits = localMetricLimit(metricName,means,stds)
upper = max(means + stds,[],'all','omitnan');
if metricName == "Precision"
    top = max(0.65,ceil((upper+0.06)*10)/10);
    top = min(top,1.0);
elseif metricName == "AUC"
    top = max(0.75,ceil((upper+0.06)*10)/10);
    top = min(top,1.0);
else
    top = max(1.65,ceil((upper+0.14)*10)/10);
end
limits = [0 top];
end

function localAddAccent(ax,x,y,halfWidth,accentColor)
for i = 1:numel(x)
    plot(ax,[x(i)-halfWidth x(i)+halfWidth],[y(i) y(i)], ...
        'Color',accentColor,'LineWidth',1.0,'HandleVisibility','off');
end
end

function fontName = localPaperFont()
available = string(listfonts);
candidates = ["Microsoft YaHei","Microsoft YaHei UI","SimHei","Arial Unicode MS","Arial"];
fontName = "Times New Roman";
for i = 1:numel(candidates)
    if any(strcmpi(available,candidates(i)))
        fontName = candidates(i);
        break;
    end
end
end
