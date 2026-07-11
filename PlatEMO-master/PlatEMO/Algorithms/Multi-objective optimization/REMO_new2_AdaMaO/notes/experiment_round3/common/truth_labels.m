function [truth_conv, truth_hyb] = truth_labels(PopObj, good_num, theta)
% truth_labels - 用真实目标值构造"真值好类"（E1 用，两种口径做稳健性检验）
%
% HybridPBI_Classification 的目标概念是"前 N/4 好解"。本函数用充分信息
% （真实目标值 + 非支配排序）构造两种口径的真值好类，各取前 good_num 个：
%
%   口径 A truth_conv（纯收敛）:
%     先按非支配层级，同层按归一化目标向量的范数（越小越收敛）
%   口径 B truth_hyb（收敛+分布，更贴近 HPC 的混合概念）:
%     先按非支配层级，同层按归一化空间中到最近均匀参考向量的 PBI（theta 同 HPC）
%
% 若结论在两种口径下一致，则不依赖真值定义的细节。
%
% 输入:
%   PopObj   - N x M 真实目标值
%   good_num - 真值好类的数量（与 HPC 一致取 ceil(N/4)）
%   theta    - PBI 惩罚系数（与 HPC 一致取 5）
% 输出:
%   truth_conv, truth_hyb - N x 1 logical，好=true

    [N, M] = size(PopObj);
    FrontNo = NDSort(PopObj, inf);
    FrontNo = FrontNo(:);

    % 目标值归一化到 [0,1]（消除量纲，使真值本身尺度无关）
    Zmin  = min(PopObj,[],1);
    Zmax  = max(PopObj,[],1);
    range = max(Zmax - Zmin, 1e-12);
    ObjN  = (PopObj - Zmin) ./ range;

    %% 口径 A：层级 -> 收敛范数
    conv_score = vecnorm(ObjN, 2, 2);
    [~, ord] = sortrows([FrontNo, conv_score]);
    truth_conv = false(N,1);
    truth_conv(ord(1:good_num)) = true;

    %% 口径 B：层级 -> 归一化空间 PBI（均匀参考向量）
    V = UniformPoint(N, M, 'ILD');
    V = V ./ vecnorm(V, 2, 2);
    cosine = 1 - pdist2(ObjN + 1e-12, V, 'cosine');  % 加小量防零向量 NaN
    [~, vidx] = max(cosine, [], 2);
    d1   = sum(ObjN .* V(vidx,:), 2);        % 投影长度（V 已单位化）
    proj = d1 .* V(vidx,:);
    d2   = vecnorm(ObjN - proj, 2, 2);       % 垂直距离
    pbi  = d1 + theta * d2;
    [~, ord] = sortrows([FrontNo, pbi]);
    truth_hyb = false(N,1);
    truth_hyb(ord(1:good_num)) = true;
end
