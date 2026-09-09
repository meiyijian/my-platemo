function verify_simple_paqc()
% Verify a compact constructed example for a REMO-style method schematic.
    out = fileparts(mfilename('fullpath'));
    src = fullfile(out,'source_snapshot');
    addpath(src);
    cleanup = onCleanup(@() rmpath(src)); %#ok<NASGU>
    P = [1/sqrt(2),1/sqrt(2); 1,0; ...
        1.16*sin(pi/8),1.16*cos(pi/8); ...
        .5,1.25; .1,1.4; 1.35,.2; 0,2.3; ...
        1.9,.5; 1.35,1.3; .9,1.9; .15,2; 1.8,.05] + .2;
    names = {'A';'R';'B';'C';'D';'E';'F';'G';'H';'I';'J';'K'};
    Z = min(P,[],1);
    Ref = P(2,:);
    delta = .5;
    theta = 5;
    t = .2;
    [V,actualN] = UniformPoint(3,2,'ILD');
    V = V./vecnorm(V,2,2);
    L = RepresentativeBasedClassification(P,Ref,delta);
    S = ContinuousPBIQualityAssessment(P,V,Z,theta);
    H = (1-t)*S+t*double(L);
    [~,order] = sort(H,'descend');
    selected = false(12,1);
    selected(order(1:3)) = true;
    radius = vecnorm(P-Z,2,2);
    [~,association] = max(1-pdist2(P,V,'cosine'),[],2);
    c = (P(:,1)-Z(1))./radius - 1e-6;
    g = radius.*(c+delta*sqrt(1-c.^2));
    assert(actualN==3);
    assert(isequal(find(selected),[1;2;5]));
    assert(isequal(find(L),[3;5]));
    assert(abs(radius(1)-1)<1e-12 && abs(radius(3)-1.16)<1e-12);
    assert(~L(1) && selected(1) && L(3) && ~selected(3));
    assert(isequal(g<=1,L));
    cutoff = H(order(3))-H(order(4));
    assert(cutoff>.01);
    L0=(P(:,1)-Z(1)+delta*(P(:,2)-Z(2)))<=1+1e-14;
    [~,order0]=sort((1-t)*S+t*double(L0),'descend');
    assert(isequal(sort(order0(1:3)),[1;2;5]));
    result=struct('status','MATLAB_SIMPLE_SOURCE_CHECK_PASS','names',{names}, ...
        'points',P,'Z',Z,'reference',Ref,'delta',delta,'theta',theta, ...
        't',t,'directions',V,'association',association,'L',L,'S',S, ...
        'H',H,'selected',selected,'g',g,'radius',radius,'cutoffGap',cutoff, ...
        'nativePositiveCount',sum(L),'hybridPositiveCount',sum(selected), ...
        'sourceScope','Given single reference and three uniform directions; no RefSelect or optimization run.', ...
        'matlabVersion',version);
    fid=fopen(fullfile(out,'simple_records.json'),'w','n','UTF-8');
    closer=onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(result,PrettyPrint=true));
    T=table(string(names),P(:,1),P(:,2),double(L),S,H,selected,radius-1, ...
        'VariableNames',{'Name','f1','f2','ReferenceLabel','S','H','HybridSelected','DistanceToKnownPF'});
    writetable(T,fullfile(out,'simple_records.csv'));
    disp(T([1,3],:));
    fprintf('MATLAB_SIMPLE_SOURCE_CHECK_PASS; cutoff gap = %.12g\n',cutoff);
end
