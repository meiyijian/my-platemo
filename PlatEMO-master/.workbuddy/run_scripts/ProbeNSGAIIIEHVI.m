function ProbeNSGAIIIEHVI()
%ProbeNSGAIIIEHVI Report which copy of every shared helper the run would use.
    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    root = fullfile(platform,'Algorithms','Multi-objective optimization','NSGAIII-EHVI');
    addpath(genpath(platform));
    fprintf('--- before Solve (plain genpath order) ---\n');
    showAll(root);
    addpath(root,'-begin');
    fprintf('\n--- after addpath(root,'' -begin'') , which is what ALGORITHM.Solve does ---\n');
    showAll(root);
    fprintf('\n--- class load check ---\n');
    try
        a = NSGAIIIEHVI('save',0,'run',1,'outputFcn',@(~,~)[]); %#ok<NASGU>
        fprintf('NSGAIIIEHVI constructed OK.\n');
    catch err
        fprintf('CONSTRUCTION FAILED: %s\n',err.message);
    end
end

function showAll(root)
    names = {'NSGAIIIEHVI','EnvironmentalSelection','LastSelection','SelectionMSE', ...
        'CalEHVI','predictor','dacefit','regpoly0','corrgauss','correxp'};
    for i = 1:numel(names)
        file = which(names{i});
        if isempty(file)
            fprintf('  %-22s MISSING\n',names{i});
        else
            flag = ' ';
            if strcmpi(fileparts(file),root), flag = '*'; end
            fprintf('  %-22s %s %s\n',names{i},flag,file);
        end
    end
end
