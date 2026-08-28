function [Output,r] = GetOutput_PBI(varargin)
% GetOutput_PBI - PBI 阈值划分（动态标签生成）
%
% 基于当前代表解锚点的 PBI 阈值，将种群产生二值区域标签
%
% PBI 公式：
%   g = ||P-Zmin|| * cosθ + δ * ||P-Zmin|| * sinθ
%
% 其中：
%   P: 解的目标值
%   Zmin: 理想点
%   θ: 解与参考方向的夹角
%   δ: 有符号的垂直距离系数；δ>0 时惩罚偏离，δ<0 时会奖励较大的垂直距离
%
% 划分标准：
%   若 g / ||Ref-Zmin|| > 1，则标签为 false
%   否则标签为 true；这是相对锚点阈值标签，不等同于真实 Pareto 好/坏标签
%
% 自适应 δ：
%   当用户未提供 δ 时，二分搜索 δ ∈ [-20, 20]，
%   使得 true 标签比例 r 落入 [0.3, 0.7]，主要用于控制二值标签比例
%
% 输入:
%   Pop - N x M 目标值矩阵
%   Ref - k x M 参考解目标值矩阵
%   可选: delt - PBI 阈值（若不提供则自适应搜索）
%
% 输出:
%   Output - N x 1 logical，true/false 为相对锚点阈值标签
%   r      - true 标签比例（自适应模式下用于调试）

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

        % 二分搜索，使 true 标签比例 r 落入 [0.3, 0.7]
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
% split_data - 对每个代表解锚点，用 PBI 阈值产生二值标签
%
% 输入：
%   Pop  : N x M 种群目标值
%   Ref  : k x M 参考解目标值
%   delt : PBI 阈值
%
% 输出：
%   Output : N x 1 logical，好=true，坏=false
%   rate   : true 标签比例

    N      = size(Pop,1);
    popind = 1 : N;
    Output = true(N,1);  % 默认全部为 true 标签

    % 使用原始 Pop 与 Ref 的余弦相似度分配锚点区域
    % 注意：这里未减理想点 Z，后续区域方向 W 则使用 Ref-Z。
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

        % 若 g > 1，则标签设为 false；当 delt<0 时该条件不能解释为单纯“偏离过大”
        Output(sub_popind(g>1)) = false;
    end

    % true 标签比例
	rate = sum(Output == 1)/length(Output);
end
