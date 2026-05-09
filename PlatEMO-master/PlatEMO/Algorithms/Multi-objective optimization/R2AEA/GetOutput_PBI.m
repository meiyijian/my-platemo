function [Output,r] = GetOutput_PBI(varargin)
% GetOutput_PBI：基于PBI函数的分类标签生成
% 判断种群中的每个个体是否在参考解所界定的前沿区域内
% 使用PBI（Penalty-based Boundary Intersection）函数进行分类
%
% 输入参数（可变参数）：
%   varargin{1} - Pop：种群的目标值矩阵
%   varargin{2} - Ref：参考解的目标值矩阵
%   varargin{3} - delt（可选）：惩罚参数，如果未提供则自适应调整
%
% 输出参数：
%   Output - 分类标签，逻辑数组（true=好解，false=差解）
%   r      - 好解的比例

%------------------------------- Copyright --------------------------------
% Copyright (c) 2024 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ==================== 步骤1：解析输入参数 ====================
    % selfadapt：是否自适应调整惩罚参数
    selfadapt = true;

    % nargin：输入参数个数
    % 如果提供了3个参数，则使用指定的惩罚参数
    if nargin == 3
        selfadapt = false;
        delt = varargin{3};  % 使用指定的惩罚参数
    end

    % 获取种群和参考解的目标值
    Pop = varargin{1};  % 种群目标值
    Ref = varargin{2};  % 参考解目标值

    %% ==================== 步骤2：自适应调整惩罚参数 ====================
    if selfadapt
        % 二分搜索自适应调整惩罚参数delt
        % 目标：使约30%-70%的解被判定为"好解"
        delt_l = -20;  % 惩罚参数下界
        delt_u = 20;   % 惩罚参数上界
        r = 0;         % 好解比例

        % 二分搜索循环
        while r>0.7 || r<0.3
            delt_c = (delt_l + delt_u)/2;  % 当前惩罚参数（中点）

            % 如果上下界足够接近，停止搜索
            if abs(delt_l-delt_u)<1e-1
                break;
            end

            % split_data：使用当前惩罚参数进行分类
            % l：分类标签，r：好解比例
            [l,r] = split_data(Pop,Ref,delt_c);

            % 根据好解比例调整搜索范围
            if r > 0.7
                % 好解太多，增大惩罚参数（使分类更严格）
                delt_l = delt_c;
            elseif r < 0.3
                % 好解太少，减小惩罚参数（使分类更宽松）
                delt_u = delt_c;
            end
        end
    else
        % 使用指定的惩罚参数
        [l,~] = split_data(Pop,Ref,delt);
    end

    % 返回分类标签
    Output = l;
end

function [Output,rate] = split_data(Pop,Ref,delt)
% split_data：使用PBI函数对种群进行分类
%
% 输入参数：
%   Pop  - 种群目标值矩阵
%   Ref  - 参考解目标值矩阵
%   delt - 惩罚参数
%
% 输出参数：
%   Output - 分类标签（true=好解，false=差解）
%   rate   - 好解的比例

    N = size(Pop,1);      % 种群大小
    popind = 1 : N;       % 种群索引
    Output = true(N,1);   % 初始化为全true（好解）

    %% ========== 步骤1：将解与参考解关联 ==========
    % pdist2(Pop,Ref,'cosine')：计算Pop和Ref之间的余弦距离
    % 1-余弦距离 = 余弦相似度
    % max(...,[],2)：对每行取最大值，找到最相似的参考解
    % ref_index：每个解对应的参考解索引
    [~,ref_index] = max(1-pdist2(Pop,Ref,'cosine'),[],2);

    % Z：理想点，种群中各目标的最小值
    Z = min(Pop,[],1);

    %% ========== 步骤2：对每个参考解区域进行分类 ==========
    for i = 1 : size(Ref,1)
        % sub_pop：与第i个参考解关联的解
        sub_pop = Pop(ref_index==i,:);

        % sub_popind：这些解在原种群中的索引
        sub_popind = popind(ref_index==i);

        % BOUND：第i个参考解（边界点）
        BOUND = Ref(i,:);

        %% --- 计算PBI值 ---
        % w：从理想点到参考解的方向向量
        w = BOUND - Z;

        % W：单位方向向量
        W = w./sqrt(sum((w).^2,2));

        % normW：单位向量的范数（应该为1）
        normW = sqrt(sum((W).^2,2));

        % normP：每个解到理想点的欧氏距离
        normP = sqrt(sum((sub_pop-repmat(Z,size(sub_pop,1),1)).^2,2));

        % normR：参考解到理想点的欧氏距离
        normR = sqrt(sum((BOUND-Z).^2,2));

        % CosineP：每个解与方向向量W的余弦值
        % (sub_pop-Z) .* W：点积
        % ./normW./normP：除以范数得到余弦值
        % -1e-6：微小偏移，避免数值问题
        CosineP = (sum((sub_pop-repmat(Z,size(sub_pop,1),1)).*repmat(W,size(sub_pop,1),1),2)./normW./normP)-1e-6;

        %% --- PBI函数计算 ---
        % PBI(x) = d1 + delt * d2
        % d1 = normP * CosineP：投影距离（沿参考方向）
        % d2 = normP * sqrt(1-CosineP^2)：垂直距离（到参考方向）
        g = normP.*CosineP + delt*normP.*sqrt(1-CosineP.^2);

        % k：参考解的PBI值（作为阈值）
        k = normR;

        % 归一化PBI值
        g = g./k;

        % 如果PBI值 > 1，说明解在参考解所界定的区域之外，标记为差解
        Output(sub_popind(g>1)) = false;
    end

    % rate：好解的比例
    rate = sum(Output == 1)/length(Output);
end