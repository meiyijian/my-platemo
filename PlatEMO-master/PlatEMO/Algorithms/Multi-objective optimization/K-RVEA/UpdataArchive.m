function  A1 = UpdataArchive(A1,New,V,mu,NI)
% Update archive

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He
% 中文注释作者：李盛薪 (2026-05-14)

% =========================================================================
% 【作用】更新 Kriging 训练档案 A1，使其规模始终保持在 NI 个。
% 【动机】
%   - Kriging 训练复杂度 O(N³)，N 越大越慢；
%   - 必须固定档案规模 (论文里 NI = 11D-1)，挑出"最有训练价值"的 NI 个解。
% 【挑选原则】
%   - 新评价的 mu 个解必保留 (最新信息最值钱)；
%   - 老解里挑剩 NI-mu 个：用 K-means 聚类 → 每簇随机挑 1 个 → 保多样性。
% 【输入】
%   A1  —— 当前训练档案
%   New —— 本轮新真实评价的 mu 个解
%   V   —— 当前自适应参考向量
%   mu  —— 新评价数 (默认 5)
%   NI  —— 档案目标规模 (= 11D-1)
% 【输出】
%   A1  —— 更新后的档案，长度恒为 NI (除非历史总解数 < NI)
% =========================================================================

    %% Delete duplicated solutions
    % 把"档案 + 新解"合并去重 (基于决策变量行去重)
    All       = [A1.decs;New.decs];
    [~,index] = unique(All,'rows');     % 第一次出现的行下标
    ALL       = [A1,New];
    Total     = ALL(index);             % 去重后的全部解 (SOLUTION 对象数组)

    %% Select NI solutions for updating the models
    if length(Total)>NI                 % 解多了 → 需要裁剪
        % 找出 New 解关联到的参考向量 active；剩下没关联的方向 Vi 才需要"补样本"
        [~,active] = NoActive(New.objs,V);
        Vi         = V(setdiff(1:size(V,1),active),:);
        % 把"已经在 New 里"的解从老档案里去掉，避免重复
        index = ismember(Total.decs,New.decs,'rows');
        Total = Total(~index);

        % Since the number of inactive reference vectors is smaller than
        % NI-mu, we cluster the solutions instead of reference vectors
        PopObj = Total.objs;
        PopObj = PopObj - repmat(min(PopObj,[],1),length(Total),1);
        Angle  = acos(1-pdist2(PopObj,Vi,'cosine'));
        [~,associate] = min(Angle,[],2);
        Via    = Vi(unique(associate)',:);   % 实际有老解可填的"待补"方向
        Next   = zeros(1,NI-mu);
        if size(Via,1) > NI-mu
            % 路径 1：可填的方向 > 名额 → 对方向聚成 NI-mu 簇，每簇随机挑 1 个老解
            [IDX,~] = kmeans(Via,NI-mu);
            for i = unique(IDX)'
                current = find(IDX==i);
                if length(current)>1
                    best = randi(length(current),1);
                else
                    best = 1;
                end
                Next(i)  = current(best);
            end
        else
            % Cluster solutions based on objective vectors when the number
            % of active reference vectors is smaller than NI-mu
            % 路径 2：可填方向不够 → 直接对老解的目标值聚成 NI-mu 簇，每簇随机挑 1 个
            [IDX,~] = kmeans(Total.objs,NI-mu);
            for i   = unique(IDX)'
                current = find(IDX==i);
                if length(current)>1
                    best = randi(length(current),1);
                else
                    best = 1;
                end
                Next(i)  = current(best);
            end
        end
        % 最终档案 = (NI-mu 个老解) + (mu 个新解)
        A1 = [Total(Next),New];
    else
        % 还没攒够 NI 个，全留下就行
        A1 = Total;
    end
end
