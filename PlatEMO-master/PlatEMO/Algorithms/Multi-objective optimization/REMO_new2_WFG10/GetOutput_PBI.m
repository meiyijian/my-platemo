function [Output,r] = GetOutput_PBI(varargin)
% PBI 阈值划分（动态标签生成）
% 基于参考解的 PBI 距离，将种群划分为好/坏两类
%
% 输入:
%   Pop - N x M 目标值矩阵
%   Ref - k x M 参考解目标值矩阵
%   可选: delt - PBI 阈值（若不提供则自适应搜索）
%
% 输出:
%   Output - N x 1 logical，好=true，坏=false
%   r      - 好解比例（自适应模式下用于调试）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ============ 参数解析 ============
    selfadapt = true;  % 默认自适应模式
    if nargin == 3
        % 用户提供了 delt，则不自适应
        selfadapt = false;
        delt      = varargin{3};
    end

    Pop = varargin{1};  % 种群目标值
    Ref = varargin{2};  % 参考解目标值

    %% ============ 自适应搜索阈值 delt ============
    if selfadapt
        % 搜索区间 [delt_l, delt_u]
        delt_l = -20;
        delt_u = 20;
        r = 0;

        % 二分搜索，使好解比例 r 落入 [0.3, 0.7]
        while r>0.7 || r<0.3
            delt_c = (delt_l + delt_u)/2;  % 中点
            if abs(delt_l-delt_u)<1e-1
                break;  % 区间足够小则停止
            end
            [l,r] = split_data(Pop,Ref,delt_c);
            if r > 0.7
               delt_l = delt_c;  % 好解太多，增大 delt（更严格）
            elseif r < 0.3
               delt_u = delt_c;  % 好解太少，减小 delt（更宽松）
            end
        end
    else
        [l,~] = split_data(Pop,Ref,delt);
    end
    Output = l;
end

%% ============ 内部函数：基于 PBI 的划分 ============
function [Output,rate] = split_data(Pop,Ref,delt)
% 对每个参考点，用 PBI 公式判断解是否"好"
%
% PBI 公式: g = ||P-Zmin|| * cosθ + delt * ||P-Zmin|| * sinθ
% 若 g / ||Ref-Zmin|| > 1，则标记为坏（false）

    N      = size(Pop,1);
    popind = 1 : N;
    Output = true(N,1);  % 默认全部为好

    % 找到每个解最近的参考解（余弦相似度最大）
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

        % 若 g > 1，说明解偏离参考方向太远，标记为坏
        Output(sub_popind(g>1)) = false;
    end

    % 好解比例
	rate = sum(Output == 1)/length(Output);
end