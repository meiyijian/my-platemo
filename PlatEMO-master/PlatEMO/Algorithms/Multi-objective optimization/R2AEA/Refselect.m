function Population = Refselect(Population,N,Z,Zmin)
% Refselect：参考解选择函数
% 从存档中选择N个代表性解作为参考解
% 使用NSGA-III的参考点关联机制，保证解在各参考方向上的均匀分布
%
% 输入参数：
%   Population - 存档（包含所有候选解）
%   N          - 需要选择的参考解数量
%   Z          - 参考方向矩阵，大小为 NZ x M
%   Zmin       - 理想点（各目标的最小值）
%
% 输出参数：
%   Population - 选择的参考解（大小为N）

    % 如果Zmin为空，则初始化为全1向量
    if isempty(Zmin)
        Zmin = ones(1,size(Z,2));
    end

    %% ==================== 步骤1：非支配排序 ====================
    % NDSort：非支配排序
    [FrontNo,MaxFNo] = NDSort(Population.objs,Population.cons,N);
    Next = FrontNo < MaxFNo;

    %% ==================== 步骤2：选择最后一个前沿的解 ====================
    Last = find(FrontNo==MaxFNo);
    Choose = LastSelection(Population(Next).objs,Population(Last).objs,N-sum(Next),Z,Zmin);
    Next(Last(Choose)) = true;

    % 返回选择后的参考解
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
    % 检测极值点
    Extreme = zeros(1,M);
    w = zeros(M)+1e-6+eye(M);

    for i = 1 : M
        [~,Extreme(i)] = min(max(PopObj./repmat(w(i,:),N,1),[],2));
    end

    % 计算截距
    if size(unique(Extreme),1)~=M
        a = max(PopObj,[],1)';
    else
        Hyperplane = PopObj(Extreme,:)\ones(M,1);
        a = 1./Hyperplane;
    end

    % 归一化目标值
    PopObj = PopObj./repmat(a',N,1);

    %% ==================== 步骤2：将解与参考点关联 ====================
    % 计算余弦距离
    Cosine = 1 - pdist2(PopObj,Z,'cosine');

    % 计算垂直距离
    Distance = repmat(sqrt(sum(PopObj.^2,2)),1,NZ).*sqrt(1-Cosine.^2);

    % 找到每个解最近的参考点
    [d,pi] = min(Distance',[],1);

    %% ==================== 步骤3：计算关联解数 ====================
    rho = hist(pi(1:N1),1:NZ);

    %% ==================== 步骤4：基于参考点选择解 ====================
    Choose = false(1,N2);
    Zchoose = true(1,NZ);

    while sum(Choose) < K
        % 找到最稀疏的参考点
        Temp = find(Zchoose);
        Jmin = find(rho(Temp)==min(rho(Temp)));
        j = Temp(Jmin(randi(length(Jmin))));

        % 找到与该参考点关联的未选中解
        I = find(Choose==0 & pi(N1+1:end)==j);

        if ~isempty(I)
            if rho(j) == 0
                % 选择距离最近的解
                [~,s] = min(d(N1+I));
            else
                % 随机选择一个解
                s = randi(length(I));
            end
            Choose(I(s)) = true;
            rho(j) = rho(j) + 1;
        else
            Zchoose(j) = false;
        end
    end
end