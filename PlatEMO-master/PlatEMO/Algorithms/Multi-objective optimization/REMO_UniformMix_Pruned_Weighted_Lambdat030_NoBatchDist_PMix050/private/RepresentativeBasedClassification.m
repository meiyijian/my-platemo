function [Output,r] = RepresentativeBasedClassification(varargin)
%RepresentativeBasedClassification 基于参考解的二值质量分类。
%   OUTPUT = RepresentativeBasedClassification(Pop,Ref) 将 Pop 的每个目标
%   向量关联到余弦相似度最大的参考解，并计算相对于该参考解的 PBI 值。
%   Pop 为 N×M 已评价目标矩阵，Ref 为参考解目标矩阵。
%
%   对于已关联的参考解，g = d1 + delt*d2；以参考解到理想点的距离归一化。
%   归一化值不大于 1 时 OUTPUT 为 true，否则为 false，对应论文的标签 L。
%   该标签与连续质量得分融合后，由 PAQC 确定最终正组和非正组。
%
%   OUTPUT = RepresentativeBasedClassification(Pop,Ref,DELT) 指定类别平衡参数。
%   未指定时，在 [-20,20] 内有界二分搜索，使 true 标签比例趋于 [0.3,0.7]；
%   比例满足条件或搜索区间宽度小于 0.1 时停止。DELT 为 d2 的有符号系数，
%   分类的归一化阈值始终为 1。
%
%   [OUTPUT,R] = RepresentativeBasedClassification(Pop,Ref) 同时返回搜索
%   过程中记录的 true 标签比例。指定 DELT 的调用只使用第一个输出。

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ============ 参数解析 ============
    selfadapt = true;  % 默认搜索类别平衡参数
    if nargin == 3
        % 使用调用方给定的类别平衡参数 delt。
        selfadapt = false;
        delt      = varargin{3};
    end

    Pop = varargin{1};  % 种群目标值
    Ref = varargin{2};  % 参考解目标值

    %% ============ 有界二分搜索类别平衡参数 delt ============
    if selfadapt
        % 搜索区间 [delt_l, delt_u]
        delt_l = -20;
        delt_u = 20;
        r = 0;

        % 以 true 标签比例位于 [0.3,0.7] 为目标搜索，区间足够小时停止。
        while r>0.7 || r<0.3
            delt_c = (delt_l + delt_u)/2;  % 中点
            if abs(delt_l-delt_u)<1e-1
                break;  % 区间足够小则停止
            end
            [l,r] = split_data(Pop,Ref,delt_c);
            if r > 0.7
               delt_l = delt_c;  % true 标签太多，增大 delt
            elseif r < 0.3
               delt_u = delt_c;  % true 标签太少，减小 delt；delt 可能进入负值
            end
        end
    else
        [l,~] = split_data(Pop,Ref,delt);
    end
    Output = l;
end
%% ============ 内部函数：基于 PBI 的划分 ============
function [Output,rate] = split_data(Pop,Ref,delt)
%split_data 在各参考解关联区域内按归一化 PBI 阈值生成标签。

    N      = size(Pop,1);
    popind = 1 : N;
    Output = true(N,1);  % 默认全部为 true 标签

    % 将每个原始目标向量关联到余弦相似度最大的参考解。
    % 关联使用原始目标向量；分类方向 W 使用参考解相对理想点的单位向量。
    [~,ref_index] = max(1-pdist2(Pop,Ref,'cosine'),[],2);

    % 理想点
    Z = min(Pop,[],1);

    % 对每个参考解分别处理
    for i = 1 : size(Ref,1)
        % 属于该参考解子区域的解
        sub_pop    = Pop(ref_index==i,:);
        sub_popind = popind(ref_index==i);

        % 参考解方向
        BOUND = Ref(i,:);
        w = BOUND-Z;           % 方向向量
        W = w./sqrt(sum((w).^2,2));  % 单位化

        % 计算 PBI 的两个分量
        normW   = sqrt(sum((W).^2,2));
        normP   = sqrt(sum((sub_pop-repmat(Z,size(sub_pop,1),1)).^2,2));  % ||P-Zmin||
        normR   = sqrt(sum((BOUND-Z).^2,2));  % ||Ref-Zmin||

        % cosθ = (P-Zmin)·W / (||P-Zmin|| * ||W||)
        CosineP = (sum((sub_pop-repmat(Z,size(sub_pop,1),1)).* ...
                  repmat(W,size(sub_pop,1),1),2)./normW./normP)-1e-6;

        % PBI 距离: g = ||P-Zmin|| * cosθ + delt * ||P-Zmin|| * sinθ
        %           g = d1 + delt * d2
        g = normP.*CosineP + delt*normP.*sqrt(1-CosineP.^2);

        % 归一化到参考解距离
        k = normR;
        g = g./k;

        % 归一化 PBI 值大于 1 时，参考解分类标签 L 取 0。
        Output(sub_popind(g>1)) = false;
    end

    % true 标签比例
	rate = sum(Output == 1)/length(Output);
end
