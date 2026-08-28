function [Lambda,B,Info] = HarmonicComplementaryVectors(M,nHarm)
% HarmonicComplementaryVectors - RSEA 盲子空间的解析互补向量（HCV）
%
% 设计依据（可证明，不依赖数据）：
%   RSEA 的 RadarGrid 把 M 维目标映射到 2 维雷达坐标
%       RLoc(:,1) = sum(P.*cos(theta))./sum(P),  RLoc(:,2) = sum(P.*sin(theta))./sum(P)
%   分子分母同次，故该映射只依赖权重剖面 lambda = P/sum(P)，与幅值无关。
%   记 A 为 2 x M 矩阵，第 m 列 = (cos(2*pi*m/M), sin(2*pi*m/M))，即离散 Fourier
%   基的一阶谐波。lambda 在单纯形上有 M-1 个自由度，A 只保留 2 个，因此
%
%       ker(RadViz) = span{ h 阶谐波 : h = 2 .. floor(M/2) },   dim = M-3
%
%   该核空间中的任意方向对 RSEA 完全不可见：存在 lambda1 ~= lambda2 而雷达坐标
%   精确相等（M 偶数时最简反例：lambda1 在 f1,f(1+M/2) 各 0.5；lambda2 在
%   f3,f(3+M/2) 各 0.5，两者雷达坐标同为原点）。
%
% 构造：对每个盲谐波基向量 b（先单位化，再缩放到 max|b|=1），取正负两侧
%
%       lambda^(h,+) = (1+b)/M ,   lambda^(h,-) = (1-b)/M
%
%   由 sum(b)=0 得 sum(lambda)=1；由 max|b|=1 得 lambda>=0。二者之差张开 b 方向，
%   故全部 HCV 的线性包恰为 ker(RadViz)。这是构造性结论，不是待验证假设。
%
% 性质（与数据无关）：
%   1. |Lambda| = 2*nUsed，nUsed <= M-3；取满时 |Lambda| = 2*(M-3)，与 k_eff 同阶
%   2. 最小两两夹角约 48.2 度（谐波正交性所致，与 M 无关），良态
%   3. 完全确定、无随机数、跨代恒定，故方向 churn 恒为 0
%   4. 复杂度 O(M^2)，可一次性预计算
%
% 与"覆盖 M 维球面"的区别：覆盖 S^(M-1) 正卦限到角半径 eps 需要 ~eps^-(M-1) 个
% 方向，k=15 时目标不可达；张满一个 M-3 维线性子空间只需 M-3 个方向，可达。
%
% 输入:
%   M     - 目标维数
%   nHarm - 使用的谐波阶数个数（h = 2 .. 1+nHarm）。嵌套族：
%           nHarm=0 -> 不做互补（退回全局排序）；取满则张满整个核空间。
%           默认 inf（取满可用阶数）
% 输出:
%   Lambda - nV x M 权重向量（每行 sum=1、>=0），互补 niche 的中心
%   B      - nB x M 盲谐波正交基（行正交、与 A 的两行及全一向量正交）
%   Info   - 结构体诊断：可用阶数、实际使用阶数、维数、最小夹角等

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    if nargin < 2 || isempty(nHarm)
        nHarm = inf;
    end
    if ~isscalar(M) || ~isnumeric(M) || ~isfinite(M) || M < 1 || M ~= floor(M)
        error('AdaMaO:InvalidObjectiveNumber', ...
            'M must be a positive integer.');
    end
    if ~isscalar(nHarm) || ~isnumeric(nHarm) || isnan(nHarm) || nHarm < 0
        error('AdaMaO:InvalidHarmonicOrder', ...
            'nHarm must be a nonnegative scalar (inf allowed).');
    end

    % 可用谐波阶：h = 2 .. floor(M/2)
    hAll = 2 : floor(M/2);
    % 按阶数升序取前 nHarm 个（低频优先：低频承载较多 lambda 方差）
    nUse = min(numel(hAll),floor(min(nHarm,numel(hAll))));
    hUse = hAll(1:nUse);

    m = 0 : M-1;
    B      = zeros(0,M);
    Lambda = zeros(0,M);
    for h = hUse
        c = cos(2*pi*h*m/M);
        pair = c;
        s = sin(2*pi*h*m/M);
        if norm(s) > 1e-12
            % h = M/2 时 sin 分量恒为 0，跳过
            pair = [c;s];
        end
        for r = 1 : size(pair,1)
            b = pair(r,:);
            B = [B; b./norm(b)];                        %#ok<AGROW>
            bs = b./max(abs(b));                        % 缩放到 max|b|=1
            Lambda = [Lambda; (1+bs)./M; (1-bs)./M];    %#ok<AGROW>
        end
    end

    % 去除数值退化行（理论上不出现，作为防御）
    if ~isempty(Lambda)
        keep = sum(Lambda,2) > 1e-12 & all(isfinite(Lambda),2);
        Lambda = Lambda(keep,:);
        Lambda = max(Lambda,0);
        rs = sum(Lambda,2);
        Lambda = Lambda./rs;
    end

    Info = struct();
    Info.M              = M;
    Info.nHarmAvailable = numel(hAll);
    Info.nHarmUsed      = nUse;
    Info.harmonics      = hUse;
    Info.blindDim       = size(B,1);
    Info.blindDimFull   = max(0,M-3);
    Info.nVectors       = size(Lambda,1);
    Info.enabled        = size(Lambda,1) >= 2;
    Info.minPairAngle   = NaN;
    if size(Lambda,1) >= 2
        W = Lambda./vecnorm(Lambda,2,2);
        G = W*W';
        G(logical(eye(size(G)))) = -inf;
        Info.minPairAngle = acosd(min(1,max(-1,max(G(:)))));
    end
end

