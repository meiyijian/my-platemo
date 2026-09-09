function verify_paqc_example()
%VERIFY_PAQC_EXAMPLE Verify an explicitly constructed PAQC classification case.
%   Run build_correction_figure.py --prepare-only first. The prepared source
%   files are byte-preserved copies or an exact local-function extraction;
%   no production algorithm or experimental result is modified.

    outDir = fileparts(mfilename('fullpath'));
    sourceDir = fullfile(outDir,'source_snapshot');
    addpath(sourceDir);
    restorePath = onCleanup(@() rmpath(sourceDir)); %#ok<NASGU>
    Names = {'A';'R';'B';'C';'D';'E';'F';'G'};
    P = [3/sqrt(10),1/sqrt(10);1,0;0,3.5;0,4;0,4.5;0,5;0,6;2,0];
    R = P(2,:);
    Z = min(P,[],1);
    delta = 0.234375;
    theta = 5;
    t = 0.20;
    [V, realizedN] = UniformPoint(size(P,1),2,'ILD');
    V = V./vecnorm(V,2,2);

    % Execute the actual reference classifier and directional-score helper.
    L = RepresentativeBasedClassification(P,R,delta);
    S = ContinuousPBIQualityAssessment(P,V,Z,theta);
    H = (1-t)*S+t*double(L);
    [~,order] = sort(H,'descend');
    selected = false(size(L));
    selected(order(1:2)) = true;
    ranks = zeros(8,1);
    ranks(order) = (1:8)';

    % Independent reconstruction of all intermediate values.
    [~,association] = max(1-pdist2(P,V,'cosine'),[],2);
    W = (R-Z)/norm(R-Z);
    rad = vecnorm(P-Z,2,2);
    cosAdjusted = ((P-Z)*W')./rad - 1e-6;
    normalizedG = rad.*(cosAdjusted+delta*sqrt(1-cosAdjusted.^2))/norm(R-Z);
    directionalD1 = sum((P-Z).*V(association,:),2);
    directionalD2 = vecnorm(P-Z-directionalD1.*V(association,:),2,2);
    independentS = 1./(1+directionalD1+theta*directionalD2);
    frontDistance = rad-1;

    assert(realizedN==9 && isequal(size(V),[9,2]));
    assert(max(abs(independentS-S))<1e-12);
    assert(isequal(L,normalizedG<=1));
    assert(isequal(find(L),[3;4]));
    assert(isequal(find(selected),[1;2]));
    assert(abs(frontDistance(1))<1e-12 && frontDistance(3)>0);
    assert(~L(1) && selected(1) && L(3) && ~selected(3));
    cutoffGap = H(order(2))-H(order(3));
    assert(cutoffGap>0.02);

    % The focal result must not depend on the boundary epsilon at R.
    normalizedGNoEpsilon = (P(:,1)+delta*P(:,2))/norm(R-Z);
    labelNoEpsilon = normalizedGNoEpsilon<=1+1e-14;
    hNoEpsilon = (1-t)*S+t*double(labelNoEpsilon);
    [~,noEpsilonOrder] = sort(hNoEpsilon,'descend');
    assert(isequal(sort(noEpsilonOrder(1:2)),[1;2]));
    assert(~labelNoEpsilon(1) && labelNoEpsilon(3));

    % The intended claim is early-stage, not a universal label reversal.
    laterT = [0.5,0.75,1];
    for j=1:numel(laterT)
        laterH = (1-laterT(j))*S+laterT(j)*double(L);
        [~,laterOrder] = sort(laterH,'descend');
        assert(~ismember(1,laterOrder(1:2)));
    end

    % Verify fixed and automatically obtained labels separately.
    [autoLabels,autoRate] = RepresentativeBasedClassification(P,R);
    autoLabelsMatch = isequal(autoLabels,L);

    records = table(string(Names),P(:,1),P(:,2),association, ...
        directionalD1,directionalD2,normalizedG,double(L),S,H,ranks, ...
        selected,frontDistance,labelNoEpsilon, ...
        'VariableNames',{'Solution','f1','f2','DirectionIndex', ...
        'DirectionalD1','DirectionalD2','ReferenceNormalizedG','ReferenceLabel', ...
        'ContinuousScore','HybridScore','HybridRank','HybridSelected', ...
        'DistanceToKnownPF','ReferenceLabelWithoutEpsilon'});
    writetable(records,fullfile(outDir,'numerical_records.csv'));
    payload = struct('names',{Names},'points',P,'reference',R,'idealPoint',Z, ...
        'delta',delta,'theta',theta,'t',t,'requestedDirections',8, ...
        'realizedDirections',realizedN,'directions',V, ...
        'directionIndex',association,'directionalD1',directionalD1, ...
        'directionalD2',directionalD2,'normalizedG',normalizedG, ...
        'labels',L,'S',S,'H',H,'rank',ranks,'selected',selected, ...
        'frontDistance',frontDistance,'cutoffGap',cutoffGap, ...
        'noEpsilonLabels',labelNoEpsilon,'noEpsilonH',hNoEpsilon, ...
        'autoLabelsMatchFixed',autoLabelsMatch,'autoPositiveRate',autoRate, ...
        'matlabVersion',version,'verification','MATLAB_SOURCE_CHECK_PASS', ...
        'scope','Constructed classification example with a given reference; not RefSelect or an optimization run.');
    fid = fopen(fullfile(outDir,'numerical_records.json'),'w','n','UTF-8');
    closer = onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s\n',jsonencode(payload,PrettyPrint=true));
    disp(records);
    fprintf('MATLAB_SOURCE_CHECK_PASS; cutoff margin = %.12g\n',cutoffGap);
end
