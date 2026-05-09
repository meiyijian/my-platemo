function Population = EnvironmentalSelection3(Population,N,Z,Zmin)
% EnvironmentalSelection3：NSGA-III风格的环境选择算子
% 基于参考点关联机制选择下一代种群，保证解在各参考方向上的均匀分布
%
% 输入参数：
%   Population - 当前种群
%   N          - 需要选择的个体数量
%   Z          - 参考方向矩阵，大小为 NZ x M（NZ个参考方向，M个目标）
%   Zmin       - 理想点（各目标的最小值），用于归一化
%
% 输出参数：
%   Population - 选择后的种群

%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 如果Zmin为空，则初始化为全1向量
    if isempty(Zmin)
        Zmin = ones(1,size(Z,2));
    end

    %% ==================== 步骤1：非支配排序 ====================
    % NDSort：非支配排序
    % Population.objs：目标值矩阵
    % Population.cons：约束值矩阵（如果有约束的话）
    [FrontNo,MaxFNo] = NDSort(Population.objs,Population.cons,N);

    % Next：逻辑数组，标记前沿编号小于MaxFNo的个体
    Next = FrontNo < MaxFNo;

    %% ==================== 步骤2：选择最后一个前沿的解 ====================
    % Last：最后一个前沿的所有个体索引
    Last = find(FrontNo==MaxFNo);

    % LastSelection：使用参考点关联机制选择最后一个前沿的部分解
    % Population(Next).objs：已确定选择的解的目标值
    % Population(Last).objs：最后一个前沿解的目标值
    % N-sum(Next)：还需要选择的个体数量
    Choose = LastSelection(Population(Next).objs,Population(Last).objs,N-sum(Next),Z,Zmin);

    % 将选中的最后一个前沿的个体标记为选中
    Next(Last(Choose)) = true;

    % 返回选择后的种群
    Population = Population(Next);
end

function Choose = LastSelection(PopObj1,PopObj2,K,Z,Zmin)
% LastSelection：使用参考点关联机制选择最后一个前沿的部分解
%
% 输入参数：
%   PopObj1 - 已确定选择的解的目标值
%   PopObj2 - 最后一个前沿解的目标值
%   K       - 还需要选择的个体数量
%   Z       - 参考方向矩阵
%   Zmin    - 理想点
%
% 输出参数：
%   Choose  - 逻辑数组，标记PopObj2中哪些个体被选中

    % 将两个目标值矩阵拼接，并减去理想点进行平移
    PopObj = [PopObj1;PopObj2] - repmat(Zmin,size(PopObj1,1)+size(PopObj2,1),1);

    [N,M] = size(PopObj);  % N：总解数，M：目标数
    N1 = size(PopObj1,1);  % N1：已确定选择的解数
    N2 = size(PopObj2,1);  % N2：最后一个前沿的解数
    NZ = size(Z,1);        % NZ：参考方向数

    %% ==================== 步骤1：目标空间归一化 ====================
    % 检测极值点（Extreme Points）
    % 极值点：在某个目标上表现最好（最小）的解
    Extreme = zeros(1,M);

    % w：权重矩阵，用于检测极值点
    % eye(M)：单位矩阵，zeros(M)+1e-6：避免除零
    w = zeros(M)+1e-6+eye(M);

    for i = 1 : M
        % 找到在第i个权重方向上投影最小的解
        % PopObj./repmat(w(i,:),N,1)：按权重缩放目标值
        % max(...,[],2)：对每行取最大值
        % min(...)：找到最小值对应的索引
        [~,Extreme(i)] = min(max(PopObj./repmat(w(i,:),N,1),[],2));
    end

    % 如果极值点不唯一（有重复），则使用最大值作为截距
    if size(unique(Extreme),1)~=M
        a = max(PopObj,[],1)';
    else
        % 否则，通过极值点构造超平面，计算截距
        % Hyperplane：超平面系数
        % a：截距（各轴的截距）
        Hyperplane = PopObj(Extreme,:)\ones(M,1);
        a = 1./Hyperplane;
    end

    % 归一化目标值
    % PopObj./repmat(a',N,1)：将目标值除以截距
    PopObj = PopObj./repmat(a',N,1);

    %% ==================== 步骤2：将解与参考点关联 ====================
    % 计算每个解到每个参考方向的余弦距离
    % pdist2(PopObj,Z,'cosine')：计算余弦距离矩阵
    % 1-余弦距离 = 余弦相似度
    Cosine = 1 - pdist2(PopObj,Z,'cosine');

    % 计算垂直距离（点到参考向量的距离）
    % sqrt(sum(PopObj.^2,2))：每个解的范数（到原点的距离）
    % sqrt(1-Cosine.^2)：正弦值（垂直分量）
    Distance = repmat(sqrt(sum(PopObj.^2,2)),1,NZ).*sqrt(1-Cosine.^2);

    % 找到每个解最近的参考点
    % min(Distance',[],1)：对转置后的距离矩阵按行取最小值
    % d：最近距离，pi：最近参考点的索引
    [d,pi] = min(Distance',[],1);

    %% ==================== 步骤3：计算每个参考点关联的解数 ====================
    % rho：每个参考点关联的已确定选择的解数
    % hist(pi(1:N1),1:NZ)：统计前N1个解的参考点分布
    rho = hist(pi(1:N1),1:NZ);

    %% ==================== 步骤4：基于参考点选择解 ====================
    Choose = false(1,N2);      % 标记最后一个前沿中哪些解被选中
    Zchoose = true(1,NZ);      % 标记哪些参考点还可以选择解

    % 逐个选择K个解
    while sum(Choose) < K
        % 找到关联解数最少的参考点（最稀疏的区域）
        Temp = find(Zchoose);
        Jmin = find(rho(Temp)==min(rho(Temp)));
        j = Temp(Jmin(randi(length(Jmin))));

        % 找到与该参考点关联且未被选中的解
        I = find(Choose==0 & pi(N1+1:end)==j);

        if ~isempty(I)
            if rho(j) == 0
                % 如果该参考点还没有关联的解，选择距离最近的解
                [~,s] = min(d(N1+I));
            else
                % 否则随机选择一个解
                s = randi(length(I));
            end
            Choose(I(s)) = true;  % 标记为选中
            rho(j) = rho(j) + 1; % 更新关联计数
        else
            % 如果该参考点没有可选的解，标记为不可选
            Zchoose(j) = false;
        end
    end
end