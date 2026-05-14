function PopNew = KrigingSelect(PopDec,PopObj,MSE,V,V0,NumV1,delta,mu,theta)
% Kriging selection in K-RVEA

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He and Qiqi Liu
% 中文注释作者：李盛薪 (2026-05-14)

% =========================================================================
% 【⭐ 这是 K-RVEA 论文的核心创新所在 ⭐】
% 【作用】从内部 RVEA 跑完后剩下的种群里，挑 mu 个解送真实评价。
%
% 【K-RVEA 的"自适应模型管理"思想】
%   定义 NumV2 = 当前内部种群下"不活跃参考向量"的数量
%        NumV1 = 上一轮档案下的不活跃数 (传进来的 NumVf)
%        Flag  = NumV2 - NumV1 (不活跃数的变化)
%
%   - Flag <= delta (不活跃数变化不大 → 多样性已稳)：
%     ⇒ 走【收敛策略】：按 APD 选每簇最优 (利用 Kriging 均值)
%
%   - Flag >  delta (不活跃数显著增加 → 多样性变差，参考向量被浪费)：
%     ⇒ 走【多样性策略】：选 MSE 最大者 (利用 Kriging 方差，去探索陌生区域)
%
%   ⇒ 这就是 K-RVEA "explore vs exploit" 的自动开关！
%      也是论文 Section IV-B 的核心贡献，必须写进汇报。
%
% 【输入】
%   PopDec  —— 候选解决策变量 (N×D)
%   PopObj  —— 候选解 Kriging 预测均值 (N×M)
%   MSE     —— 候选解 Kriging 预测方差 (N×M)，越大表示模型越没把握
%   V       —— 当前自适应参考向量
%   V0      —— 原始参考向量 (用来算 NumV2)
%   NumV1   —— 上一轮的"不活跃参考向量数" (来自主程序的 NoActive(A1Obj,V0))
%   delta   —— 切换阈值 (主程序传 0.05*Problem.N)
%   mu      —— 要挑的解的个数 (默认 5)
%   theta   —— APD 时变惩罚因子
% 【输出】
%   PopNew  —— mu 个待真实评价的解 (mu×D)
% =========================================================================

    % NumV2：当前候选解关联到 V0 后，有多少个 V0 里的参考向量"没有解关联" (越多越说明多样性不足)
    [NumV2,~] = NoActive(PopObj,V0);
    % NVa, va：在自适应后的 V 上的不活跃数 / 活跃下标
    [NVa,va]  = NoActive(PopObj,V);
    % 以"活跃参考向量"做 K-means 聚类，分成 NCluster 簇 (簇数 = mu 与剩余活跃向量数取小)
    NCluster  = min(mu,size(V,1)-NVa);
    Va        = V(va,:);
    [IDX,~]   = kmeans(Va,NCluster);   % IDX: 每个活跃参考向量属于哪一簇

    % --- 后面这一段 (平移 + 算 gamma + 关联) 和 KEnvironmentalSelection 思路一致 ---
    PopObj = PopObj - repmat(min(PopObj,[],1),size(PopObj,1),1);
    cosine = 1 - pdist2(Va,Va,'cosine');
    cosine(logical(eye(length(cosine)))) = 0;
    gamma  = min(acos(cosine),[],2);
    Angle  = acos(1-pdist2(PopObj,Va,'cosine'));
    [~,associate] = min(Angle,[],2);   % 每个解关联到哪个活跃参考向量

    % 先把每个解的 APD 值算出来缓存到 APD_S 里
    APD_S  = ones(size(PopObj,1),1);
    for i = unique(associate)'
        current1 = find(associate==i);
        if ~isempty(current1)
            APD = (1+size(PopObj,2)*theta*Angle(current1,i)/gamma(i)).*sqrt(sum(PopObj(current1,:).^2,2));
            APD_S(current1,:) = APD;
        end
    end

    Cindex = IDX(associate);   % 把"解 → 参考向量 → 簇"两层映射合成"解 → 簇"

    % ========== ⭐ 关键开关 ⭐ ==========
    Flag = NumV2-NumV1;        % 不活跃参考向量数量的"变化量"
    Next = zeros(NCluster,1);

    for i = unique(Cindex)'
        solution_Best = [];
        current = find(Cindex==i);          % 该簇下的所有解
        t       = unique(associate(current));% 该簇覆盖的活跃参考向量编号

        if Flag<=delta
            % -------- 策略 A：收敛模式 (APD 最小) --------
            % 多样性变化不大 → 信任代理预测均值，每个参考向量先选 APD 最小的，再在簇里选总冠军
            for j = 1:size(t,1)
                currentS = find(associate==t(j));
                [~,id]   = min(APD_S(currentS,:),[],1);
                solution_Best = [solution_Best;currentS(id)];
            end
            [~,best] = min(APD_S(solution_Best,:),[],1);
            Next(i)  = solution_Best(best);
        else
            % -------- 策略 B：多样性 / 探索模式 (MSE 最大) --------
            % 不活跃参考向量增多 → 代理可能误导 → 选模型最不确定 (MSE 最大) 的解去探索陌生区域
            % 用各目标 MSE 的均值作为综合不确定度
            Uncertainty = mean(MSE(current,:),2);
            [~,best]    = max(Uncertainty);
            Next(i)     = current(best);
        end
    end
    index  = Next(Next~=0);
    PopNew = PopDec(index,:);
end
