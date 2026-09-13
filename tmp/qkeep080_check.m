function qkeep080_check()
%QKEEP080_CHECK Equivalence + divergence check for the new qKeep=0.80 variant.
%   A: upstream Pruned class, qKeep=0.70
%   B: upstream Pruned class, qKeep=0.80
%   C: new qKeep080 class,  qKeep=0.80
%   Expected: B == C (faithful clone) and A ~= B (qKeep actually matters).
    root = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO';
    addpath(genpath(root));
    rehash;

    oldCls = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned';
    newCls = 'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned_qKeep080';

    out = fullfile('D:\PlatEMO-master\tmp','qkeep080_check_out.txt');
    fid = fopen(out,'w');
    lg = @(varargin)fprintf(fid,varargin{:});

    cases = { 'A', oldCls, {3000,0.50,0.25,0.70,6};
              'B', oldCls, {3000,0.50,0.25,0.80,6};
              'C', newCls, {3000,0.50,0.25,0.80,6} };

    res = zeros(3,1);
    for i = 1:size(cases,1)
        tag = cases{i,1}; cls = cases{i,2}; prm = cases{i,3};
        PRO = DTLZ2('N',100,'M',10,'D',30,'maxFE',106);
        rng(1,'twister');
        ALG = feval(cls,'parameter',prm,'save',3,'run',1,'outputFcn',@(varargin)[]);
        ALG.Solve(PRO);
        ALG.CalMetric('IGD');
        res(i) = ALG.metric.IGD(end);
        lg('%s: %s | params %s | FE %d | final IGD %.10f\n', ...
            tag,cls,mat2str(cell2mat(prm)),ALG.pro.FE,res(i));
        clear ALG PRO;
    end
    lg('\nB == C (clone faithful) : %s   |diff| = %.3e\n', ...
        string(res(2)==res(3)),abs(res(2)-res(3)));
    lg('A ~= B (qKeep matters)  : %s   |diff| = %.3e\n', ...
        string(res(1)~=res(2)),abs(res(1)-res(2)));
    fclose(fid);
end
