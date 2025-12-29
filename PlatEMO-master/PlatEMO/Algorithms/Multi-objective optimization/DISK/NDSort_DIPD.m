function [FrontNo,MaxFNo] = NDSort_DIPD(PopDec,PopObj,ObjMSE,nSort)
% 基于分布信息的非支配排序（DIPD）：考虑代理模型不确定性和种群分布的非支配排序算法
% 输入：
%   PopDec - 决策变量矩阵
%   PopObj - 代理模型预测的目标函数值矩阵
%   ObjMSE - 代理模型预测的均方误差矩阵
%   nSort  - 需要排序的解的数量
% 输出：
%   FrontNo - 每个解的前沿编号
%   MaxFNo  - 最大前沿编号

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: z.zhang0@csu.edu.cn)

    global  mu K % 全局变量：均值向量和协方差矩阵
    [N,~] = size(PopObj); % 解的数量
    [~,D] = size(PopDec); % 决策变量维度
    
    %% 计算每个解的分布概率密度
    Pro   = zeros(N,1); % 概率密度向量
    for j = 1 : N
        % 多元高斯分布概率密度函数
        Pro(j,:) = (1/(det(K)^(1/2)*(2*pi)^(D/2)))*exp(-0.5*(PopDec(j,:) - mu)*(K^-1)*(PopDec(j,:) - mu)');
    end
    
    %% 计算基于代理模型不确定性的支配概率
    % 计算两个解之间差异的标准偏差
    sigma = sqrt(ObjMSE(reshape(ones(N,1)*(1:N),N*N,1),:) + repmat(ObjMSE,N,1));
    % 计算两个解之间目标值的差异
    mean  = PopObj(reshape(ones(N,1)*(1:N),N*N,1),:) - repmat(PopObj,N,1);
    % 计算解i支配解j的概率
    x_PD  = normcdf((0-mean)./sigma);
    % 计算解j支配解i的概率
    y_PD  = 1 - x_PD;
    
    %% 结合分布信息调整支配概率
    x_PD = - x_PD.*Pro(reshape(ones(N,1)*(1:N),N*N,1),:);
    y_PD = - y_PD.*repmat(Pro,N,1);
    
    %% 构建支配关系矩阵
    dominate = false(N); % 支配关系矩阵，dominate(i,j)=true表示i支配j
    for i = 1 : N-1
        for j = i+1 : N
            % 检查解i是否支配解j
            if all(x_PD(N*(i-1)+j,:) <= y_PD(N*(i-1)+j,:)) && ~all(x_PD(N*(i-1)+j,:) == y_PD(N*(i-1)+j,:))
                dominate(i,j) = true;
            % 检查解j是否支配解i
            elseif all(x_PD(N*(i-1)+j,:) >= y_PD(N*(i-1)+j,:)) && ~all(x_PD(N*(i-1)+j,:) == y_PD(N*(i-1)+j,:))
                dominate(j,i) = true;
            end
        end
    end

    %% 非支配排序过程
    FrontNo = inf(1,N); % 初始化为无穷大，表示未分配前沿
    MaxFNo  = 0; % 最大前沿编号
    while sum(FrontNo~=inf) < min(nSort,N) % 当已排序的解数小于nSort或N时
        MaxFNo                     = MaxFNo + 1; % 前沿编号加1
        current                    = find(FrontNo==inf); % 当前未分配前沿的解
        dominate_                  = sum(dominate(current,current),1); % 计算每个解被支配的次数
        index                      = find(dominate_==min(dominate_)); % 找到被支配次数最少的解
        FrontNo(current(index))    = MaxFNo; % 分配当前前沿
        dominate(current(index),:) = false; % 将这些解标记为不支配其他任何解
    end
end