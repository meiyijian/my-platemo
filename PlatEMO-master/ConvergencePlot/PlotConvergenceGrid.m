function out = PlotConvergenceGrid(varargin)
%PLOTCONVERGENCEGRID Compose convergence curves of many problems into one
%   figure and export it, plus optionally one standalone figure per problem.
%
%   out = PlotConvergenceGrid('Name',Value,...)
%
%   Accepts every Name-Value pair of PlotConvergenceCurves, plus:
%     'problems'         (required) cell array of problem names
%     'outputDir'        (required) folder for the exported figures
%     'fileTag'          base file name, default 'convergence'
%     'formats'          default {'png'} (also 'pdf','eps','fig')
%     'gridShape'        [nRow nCol], default the squarest fit
%     'gridLabels'       short legend entries used in the grid only; the
%                        per-problem figures keep the full labels
%     'visible'          'off' (default) exports without flashing windows
%     'perProblemFiles'  also export one figure per problem, default true
%     'quiet'            suppress the per-algorithm summary table, default true
%     'caption'          layout title; default is built from the settings
%
%   The grid uses compact panel titles and one shared pair of axis labels so
%   that sixteen panels fit without overlapping text.
%
%   Example
%     PlotConvergenceGrid('problems',{'DTLZ1','WFG1'},'dataRoot',root, ...
%         'algorithms',{'REMO','MyAlg'},'M',10,'outputDir',pwd);

    known = {'problems','outputDir','fileTag','formats','gridShape', ...
             'gridLabels','visible','perProblemFiles','quiet','caption'};
    parser = inputParser;
    parser.KeepUnmatched = true;
    parser.addParameter('problems',{},@iscell);
    parser.addParameter('outputDir','',@(x)ischar(x)||isstring(x));
    parser.addParameter('fileTag','convergence',@(x)ischar(x)||isstring(x));
    parser.addParameter('formats',{'png'},@iscell);
    parser.addParameter('gridShape',[],@isnumeric);
    parser.addParameter('gridLabels',{},@iscell);
    parser.addParameter('visible','off',@(x)ischar(x)||isstring(x));
    parser.addParameter('perProblemFiles',true,@islogical);
    parser.addParameter('quiet',true,@islogical);
    parser.addParameter('caption','',@(x)ischar(x)||isstring(x));
    parser.parse(varargin{:});
    o = parser.Results;

    % Forward everything that belongs to PlotConvergenceCurves.
    unmatched = parser.Unmatched;
    passthrough = {};
    fn = fieldnames(unmatched);
    for i = 1 : numel(fn)
        if ~ismember(fn{i},known)
            passthrough(end+1:end+2) = {fn{i},unmatched.(fn{i})}; %#ok<AGROW>
        end
    end

    problems = o.problems;
    nP = numel(problems);
    assert(nP > 0,'problems is required.');
    assert(isfolder(o.outputDir),'outputDir does not exist: %s',o.outputDir);
    if isempty(o.gridShape)
        nCol = ceil(sqrt(nP)); nRow = ceil(nP/nCol);
    else
        nRow = o.gridShape(1); nCol = o.gridShape(2);
    end

    fprintf('=== PlotConvergenceGrid: %d problems, %s, grid %dx%d ===\n', ...
        nP,o.fileTag,nRow,nCol);
    fig = figure('Visible',o.visible,'Color','w', ...
        'Position',[60 40 280*nCol 200*nRow],'NumberTitle','off', ...
        'Name',sprintf('%s grid',o.fileTag));
    tl = tiledlayout(fig,nRow,nCol,'Padding','compact','TileSpacing','compact');
    plots = cell(1,nP);
    for i = 1 : nP
        ax = nexttile;
        extra = passthrough;
        if ~isempty(o.gridLabels)
            extra = replaceOption(extra,'labels',o.gridLabels);
        end
        plots{i} = PlotConvergenceCurves(problems{i},'verbose',~o.quiet, ...
            'axes',ax,'titleMode','compact','showAxisLabels',false, ...
            'fontSize',9,extra{:});
        set(ax,'FontSize',8);
        if ~isempty(ax.Legend)
            set(ax.Legend,'FontSize',7.5,'Location','northeast');
        end
        if ~isempty(ax.Title), set(ax.Title,'FontSize',11); end
        drawnow;
    end

    if isempty(o.caption)
        mn = min(cellfun(@(s)s.M,plots));
        if isnan(plots{1}.D)
            caption = sprintf('%s convergence, M=%d, %d runs, median with IQR band', ...
                plots{1}.metric,mn,plots{1}.curves{1}.nRuns);
        else
            caption = sprintf('%s convergence, M=%d, D=%d, %d runs, median with IQR band', ...
                plots{1}.metric,mn,plots{1}.D,plots{1}.curves{1}.nRuns);
        end
    else
        caption = o.caption;
    end
    title(tl,caption,'FontSize',12,'FontWeight','normal');
    xlabel(tl,'Number of function evaluations','FontSize',10);
    ylabel(tl,strrep(plots{1}.metric,'_',' '),'FontSize',10);

    stamp = datestr(now,'yyyymmdd_HHMMSS'); %#ok<TNOW1,DATST>
    for f = 1 : numel(o.formats)
        gridFile = fullfile(o.outputDir,sprintf('%s_grid_%s.%s', ...
            o.fileTag,stamp,o.formats{f}));
        exportgraphics(fig,gridFile,'Resolution',200);
        fprintf('saved grid  : %s\n',gridFile);
    end

    if o.perProblemFiles
        for i = 1 : nP
            if isempty(plots{i}), continue; end
            f1 = figure('Visible',o.visible,'Color','w','Position',[100 80 660 460], ...
                'NumberTitle','off','Name',problems{i});
            ax = axes(f1); %#ok<LAXES>
            PlotConvergenceCurves(problems{i},'verbose',false,'axes',ax, ...
                'lineWidth',2.0,'fontSize',11,passthrough{:});
            drawnow;
            for f = 1 : numel(o.formats)
                one = fullfile(o.outputDir,sprintf('%s_%s.%s', ...
                    o.fileTag,problems{i},o.formats{f}));
                exportgraphics(f1,one,'Resolution',200);
                fprintf('saved curve : %s\n',one);
            end
            if strcmpi(o.visible,'off'), close(f1); end
        end
    end
    if strcmpi(o.visible,'off'), close(fig); end

    out = struct('results',{plots},'gridShape',[nRow nCol],'tag',o.fileTag, ...
        'caption',caption);
    fprintf('\nAll figures exported to %s\n',o.outputDir);
end

% ------------------------------------------------------------------------
function args = replaceOption(args,name,value)
%replaceOption Overwrite one name-value pair inside a flat cell array.

    args = args(:)';
    idx = find(strcmp(args,name),1);
    if isempty(idx)
        args(end+1:end+2) = {name,value};
    else
        args{idx+1} = value;
    end
end
