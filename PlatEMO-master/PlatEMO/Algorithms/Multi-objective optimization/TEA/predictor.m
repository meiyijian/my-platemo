function [y,or1,or2,dmse] = predictor(x,dmodel)
%PREDICTOR  DACE模型预测器 - 基于给定DACE模型预测y(x)的函数值
% 使用DACE模型对目标函数进行预测，包括函数值、梯度和均方误差估计
%
% 调用格式:
%   y = predictor(x, dmodel)
%   [y, or] = predictor(x, dmodel)
%   [y, dy, mse] = predictor(x, dmodel) 
%   [y, dy, mse, dmse] = predictor(x, dmodel) 
%
% 输入参数:
% x      : 试验设计点，具有n维。对于mx个试验点x：
%          如果mx = 1，则接受行向量和列向量，
%          否则，x必须是mx*n矩阵，按行存储各点
% dmodel : DACE模型结构体；参见DACEFIT
%
% 输出参数:
% y    : 在x处的预测响应值
% or   : 如果mx = 1，则or为预测器的梯度向量/雅可比矩阵
%        否则，or是包含mx行的向量，表示预测器的估计均方误差
% 仅当mx = 1时允许三个或四个输出结果，
% dy   : 预测器梯度；包含n个元素的列向量
% mse  : 预测器的估计均方误差
% dmse : mse的梯度向量/雅可比矩阵
% hbn@imm.dtu.dk
% 最后更新 2002年8月26日

    or1 = NaN; or2 = NaN; dmse = NaN;	% 默认返回值
    if isnan(dmodel.beta)
        error('DMODEL未找到')
    end
    [m,n] = size(dmodel.S);     % 设计点数量和维度数量
    sx    = size(x);            % 试验点数量及其维度
    if min(sx) == 1 && n > 1    % 单个试验点 
        nx = max(sx);
        if nx == n 
            mx = 1;
            x  = x(:).';
        end
    else
        mx = sx(1);
        nx = sx(2);
    end
    if nx ~= n
        error('试验点维度应为%d',n)
    end
    % 归一化试验点  
    x = (x - repmat(dmodel.Ssc(1,:),mx,1)) ./ repmat(dmodel.Ssc(2,:),mx,1);
    q = size(dmodel.Ysc,2);  % 响应函数数量
    if mx == 1  % 单个试验点
        dx = repmat(x,m,1) - dmodel.S;  % 到设计点的距离
        if nargout > 1                  % 需要梯度/雅可比矩阵
            [f,df] = feval(dmodel.regr, x);
            [r,dr] = feval(dmodel.corr, dmodel.theta, dx);
            % 缩放后的雅可比矩阵
            dy = (df * dmodel.beta).' + dmodel.gamma * dr;
            % 未缩放的雅可比矩阵
            or1 = dy .* repmat(dmodel.Ysc(2, :)', 1, nx) ./ repmat(dmodel.Ssc(2,:), q, 1);
            if q == 1
                % 梯度作为列向量
                or1 = or1';
            end
            if nargout > 2  % 需要MSE
                rt = dmodel.C \ r;
                u = dmodel.Ft.' * rt - f.';
                v = dmodel.G \ u;
                or2 = repmat(dmodel.sigma2,mx,1) .* repmat((1 + sum(v.^2) - sum(rt.^2))',1,q);
                if nargout > 3  % 需要MSE的梯度/雅可比矩阵
                    % 缩放后的梯度作为行向量
                    Gv = dmodel.G' \ v;
                    g = (dmodel.Ft * Gv - rt)' * (dmodel.C \ dr) - (df * Gv)';
                    % 未缩放的雅可比矩阵
                    dmse = repmat(2 * dmodel.sigma2',1,nx) .* repmat(g ./ dmodel.Ssc(2,:),q,1);
                    if q == 1
                    % 梯度作为列向量
                    dmse = dmse';
                    end
                end
            end
        else  % 仅预测器
            f = feval(dmodel.regr, x);
            r = feval(dmodel.corr, dmodel.theta, dx);
        end
        % 缩放后的预测器
        sy = f * dmodel.beta + (dmodel.gamma*r).';
        % 预测器
        y = (dmodel.Ysc(1,:) + dmodel.Ysc(2,:) .* sy)';
	else  % 多个试验点
        % 获取到设计点的距离  
        dx = zeros(mx*m,n);
        kk = 1 : m;
        for k = 1 : mx
            dx(kk,:) = repmat(x(k,:),m,1) - dmodel.S;
            kk = kk + m;
        end
        % 获取回归函数和相关函数
        f = feval(dmodel.regr, x);
        r = feval(dmodel.corr, dmodel.theta, dx);
        r = reshape(r, m, mx);
        % 缩放后的预测器 
        sy = f * dmodel.beta + (dmodel.gamma * r).';
        % 预测器
        y = repmat(dmodel.Ysc(1,:),mx,1) + repmat(dmodel.Ysc(2,:),mx,1) .* sy;
        if nargout > 1	% 需要MSE
            rt  = dmodel.C \ r;
            u   = dmodel.G \ (dmodel.Ft.' * rt - f.');
            or1 = repmat(dmodel.sigma2,mx,1) .* repmat((1 + sum(u.^2,1) - sum(rt.^2,1))',1,q);
            if  nargout > 2
                disp('WARNING from PREDICTOR.  Only  y  and  or1=mse  are computed')
            end
        end
    end
end

function [r,dr] = corrgauss(theta,d)
%CORRGAUSS  高斯相关函数
% 实现高斯相关函数及其导数计算，用于DACE模型的相关性建模

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
% 零阶多项式回归，常数模型，无自变量项

    f  = ones(size(S,1),1);
	df = zeros(size(S,2),1);
end

function [f,df] = regpoly1(S)
%REGPOLY1  一阶多项式回归函数
% 一阶多项式回归，包含常数项和线性项

    f  = [ones(size(S,1),1),S];
	df = [zeros(size(S,2),1),eye(size(S,2))];
end