function out = PlotConvergenceCurves(problem,varargin)
%PLOTCONVERGENCECURVES Draw median convergence curves of one problem on the
%   current axes, using the per-generation metric traces stored by PlatEMO.
%
%   out = PlotConvergenceCurves(problem,'Name',Value,...)
%
%   Saved result files produced with 'save',K contain two things that matter
%   here:
%       result(:,1)  - number of function evaluations at each snapshot
%       metric.NAME  - metric value of every snapshot, i.e. the trajectory
%   Snapshot counts differ between algorithms, so every run is resampled onto
%   a common FE grid with zero-order hold (an IGD value only improves when a
%   new snapshot is written, so 'previous' is the correct interpolation).
%
%   Name-Value pairs
%     'dataRoot'    (required) folder containing one subfolder per algorithm
%     'algorithms'  (required) cell array of algorithm folder names
%     'metric'      'IGD' (default) | 'IGDp' | 'HV' | any stored field
%     'M'           number of objectives, default 10
%     'runs'        run ids to read, default 1:30
%     'maxFE'       evaluation budget used as x-axis limit, default 300
%     'gridStep'    FE spacing of the common grid, default 1
%     'logY'        log-scaled metric axis, default true
%     'labels'      legend entries, default = algorithm folder names
%     'colors'      N-by-3 RGB matrix, default a fixed palette
%     'lineStyles'  cell of LineSpec strings, default solid/dashed cycle
%     'showFinal'   append median final metric to the legend, default true
%     'lineWidth'   default 1.8
%     'fontSize'    default 10
%     'titleText'   axes title, default derived from problem/M/D/metric
%     'titleMode'   'full' (default) | 'compact' (problem name only) | 'none'
%     'showAxisLabels'  write xlabel/ylabel, default true
%     'maxD'        override the D shown in the title (otherwise parsed from
%                   the file name, e.g. WFG2 uses D=31)
%     'verbose'     print a per-algorithm summary table, default true
%
%   out.curves{a}  struct with fields x, q25, q50, q75, runs, finalMedian
%
%   Example
%     PlotConvergenceCurves('DTLZ1','dataRoot',root, ...
%         'algorithms',{'REMO','REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_Weighted'}, ...
%         'metric','IGD','M',10,'maxFE',300);

    parser = inputParser;
    parser.addRequired('problem',@(x)ischar(x)||isstring(x));
    parser.addParameter('dataRoot','',@(x)ischar(x)||isstring(x));
    parser.addParameter('algorithms',{},@iscell);
    parser.addParameter('metric','IGD',@(x)ischar(x)||isstring(x));
    parser.addParameter('M',10,@(x)isnumeric(x)&&isscalar(x));
    parser.addParameter('runs',1:30,@isnumeric);
    parser.addParameter('maxFE',300,@(x)isnumeric(x)&&isscalar(x));
    parser.addParameter('gridStep',1,@(x)isnumeric(x)&&isscalar(x)&&x>0);
    parser.addParameter('logY',true,@islogical);
    parser.addParameter('labels',{},@iscell);
    parser.addParameter('colors',[],@isnumeric);
    parser.addParameter('lineStyles',{},@iscell);
    parser.addParameter('showFinal',true,@islogical);
    parser.addParameter('lineWidth',1.8,@isnumeric);
    parser.addParameter('fontSize',10,@isnumeric);
    parser.addParameter('titleText','',@(x)ischar(x)||isstring(x));
    parser.addParameter('titleMode','full',@(x)ischar(x)||isstring(x));
    parser.addParameter('showAxisLabels',true,@islogical);
    parser.addParameter('maxD',[],@(x)isempty(x)||isnumeric(x));
    parser.addParameter('verbose',true,@islogical);
    parser.addParameter('axes',[],@(x)isempty(x)||isa(x,'matlab.graphics.axis.Axes')||isnumeric(x));
    parser.parse(problem,varargin{:});
    c = parser.Results;

    problem  = char(problem);
    dataRoot = char(c.dataRoot);
    metric   = char(c.metric);
    nAlg     = numel(c.algorithms);
    assert(nAlg >= 1,'At least one algorithm folder is required.');
    assert(isfolder(dataRoot),'dataRoot does not exist: %s',dataRoot);

    if isempty(c.labels)
        labels = c.algorithms;
    else
        assert(numel(c.labels) == nAlg,'labels must match algorithms.');
        labels = c.labels;
    end
    if isempty(c.colors)
        base = [0.12 0.42 0.72; 0.85 0.22 0.18; 0.16 0.62 0.40; ...
                0.55 0.28 0.72; 0.90 0.58 0.10; 0.30 0.30 0.30];
        colors = base(1+mod(0:nAlg-1,size(base,1)),:);
    else
        colors = c.colors;
    end
    if isempty(c.lineStyles)
        pool = {'-','--','-.',':'};
        lineStyles = pool(1+mod(0:nAlg-1,numel(pool)));
    else
        lineStyles = c.lineStyles;
    end

    grid  = 0 : c.gridStep : c.maxFE;
    nGrid = numel(grid);
    curves = cell(1,nAlg);
    summary = cell(nAlg,1);
    seenD = [];

    for a = 1 : nAlg
        folder = fullfile(dataRoot, c.algorithms{a});
        assert(isfolder(folder),'Algorithm folder not found: %s',folder);
        trace = nan(numel(c.runs), nGrid);
        lastSnap = nan(1,numel(c.runs));
        used  = 0; missing = {};
        for k = 1 : numel(c.runs)
            r = c.runs(k);
            files = dir(fullfile(folder,sprintf('*_%s_M%d_D*_%d.mat',problem,c.M,r)));
            if isempty(files), missing{end+1} = sprintf('run %d',r); continue; end  %#ok<AGROW>
            if isempty(seenD)
                tok = regexp(files(1).name,'_D(\d+)_','tokens','once');
                if ~isempty(tok), seenD = str2double(tok{1}); end
            end
            [x,y] = readTrace(fullfile(folder,files(1).name),metric);
            if isempty(x), missing{end+1} = sprintf('run %d (no %s)',r,metric); continue; end  %#ok<AGROW>
            used = used + 1;
            trace(used,:) = resample(x,y,grid);
            lastSnap(used) = y(end);      % value at the run's own final snapshot
        end
        trace    = trace(1:used,:);
        lastSnap = lastSnap(1:used);
        assert(used > 0,'No usable run for %s on %s (metric %s).', ...
            c.algorithms{a},problem,metric);
        if ~isempty(missing) && c.verbose
            warning('PlotConvergenceCurves:SkippedRuns','%s / %s: skipped %s', ...
                c.algorithms{a},problem,strjoin(missing,', '));
        end
        q25 = localQuantile(trace,25);
        q50 = localQuantile(trace,50);
        q75 = localQuantile(trace,75);
        curves{a} = struct('x',grid,'q25',q25,'q50',q50,'q75',q75, ...
            'runs',trace,'nRuns',used,'finalMedian',q50(end), ...
            'finalSnapshotMedian',median(lastSnap));
        summary{a} = sprintf(['%-46s runs=%2d  %s at FE=%g = %.4g  ' ...
            '(IQR %.4g - %.4g)  last-snapshot median = %.4g'], ...
            c.algorithms{a}, used, metric, c.maxFE, q50(end), q25(end), q75(end), ...
            curves{a}.finalSnapshotMedian);
    end

    %% Draw
    if isempty(c.maxD), Dshown = seenD; else, Dshown = c.maxD; end
    if isempty(c.axes), ax = gca; else, ax = c.axes; end
    hold(ax,'on');
    h = gobjects(1,nAlg);
    for a = 1 : nAlg
        x = curves{a}.x; y50 = curves{a}.q50; y25 = curves{a}.q25; y75 = curves{a}.q75;
        band = fill(ax,[x,fliplr(x)],[y25,fliplr(y75)],colors(a,:), ...
            'FaceAlpha',0.16,'EdgeColor','none');
        set(band,'HandleVisibility','off');
        h(a) = plot(ax,x,y50,lineStyles{a},'Color',colors(a,:), ...
            'LineWidth',c.lineWidth);
    end
    hold(ax,'off');

    if c.showFinal
        for a = 1 : nAlg
            labels{a} = sprintf('%s (%s=%.4g)',labels{a},metric,curves{a}.finalMedian);
        end
    end
    lg = legend(ax,h,labels,'Location','northeast','Interpreter','none', ...
        'FontSize',c.fontSize-1);
    set(lg,'Box','on');
    if c.showAxisLabels
        xlabel(ax,'Number of function evaluations','FontSize',c.fontSize);
        ylabel(ax,strrep(metric,'_',' '),'FontSize',c.fontSize);
    end
    if ~isempty(c.titleText)
        title(ax,c.titleText,'Interpreter','none','FontSize',c.fontSize+1);
    else
        switch lower(c.titleMode)
            case 'none'
                % leave the axes untitled
            case 'compact'
                title(ax,problem,'Interpreter','none','FontSize',c.fontSize+1);
            otherwise
                if isempty(Dshown)
                    title(ax,sprintf('%s (M=%d, %d runs, median with IQR band)', ...
                        problem,c.M,curves{1}.nRuns), ...
                        'Interpreter','none','FontSize',c.fontSize+1);
                else
                    title(ax,sprintf(['%s (M=%d, D=%d, %d runs, ' ...
                        'median with IQR band)'],problem,c.M,Dshown,curves{1}.nRuns), ...
                        'Interpreter','none','FontSize',c.fontSize+1);
                end
        end
    end
    xlim(ax,[0 c.maxFE]);
    if c.logY
        allY = cell2mat(cellfun(@(s)s.runs(:),curves,'UniformOutput',false)');
        if any(allY(:) > 0)
            set(ax,'YScale','log');
            ylim(ax,[min(allY(allY>0))*0.85, max(allY(:))*1.15]);
        end
    end
    box(ax,'on');
    set(ax,'FontSize',c.fontSize,'LineWidth',0.8,'TickDir','out');

    out = struct('curves',{curves},'legendLabels',{labels}, ...
        'colors',colors,'summary',{summary},'problem',problem,'metric',metric, ...
        'D',Dshown,'M',c.M,'maxFE',c.maxFE);

    if c.verbose
        fprintf('\n[%s | %s | M=%d]\n',problem,metric,c.M);
        for a = 1 : nAlg, fprintf('  %s\n',summary{a}); end
    end
end

% ------------------------------------------------------------------------
function [x,y] = readTrace(file,metric)
%readTrace Read the FE column and one metric trace from a saved result file.
%   'metric' is a plain struct, so matfile can partial-load it cleanly. The
%   'result' cell holds SOLUTION objects, which matfile cannot partial-load
%   from a -v7 file, so it is read with a plain (tiny) load call instead.

    x = []; y = [];
    try
        m = matfile(file);
        names = who(m);
        if ~ismember('metric',names) || ~ismember('result',names), return; end
        met = m.metric;
        if ~isfield(met,metric), return; end
        y = met.(metric)(:);
        state = warning('off','all');
        try
            S = load(file,'result');
            x = cellfun(@(v)v(1),S.result(:,1));
            x = x(:);
        catch
            x = [];
        end
        warning(state);
    catch
        x = []; y = [];
    end
    if numel(x) ~= numel(y), x = []; y = []; end
end

% ------------------------------------------------------------------------
function g = resample(x,y,grid)
%resample Zero-order-hold resampling of a trace onto a common FE grid.

    x = x(:); y = y(:);
    keep = isfinite(x) & isfinite(y);
    x = x(keep); y = y(keep);
    if isempty(x), g = nan(size(grid)); return; end
    [xu,ia] = unique(x,'last');   % duplicated FE -> last snapshot wins
    yu = y(ia);
    [xu,order] = sort(xu); yu = yu(order);
    if numel(xu) == 1
        g = repmat(yu,size(grid));
        g(grid < xu) = NaN;
        return;
    end
    g = interp1(xu,yu,grid,'previous','extrap');
    g = reshape(g,1,[]);                           % always a row
    g(grid < xu(1)) = NaN;
end

% ------------------------------------------------------------------------
function q = localQuantile(M,p)
%localQuantile Column-wise percentile without the Statistics Toolbox.
%   NaNs are dropped per column, so runs whose trace has not started yet at
%   a given FE point do not drag the quantile down.

    M = sort(M,1);
    n = size(M,1);
    if n == 0, q = nan(1,size(M,2)); return; end
    bad = isnan(M);
    M(bad) = Inf;                     % push NaN to the end of each column
    m = sum(~bad,1);                  % valid count per column
    q = nan(1,size(M,2));
    for j = 1 : size(M,2)
        if m(j) == 0, continue; end
        col = M(1:m(j),j);
        if m(j) == 1, q(j) = col; continue; end
        idx = (p/100) * (m(j)-1) + 1;
        lo = floor(idx); hi = ceil(idx); w = idx - lo;
        q(j) = (1-w)*col(lo) + w*col(hi);
    end
end
