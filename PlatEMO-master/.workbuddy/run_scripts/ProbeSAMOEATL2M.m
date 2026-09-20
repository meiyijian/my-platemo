function ProbeSAMOEATL2M()
%ProbeSAMOEATL2M Check path resolution and the FE budget of one short run.
    platform = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    root = fullfile(platform,'Algorithms','Multi-objective optimization','SAMOEA-TL2M');
    addpath(genpath(platform));
    fprintf('--- resolution before Solve (plain genpath order) ---\n');
    showAll(root);
    addpath(root,'-begin');
    fprintf('\n--- resolution after raise-to-top (what ALGORITHM.Solve does) ---\n');
    showAll(root);

    fprintf('\n--- what the algorithm asks the problem for ---\n');
    pro = DTLZ2('N',100,'M',10,'D',30,'maxFE',300);
    fprintf('  problem reports N=%d M=%d D=%d maxFE=%d\n',pro.N,pro.M,pro.D,pro.maxFE);
    fprintf('  initial design size NI = 11*D-1 = %d\n',11*30-1);
    fprintf('  problem.N after UniformPoint(N,M) is computed inside the algorithm\n');

    fprintf('\n--- one run, DTLZ2 M=10 D=30 maxFE=300 ---\n');
    alg = SAMOEATL2M('save',30,'run',1,'outputFcn',@(~,~)[]);
    rng(21260912,'twister');
    t0 = tic;
    try
        alg.Solve(pro);
        fprintf('  Solve returned normally.\n');
    catch err
        fprintf('  Solve threw: %s\n',err.message);
    end
    fprintf('  wall time      = %.1f s\n',toc(t0));
    fprintf('  final FE       = %d   (budget was %d)\n',pro.FE,pro.maxFE);
    fprintf('  result rows    = %d\n',size(alg.result,1));
    if ~isempty(alg.result)
        fprintf('  result FE col  = %s\n',mat2str(cell2mat(alg.result(:,1))'));
        fprintf('  last pop size  = %d\n',length(alg.result{end,2}));
    end
end

function showAll(root)
    names = {'SAMOEATL2M','TrainModel2','idw_prediction_and_uncertainty', ...
        'UniformPoint','OperatorGA','NDSort','RBF'};
    for i = 1:numel(names)
        file = which(names{i});
        if isempty(file)
            fprintf('  %-32s MISSING (probably a local function)\n',names{i});
        else
            flag = ' ';
            if strncmpi(fileparts(file),root,numel(root)), flag = '*'; end
            fprintf('  %-32s %s %s\n',names{i},flag,file);
        end
    end
end
