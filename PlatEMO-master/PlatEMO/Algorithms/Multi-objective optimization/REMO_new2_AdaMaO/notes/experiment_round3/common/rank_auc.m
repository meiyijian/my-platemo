function auc = rank_auc(score, label)
% rank_auc - Mann-Whitney 秩 AUC：P(正类得分 > 负类得分) + 0.5*P(相等)
%
% 用途（E1）：score = confidence（或关系对权重 Ws），label = 分类是否正确。
%   AUC > 0.5  : 置信度越高越可能分类正确（度量有信息）
%   AUC ≈ 0.5  : 置信度与正确性无关（度量无效）
%   AUC < 0.5  : 反向（置信度高反而更容易错）
%
% 输入:
%   score - N x 1 连续得分
%   label - N x 1 logical/0-1，1=正类
% 输出:
%   auc   - 标量；任一类为空时返回 NaN

    score = score(:);
    label = logical(label(:));
    n1 = sum(label);
    n0 = sum(~label);
    if n1 == 0 || n0 == 0
        auc = NaN;
        return;
    end
    r   = tiedrank(score);   % 并列取平均秩（Statistics Toolbox，与 kmeans 同依赖）
    auc = (sum(r(label)) - n1*(n1+1)/2) / (n1*n0);
end
