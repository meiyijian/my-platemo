function [good_idx,bad_idx,Catalog,agreement,Ref,Diag] = ...
        ComplementaryPBI_Classification(Population,ratio,varargin)
% ComplementaryPBI_Classification - RSEA 锚点 PBI + 盲子空间互补 niching
%
% 本模块替换 HybridPBI_Classification 的"连续方向场分支"，针对三个已定位痛点：
%
% 痛点 P1（连续分支退化）：原实现以 'Nref' = N 调用，而 |Population| = N，故
%   nPareto <= Nref 恒成立，K-means 的 nClusters = min(Nref,nPareto) 恒等于
%   nPareto。簇数等于样本数时全局最优为 SSE=0，即簇心就是样本自身，再经
%   V = C.*range + Zmin 精确还原。于是每个非支配解的关联方向是它自己，PBI 闭式为
%       PBI_i = ||f_i|| - u_i'z + theta*|| z - (u_i'z)u_i ||,  u_i = f_i/||f_i||
%   第一项是以坐标原点（而非理想点）为基准的范数，第二项只依赖方向、与解的优劣
%   无关，且奖励靠近理想点的对角方向、惩罚近轴边界解，即一个反多样性偏置。
%   本模块不再使用该分支。
%
% 痛点 P2（二值标签压制连续分支）：GetOutput_PBI 自适应 delt 把 true 比例锁在
%   [0.3,0.7]，即 label=1 的解数（30~70）恒多于正组所需（N*rGood=25）。只要
%   (1-ratio)*spread(score_v) < ratio，label=1 即成为硬过滤，连续分支仅在其内部
%   起排序作用。本模块改用锚点连续 PBI 值作为排序键，取消二值化平台。
%
% 痛点 P3（全局 top-r 使参考向量只有二阶影响）：Catalog 原为标量分数的全局前 r
%   比例，没有 per-direction niching，故参考向量集合的更换只能通过间接改变分数
%   来影响选择。本模块改为在 niche 内取优的 round-robin，使向量集合成为一阶变量。
%
% 选择规则：
%   1. Ref = RefSelect(Population,k)                 （锚点分支完全保留）
%   2. g_i = 锚点相对连续 PBI = (d1 + theta*d2)/||Ref_j - Z||，越小越好
%      —— 与 GetOutput_PBI 的 split_data 同一几何，但不二值化
%   3. beta_i = lambda_i * B'，lambda_i = 归一化目标的权重剖面，B = RSEA 盲谐波基
%      将每个解关联到 beta 空间中最近的 HCV
%   4. 时间日程重定位：原 alpha = 1-ratio 用于混合两个不可比标量（连续 PBI 与
%      二值标签），此处改为控制正组的"名额构成"：
%          nDiv_t = round(nGood * (1-ratio))  个名额由跨 niche round-robin 填充
%          其余名额由全局最优 g 填充
%      早期 (ratio 小) 偏互补覆盖，后期 (ratio 大) 偏纯收敛，语义与原日程一致，
%      但互补分支不再可能被二值平台压制，因为它拥有保底名额。
%
% 嵌套族：nHarm = 0 时 HCV 为空、nDiv 强制为 0，退化为"纯锚点连续 PBI 全局排序"。
%   注意这不等于原始 Original（后者混合 score_v 与二值标签），要对照原始基线请直接
%   运行 REMO_new2_AdaMaO_SDEOnly_UniformMix_Original。
%
% 输入:
%   Population - 种群对象
%   ratio      - 进化比例（已评估次数/总预算，0~1）
%   可选参数:
%     'k'      - 锚点数量（默认 6）
%     'theta'  - PBI 惩罚系数（默认 5）
%     'rGood'  - 正组比例（默认 0.25）
%     'nHarm'  - 使用的盲谐波阶数个数（默认 2；0 = 关闭互补分支）
%
% 输出:
%   good_idx  - 正组索引
%   bad_idx   - 末端排名索引（仅作输出，主程序不单独使用）
%   Catalog   - N x 1 logical，正组 = true
%   agreement - N x 1 双视图一致性（不是校准置信概率；为接口兼容保留）
%   Ref       - RSEA 锚点（k 个）
%   Diag      - 诊断结构体，不参与搜索决策

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ============ 参数解析 ============
    N      = length(Population);
    PopObj = [Population.objs];
    M      = size(PopObj,2);

    k     = get_option(varargin,'k',6);
    theta = get_option(varargin,'theta',5);
    rGood = get_option(varargin,'rGood',0.25);
    nHarm = get_option(varargin,'nHarm',2);

    if ~isscalar(rGood) || ~isnumeric(rGood) || ~isfinite(rGood) || ...
            rGood <= 0 || rGood > 0.5
        error('AdaMaO:InvalidPositiveGroupRatio', ...
            'rGood must be a finite scalar in (0,0.5].');
    end
    if ~isscalar(theta) || ~isnumeric(theta) || ~isfinite(theta) || theta < 0
        error('AdaMaO:InvalidPenaltyParameter', ...
            'theta must be a nonnegative finite scalar.');
    end
    if ~isscalar(ratio) || ~isnumeric(ratio) || ~isfinite(ratio)
        ratio = 0;
    end
    ratio = min(1,max(0,ratio));

    %% ============ 步骤一：RSEA 锚点（完全保留） ============
    Ref    = RefSelect(Population,k);
    RefObj = [Ref.objs];

    %% ============ 步骤二：锚点相对连续 PBI（排序键） ============
    [g,anchorIdx] = AnchorPBI(PopObj,RefObj,theta);

    %% ============ 步骤三：盲子空间互补 niching ============
    [Lambda,B,HInfo] = HarmonicComplementaryVectors(M,nHarm);
    useHCV = HInfo.enabled && N > 1;

    niche = ones(N,1);
    nNicheUsed = 1;
    if useHCV
        beta     = BlindCoords(PopObj,B);
        betaRef  = Lambda*B';
        Dbeta    = pdist2(beta,betaRef);
        [~,niche] = min(Dbeta,[],2);
        nNicheUsed = numel(unique(niche));
    end

    %% ============ 步骤四：名额构成（时间日程重定位） ============
    nGood = max(1,min(N,ceil(N*rGood)));
    if useHCV
        nDiv = round(nGood*(1-ratio));
        nDiv = max(0,min(nGood,nDiv));
    else
        nDiv = 0;
    end

    selected = false(N,1);
    % 4a. round-robin：每个非空 niche 轮流贡献其 g 最小的未选解
    if nDiv > 0
        selected = RoundRobinFill(niche,g,nDiv,selected);
    end
    % 4b. 剩余名额：全局最优 g 补齐
    nFill = nGood - sum(selected);
    if nFill > 0
        rest = find(~selected);
        [~,ord] = sort(g(rest),'ascend');
        selected(rest(ord(1:min(nFill,numel(rest))))) = true;
    end

    good_idx = find(selected);
    % 末端排名：在未入正组的解中取 g 最大的 nGood 个
    rest    = find(~selected);
    [~,ord] = sort(g(rest),'descend');
    bad_idx = rest(ord(1:min(nGood,numel(rest))));

    Catalog = false(N,1);
    Catalog(good_idx) = true;

    %% ============ 步骤五：双视图一致性（接口兼容） ============
    % 连续视图 = 1/(1+g) 的组内归一；离散视图 = 是否入正组
    sc = 1./(1+max(g,0));
    sc = norm01_local(sc);
    agreement = 1 - abs(sc - double(Catalog));

    %% ============ 诊断 ============
    % 主循环只取前 5 个输出，不需要 Diag。诊断量包含额外的 pdist2 与一次
    % 完整核空间构造，每代都算属于浪费（约 90 代/次运行），故按 nargout 跳过。
    if nargout < 6
        Diag = struct();
        return;
    end
    Diag = struct();
    Diag.M                 = M;
    Diag.N                 = N;
    Diag.k                 = numel(Ref);
    Diag.ratio             = ratio;
    Diag.nGood             = nGood;
    Diag.nDivSlots         = nDiv;
    Diag.hcv               = HInfo;
    Diag.hcvActive         = useHCV;
    Diag.nicheOccupied     = nNicheUsed;
    Diag.nicheTotal        = max(1,size(Lambda,1));
    % 注意：nicheOfPositive 基于当前 nHarm 激活的划分，nHarm=0 时 niche 恒为 1，
    % 因此该量不可用于跨 nHarm 比较（会得到平凡结论）。跨配置比较请用下方
    % nicheCoverageFull —— 它始终基于完整核空间的固定划分。
    Diag.nicheOfPositive   = numel(unique(niche(good_idx)));
    Diag.meanGPositive     = mean(g(good_idx));
    Diag.meanGAll          = mean(g);
    Diag.anchorUsedFrac    = numel(unique(anchorIdx))/max(1,numel(Ref));
    % 诊断量始终基于完整核空间 B_full（而非当前 nHarm 激活的子集），
    % 否则 blindVarShare/blindSpread 会随 nHarm 变化而失去跨配置可比性。
    [LamFull,Bfull,FullInfo] = HarmonicComplementaryVectors(M,inf);
    Diag.blindDimFullUsed    = FullInfo.blindDim;
    Diag.blindVarShare       = NaN;
    Diag.nicheCoverageFull   = NaN;
    Diag.nicheTotalFull      = size(LamFull,1);
    if FullInfo.blindDim > 0
        vis = BlindVisibleCoords(PopObj);
        bl  = BlindCoords(PopObj,Bfull);
        tb  = sum(var(bl,0,1));
        tv  = sum(var(vis,0,1));
        if tb + tv > 0
            Diag.blindVarShare = tb/(tb+tv);
        end
        Diag.blindSpreadPositive = mean_pdist(bl(good_idx,:));
        Diag.blindSpreadAll      = mean_pdist(bl);
        % 跨配置可比的覆盖度量：在完整核空间的固定划分下，正组覆盖的 niche 数。
        % 与 nHarm 无关，因此 nHarm=0 与 nHarm>0 可直接比较。
        [~,partFull] = min(pdist2(bl,LamFull*Bfull'),[],2);
        Diag.nicheCoverageFull = numel(unique(partFull(good_idx)));
        % 覆盖半径：正组代表整个盲空间点云的最坏距离（越小越好）
        Diag.blindCoverRadius = max(min(pdist2(bl,bl(good_idx,:)),[],2));
    else
        Diag.blindSpreadPositive = NaN;
        Diag.blindSpreadAll      = NaN;
        Diag.blindCoverRadius    = NaN;
    end
end

%% ============ 锚点相对连续 PBI ============
function [g,anchorIdx] = AnchorPBI(PopObj,RefObj,theta)
% 与 GetOutput_PBI/split_data 同一几何：按原始目标余弦分配锚点区域，
% 在 (P - Z) 坐标中计算 d1 + theta*d2，再除以 ||Ref - Z|| 归一。
% 区别仅在于不做二值化，直接返回连续值（越小越好）。

    N = size(PopObj,1);
    g = zeros(N,1);
    Z = min(PopObj,[],1);

    [~,anchorIdx] = max(1 - pdist2(PopObj,RefObj,'cosine'),[],2);
    anchorIdx(~isfinite(anchorIdx)) = 1;

    X = PopObj - Z;
    for i = 1 : size(RefObj,1)
        sel = anchorIdx == i;
        if ~any(sel)
            continue;
        end
        w  = RefObj(i,:) - Z;
        nw = norm(w);
        if nw < 1e-12
            % 锚点与理想点重合：该区域退化为纯范数
            g(sel) = vecnorm(X(sel,:),2,2);
            continue;
        end
        W  = w./nw;
        Xs = X(sel,:);
        d1 = Xs*W';
        d2 = vecnorm(Xs - d1*W,2,2);
        g(sel) = (d1 + theta.*d2)./nw;
    end
    g(~isfinite(g)) = max([g(isfinite(g));0]);
end

%% ============ RSEA 盲子空间坐标 ============
function beta = BlindCoords(PopObj,B)
% beta = lambda * B'，lambda = 归一化目标的权重剖面。
% 归一化与 RSEA 一致（Pmin = min+1e-6），但逐目标安全处理，
% 以避免 RefSelect 中 "if Pmax > Pmin" 的整体跳过语义。

    lambda = WeightProfile(PopObj);
    beta   = lambda*B';
end

function vis = BlindVisibleCoords(PopObj)
% RadViz 可见的 2 维坐标（一阶谐波），仅用于诊断中的方差分解
    M      = size(PopObj,2);
    lambda = WeightProfile(PopObj);
    m      = 0 : M-1;
    A      = [cos(2*pi*m/M); sin(2*pi*m/M)];
    vis    = lambda*A';
end

function lambda = WeightProfile(PopObj)
    Pmin  = min(PopObj,[],1) + 1e-6;
    Pmax  = max(PopObj,[],1);
    range = Pmax - Pmin;
    flat  = range <= 0;
    range(flat) = 1;                       % 恒定目标：该维贡献 0，不放大噪声
    P = (PopObj - Pmin)./range;
    P(:,flat) = 0;
    P = max(P,0);
    s = sum(P,2);
    bad = s <= 1e-12;
    if any(bad)
        % 全零剖面（等于理想点）：置为均匀剖面，避免 0/0
        P(bad,:) = 1./size(PopObj,2);
        s(bad)   = 1;
    end
    lambda = P./s;
end

%% ============ 跨 niche round-robin ============
function selected = RoundRobinFill(niche,g,nSlots,selected)
% 每一轮里，每个仍有未选解的 niche 贡献其 g 最小的一个，直到填满 nSlots。
% 空 niche 自动跳过，不复制、不占名额。niche 遍历顺序固定（按编号升序），
% 因此在相同输入下结果确定。

    ids   = unique(niche);
    nPick = 0;
    while nPick < nSlots
        moved = false;
        for t = 1 : numel(ids)
            cand = find(niche == ids(t) & ~selected);
            if isempty(cand)
                continue;
            end
            [~,b] = min(g(cand));
            selected(cand(b)) = true;
            nPick = nPick + 1;
            moved = true;
            if nPick >= nSlots
                break;
            end
        end
        if ~moved
            break;                          % 所有 niche 已耗尽
        end
    end
end

%% ============ 工具 ============
function val = get_option(args,name,default)
    val = default;
    for i = 1 : 2 : numel(args)-1
        if strcmpi(args{i},name)
            val = args{i+1};
            return;
        end
    end
end

function s = norm01_local(x)
    x = x(:);
    if isempty(x)
        s = x;
        return;
    end
    a = min(x);
    b = max(x);
    if b - a < 1e-12
        s = ones(size(x))*0.5;
    else
        s = (x-a)./(b-a);
    end
end

function m = mean_pdist(X)
    if size(X,1) < 2
        m = 0;
    else
        m = mean(pdist(X));
    end
end
