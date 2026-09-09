function score_v = ContinuousPBIQualityAssessment(PopObj,V,Zmin,theta)
%ContinuousPBIQualityAssessment Compute continuous directional PBI scores.
    N = size(PopObj,1);
    % 对每个解，使用原始目标向量与 V 的余弦相似度找到关联方向
    % 关联使用原始目标向量；PBI 投影和垂直距离使用相对理想点的目标向量。
    cosine = 1 - pdist2(PopObj, V, 'cosine');  % 余弦相似度
    [~, ref_idx] = max(cosine, [], 2);         % 最相似的参考方向索引

    d1 = zeros(N,1);  % 投影长度
    d2 = zeros(N,1);  % 垂直距离
    for i = 1:N
        vi = ref_idx(i);
        w = V(vi,:);  % 对应的参考方向

        % d1 = 解到理想点沿 w 方向的投影长度
        d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);
        % 投影点
        proj = Zmin + d1(i) * w;
        % d2 = 解到投影点的垂直距离
        d2(i) = norm(PopObj(i,:) - proj);
    end

    % PBI 距离 = d1 + theta * d2（theta 越大，对偏离方向的惩罚越重）
    PBI_v = d1 + theta * d2;
    % 连续质量得分 S=1/(1+PBI)，值越大表示关联方向上的 PBI 值越小。
    score_v = 1 ./ (1 + PBI_v);
end

