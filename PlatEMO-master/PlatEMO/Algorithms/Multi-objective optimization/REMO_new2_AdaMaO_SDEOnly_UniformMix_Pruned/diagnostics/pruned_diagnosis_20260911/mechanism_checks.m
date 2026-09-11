% Read-only diagnostic: constructed examples, not optimization runs.
platform = 'D:/PlatEMO-master/PlatEMO-master/PlatEMO';
addpath(genpath(platform));
variant = fullfile(platform,'Algorithms','Multi-objective optimization', ...
    'REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned');
addpath(variant);
out = 'D:/PlatEMO-master/PlatEMO-master/PlatEMO/Algorithms/Multi-objective optimization/REMO_new2_AdaMaO_SDEOnly_UniformMix_Pruned/diagnostics/pruned_diagnosis_20260911';
diary(fullfile(out,'mechanism_checks.log'));
% DTLZ5: neutral decision-variable spread on the Pareto set.
p5 = DTLZ5('M',10,'D',30);
a = [0.4,zeros(1,8),0.5*ones(1,21)];
b = [0.4,ones(1,8),0.5*ones(1,21)];
c = [0.7,zeros(1,8),0.5*ones(1,21)];
f = p5.CalObj([a;b;c]);
fprintf('DTLZ5 neutral decision distance %.12g, objective distance %.12g\n', ...
    norm(a-b),norm(f(1,:)-f(2,:)));
fprintf('DTLZ5 useful angle decision distance %.12g, objective distance %.12g\n', ...
    norm(a-c),norm(f(1,:)-f(3,:)));
% Quantile gate includes all three tied good candidates.
[~,chosen] = QualityBatchDistanceSelection([a;b;c],ones(3,1),0.8,2);
fprintf('DTLZ5 chosen indices for tied scores: %s\n',mat2str(chosen'));
% DTLZ2: decision-space novelty can increase radial convergence error.
p2 = DTLZ2('M',10,'D',30);
d = [a(1:9),0.9*ones(1,21)];
f2 = p2.CalObj([a;d]);
fprintf('DTLZ2 tail excursion: decision distance %.12g, objective norms %s, g %.12g\n', ...
    norm(a-d),mat2str(vecnorm(f2,2,2)'),sum((d(10:end)-0.5).^2));
% Same candidate pool, weights removed, ambiguity reward set to zero.
x = [0;0.02;0.04;0.06;0.08;1;linspace(2,3,24)'];
r = [1;0.99;0.98;0.97;0.96;0.8;linspace(0,0.7,24)'];
[~,new] = QualityBatchDistanceSelection(x,r,0.8,2);
keep = find(r>=quantile(r,0.8));
[~,first] = max(r(keep));
oldFirst = keep(first);
remain = keep; remain(first)=[];
quality = (r(remain)-min(r(remain)))/(max(r(remain))-min(r(remain)));
distance = abs(x(remain)-x(oldFirst));
diversity = (distance-min(distance))/(max(distance)-min(distance));
[~,second] = max(0.75*quality+0.25*diversity);
old = [oldFirst;remain(second)];
fprintf('Constructed identical-pool selection, old no-ambiguity %s; pruned %s\n', ...
    mat2str(old'),mat2str(new'));
% Indicator invariance condition: >=64 candidates => >=20 coarse rows.
rng(918,'twister');
counts = [64,65,100,3000];
checks = 0;
for n = counts
    for rep = 1:20
        scores = rand(n,1);
        [~,rel] = sort(scores,'descend');
        shortlist = rel(1:max(20,ceil(0.3*n)));
        indScores = scores(shortlist);
        candidates = find(indScores >= quantile(indScores,0.7));
        [~,order] = sort(indScores(candidates),'descend');
        oldIdx = shortlist(candidates(order(1:6)));
        [~,newIdx] = PrunedIndicatorSelection((1:n)',scores,[],6);
        assert(isequal(oldIdx,newIdx));
        checks = checks+1;
    end
end
fprintf('Indicator finite-score fallback invariance checks passed: %d\n',checks);
diary off;
