function  [dmodel,perf] = dacefit(S,Y,regr,corr,theta0,lob,upb)
% DACE模型拟合函数 - 约束非线性最小二乘拟合
% 基于给定相关模型和回归模型对提供的数据集进行约束非线性最小二乘拟合
%
% 调用格式:
%   [dmodel, perf] = dacefit(S, Y, regr, corr, theta0)
%   [dmodel, perf] = dacefit(S, Y, regr, corr, theta0, lob, upb)
%
% 输入参数:
% S, Y    : 数据点 (S(i,:), Y(i,:)), i = 1,...,m
% regr    : 回归模型函数句柄
% corr    : 相关函数句柄
% theta0  : 相关函数参数的初始猜测
% lob,upb : 如果存在，则为theta的下界和上界
%           否则，使用theta0作为theta
%
% 输出参数:
% dmodel  : DACE模型：包含以下元素的结构体
%    regr   : 回归模型函数句柄
%    corr   : 相关函数句柄
%    theta  : 相关函数参数
%    beta   : 广义最小二乘估计
%    gamma  : 相关因子
%    sigma2 : 过程方差的最大似然估计
%    S      : 缩放后的设计点
%    Ssc    : 设计自变量的缩放因子
%    Ysc    : 设计因变量的缩放因子
%    C      : 相关矩阵的Cholesky因子
%    Ft     : 去相关回归矩阵
%    G      : 来自QR分解：Ft = Q*G'
% perf   : 性能信息结构体，包含以下元素
%    nv     : 目标函数评估次数
%    perf   : (q+2)*nv数组，其中q是theta元素的数量
%             各列保存当前值
%                 [theta;  psi(theta);  type]
%             |type| = 1, 2 或 3，分别表示'start', 'explore' 或 'move'
%             type的负值表示上升步
% hbn@imm.dtu.dk  
% 最后更新 2002年9月3日

    % 检查设计点
    [m,n] = size(S);  % 设计点数量及其维度
    sY    = size(Y);
    if min(sY) == 1
        Y = Y(:);  
        lY  = max(sY);  
    else       
        lY  = sY(1);
    end
    if m ~= lY
        error('S和Y必须具有相同的行数')
    end
    % 检查相关参数（如果给定）
    lth = length(theta0);
    if nargin > 5  % 优化情况
        if length(lob) ~= lth || length(upb) ~= lth
            error('theta0、lob和upb必须具有相同长度')
        end
        if any(lob <= 0) || any(upb < lob)
            error('边界必须满足  0 < lob <= upb')
        end
    else  % 给定theta
        if any(theta0 <= 0)
            error('theta0必须严格为正')
        end
    end
    % 数据归一化
    mS = mean(S);   sS = std(S);
    mY = mean(Y);   sY = std(Y);
    % 2002.08.27: 检查'缺失维度'
    j = find(sS == 0);
    if ~isempty(j)
        sS(j) = 1;
    end
    j = find(sY == 0);
    if  ~isempty(j)
        sY(j) = 1;
    end
    S = (S - repmat(mS,m,1)) ./ repmat(sS,m,1);
    Y = (Y - repmat(mY,m,1)) ./ repmat(sY,m,1);
    % 计算点间距离D
    mzmax = m*(m-1) / 2;        % 非零距离数量
    ij    = zeros(mzmax, 2);  	% 用索引初始化矩阵
    D     = zeros(mzmax, n);  	% 用距离初始化矩阵
    LL    = 0;
    for k = 1 : m-1
        LL       = LL(end) + (1 : m-k);
        ij(LL,:) = [repmat(k,m-k,1) (k+1:m)']; % 稀疏矩阵的索引
        D(LL,:)  = repmat(S(k,:),m-k,1)-S(k+1:m,:); % 点间差值
    end
%     if min(sum(abs(D),2) ) == 0
%         error('Multiple design sites are not allowed')
%     end
    % 回归矩阵
    F      = feval(regr, S);  
    [mF,p] = size(F);
    if mF ~= m
        error('F的行数与S不匹配')
    end
    if p > mF 
        error('最小二乘问题欠定')
    end
    % 目标函数参数
    par = struct('corr',corr,'regr',regr,'y',Y,'F',F,'D',D,'ij',ij,'scS',sS);
    % 确定theta
    if nargin > 5
        % 边界约束非线性优化
        [theta, f, fit, perf] = boxmin(theta0, lob, upb, par);
        if  isinf(f)
            error('Bad parameter region.  Try increasing  upb')
        end
    else
        % 给定theta
        theta   = theta0(:);   
        [f,fit] = objfunc(theta, par);
        perf    = struct('perf',[theta; f; 1], 'nv',1);
        if  isinf(f)
            error('Bad point.  Try increasing theta0')
        end
    end
    % 返回值
    dmodel = struct('regr',regr,'corr',corr,'theta',theta.','beta',fit.beta,...
                    'gamma',fit.gamma,'sigma2',sY.^2.*fit.sigma2,'S',S,'Ssc',[mS; sS],...
                    'Ysc',[mY; sY],'C',fit.C,'Ft',fit.Ft,'G',fit.G);
end

function  [obj, fit] = objfunc(theta, par)
    % 目标函数计算 - DACE模型拟合的核心优化函数
    % 计算给定theta参数下的目标函数值和拟合参数
    
    % 初始化
    obj = inf; 
    fit = struct('sigma2',NaN,'beta',NaN,'gamma',NaN,'C',NaN,'Ft',NaN,'G',NaN);
    m   = size(par.F,1);
    % 建立R矩阵
    r   = feval(par.corr, theta, par.D);
    idx = find(r > 0);   o = (1 : m)';   
    mu  = (10+m)*eps;
    R   = sparse([par.ij(idx,1); o],[par.ij(idx,2); o],[r(idx); ones(m,1)+mu]);  
    % Cholesky分解并检查正定性
    [C,rd] = chol(R);
    if rd
        return;
    end
    % 获取最小二乘解
    C     = C';
    Ft    = C \ par.F;
    [Q,G] = qr(Ft,0);
    if rcond(G) < 1e-10
        % 检查F
        if cond(par.F) > 1e15 
            error('F病态严重\n回归模型和设计点组合不佳')
        else  % Ft矩阵病态严重
            return 
        end 
    end
    Yt   = C \ par.y;
    beta = G \ (Q'*Yt);
    rho  = Yt - Ft*beta;  sigma2 = sum(rho.^2)/m;
    detR = prod( full(diag(C)) .^ (2/m) );
    obj  = sum(sigma2) * detR;
    if nargout > 1
        fit = struct('sigma2',sigma2,'beta',beta,'gamma',rho'/C,'C',C,'Ft',Ft,'G',G');
    end
end

function  [t,f,fit,perf] = boxmin(t0,lo,up,par)
%BOXMIN  正值边界约束优化
% 使用Box算法进行边界约束的非线性优化

    % 初始化
    [t, f, fit, itpar] = start(t0, lo, up, par);
    if  ~isinf(f)
        % 迭代
        p = length(t);
        if  p <= 2
            kmax = 2;
        else
            kmax = min(p,4);
        end
        for k = 1 : kmax
            th = t;
            [t, f, fit, itpar] = explore(t, f, fit, itpar, par);
            [t, f, fit, itpar] = move(th, t, f, fit, itpar, par);
        end
    end
    perf = struct('nv',itpar.nv, 'perf',itpar.perf(:,1:itpar.nv));
end

function [t,f,fit,itpar] = start(t0,lo,up,par)
% 获取起始点和迭代参数

    % 初始化
    t  = t0(:);
    lo = lo(:);
    up = up(:);
    p  = length(t);
    D  = 2 .^((1:p)'/(p+2));
    ee = find(up == lo);  % 等式约束
    if ~isempty(ee)
        D(ee) = ones(length(ee),1);
        t(ee) = up(ee); 
    end
    ng = find(t < lo | up < t);  % 自由起始值
    if ~isempty(ng)
        t(ng) = (lo(ng) .* up(ng).^7).^(1/8);  % 起始点
    end
    ne = find(D ~= 1);
    % 检查起始点并初始化性能信息
    [f,fit] = objfunc(t,par);
    nv      = 1;
    itpar   = struct('D',D,'ne',ne,'lo',lo,'up',up,'perf',zeros(p+2,200*p),'nv',1);
    itpar.perf(:,1) = [t; f; 1];
    if isinf(f)    % 不良参数区域
        return
    end
    if length(ng) > 1  % 尝试改进起始猜测
        d0 = 16;  d1 = 2;   q = length(ng);
        th = t;   fh = f;   jdom = ng(1);  
        for k = 1 : q
            j  = ng(k);
            fk = fh;
            tk = th;
            DD = ones(p,1);  DD(ng) = repmat(1/d1,q,1);  DD(j) = 1/d0;
            alpha = min(log(lo(ng) ./ th(ng)) ./ log(DD(ng))) / 5;
            v = DD .^ alpha;
            for rept = 1 : 4
                tt = tk .* v; 
                [ff, fitt] = objfunc(tt,par);  nv = nv+1;
                itpar.perf(:,nv) = [tt; ff; 1];
                if ff <= fk 
                    tk = tt;
                    fk = ff;
                    if  ff <= f
                        t   = tt;
                        f   = ff;
                        fit = fitt;
                        jdom = j;
                    end
                else
                    itpar.perf(end,nv) = -1;
                    break
                end
            end
        end % 改进
        % 更新Delta  
        if  jdom > 1
            D([1 jdom]) = D([jdom 1]); 
            itpar.D = D;
        end
    end % 自由变量
    itpar.nv = nv;
end

function [t,f,fit,itpar] = explore(t,f,fit,itpar,par)
% 探索步骤 - 在每个方向上探索改进

    nv = itpar.nv;
    ne = itpar.ne;
    for k = 1 : length(ne)
        j  = ne(k);
        tt = t;
        DD = itpar.D(j);
        if t(j) == itpar.up(j)
            atbd  = 1;
            tt(j) = t(j) / sqrt(DD);
        elseif t(j) == itpar.lo(j)
            atbd  = 1;
            tt(j) = t(j) * sqrt(DD);
        else
            atbd  = 0;
            tt(j) = min(itpar.up(j), t(j)*DD);
        end
        [ff,fitt] = objfunc(tt,par);
        nv = nv+1;
        itpar.perf(:,nv) = [tt; ff; 2];
        if ff < f
            t   = tt;
            f   = ff;
            fit = fitt;
        else
            itpar.perf(end,nv) = -2;
            if ~atbd  % 尝试减小
                tt(j) = max(itpar.lo(j), t(j)/DD);
                [ff,fitt] = objfunc(tt,par);
                nv = nv+1;
                itpar.perf(:,nv) = [tt; ff; 2];
                if ff < f
                    t   = tt;
                    f   = ff;
                    fit = fitt;
                else
                    itpar.perf(end,nv) = -2;
                end
            end
        end
    end
    itpar.nv = nv;
end

function [t,f,fit,itpar] = move(th,t,f,fit,itpar,par)
% 模式移动 - 基于成功方向的模式搜索

    nv = itpar.nv;
    p  = length(t);
    v  = t ./ th;
    if  all(v == 1)
        itpar.D = itpar.D([2:p 1]).^.2;
        return;
    end
    % 适当移动
    rept = 1;
    while  rept
        tt = min(itpar.up, max(itpar.lo, t .* v));  
        [ff,fitt] = objfunc(tt,par); 
        nv = nv+1;
        itpar.perf(:,nv) = [tt; ff; 3];
        if  ff < f
            t   = tt;
            f   = ff;
            fit = fitt;
            v   = v .^ 2;
        else
            itpar.perf(end,nv) = -3;
            rept = 0;
        end
        if any(tt == itpar.lo | tt == itpar.up)
            rept = 0;
        end
    end
    itpar.nv = nv;
    itpar.D  = itpar.D([2:p 1]).^.25;
end

function [r,dr] = corrgauss(theta,d)
%CORRGAUSS  高斯相关函数
% 实现高斯相关函数及其导数计算

    [m,n] = size(d);  % 差值数量和数据维度
    if length(theta) == 1
        theta = repmat(theta,1,n);
    elseif length(theta) ~= n
        error('theta长度必须为1或%d',n)
    end
    td = d.^2 .* repmat(-theta(:).',m,1);
    r  = exp(sum(td, 2));
	dr = repmat(-2*theta(:).',m,1) .* d .* repmat(r,1,n);
end

function [f,df] = regpoly0(S)
%REGPOLY0  零阶多项式回归函数
% 零阶多项式回归，常数模型

    f  = ones(size(S,1),1);
	df = zeros(size(S,2),1);
end

function [f,df] = regpoly1(S)
%REGPOLY1  一阶多项式回归函数
% 一阶多项式回归，包含常数项和线性项

    f  = [ones(size(S,1),1),S];
	df = [zeros(size(S,2),1),eye(size(S,2))];
end