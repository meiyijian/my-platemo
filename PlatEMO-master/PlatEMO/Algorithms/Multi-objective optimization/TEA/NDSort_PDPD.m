function[FrontNo,MaxFNo] = NDSort_PDPD(varargin)
% NDSort_PDPD - 基于概率的PDPD非支配排序算法
% 该函数实现概率支配关系(Probabilistic Domination)的非支配排序
% 根据预测不确定性对解进行分层排序，适用于代理模型辅助优化
%
% 输入参数（变参形式）:
% 第1种调用方式（有3个参数）:
%   varargin{1} - PopObj: 种群目标值矩阵
%   varargin{2} - ObjMSE: 目标函数预测误差矩阵
%   varargin{3} - nSort: 需要排序的解数量
%
% 第2种调用方式（有5个参数）:
%   varargin{1} - PopObj: 种群目标值矩阵
%   varargin{2} - ObjMSE: 目标函数预测误差矩阵
%   varargin{3} - PopCon: 约束条件矩阵
%   varargin{4} - ConMSE: 约束条件预测误差矩阵
%   varargin{5} - nSort: 需要排序的解数量
%
% 输出参数:
% FrontNo - 每个解所属的前沿层号
% MaxFNo  - 最大前沿层数

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or acknowledge
% the use of "PlatEMO" and reference "Ye Tian, Ran Cheng, Xingyi Zhang, and
% Yaochu Jin, PlatEMO: A MATLAB platform for evolutionary multi-objective
% optimization [educational forum], IEEE Computational Intelligence Magazine,
% 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao_zhang0@163.com)

    %% 数据读取与预处理
    PopObj = varargin{1};    % 目标值矩阵
    ObjMSE = varargin{2};    % 目标函数预测误差
    
    % 根据参数数量确定处理模式
    if nargin == 3
        % 模式1：无约束优化的非支配排序
        nSort = varargin{3};  % 需要排序的解数量
        mark  = 1;            % 标记：无约束模式
    elseif nargin == 5
        % 模式2：约束优化的非支配排序
        PopCon = varargin{3}; % 约束条件矩阵
        ConMSE = varargin{4}; % 约束条件预测误差
        nSort  = varargin{5}; % 需要排序的解数量
        
        % 计算可行概率和总体可行概率
        [LPoF,TPoF] = Feasible_Probability(PopCon,ConMSE);
        mark = 0;            % 标记：约束优化模式
    end
    
    epsilon = 0.75;          % 概率支配关系的判断阈值

    %% 构建概率支配矩阵
    N = size(PopObj,1);      % 种群大小
    
    % 计算统计量用于概率支配判断
    % 合并预测值和预测误差，用于正态分布计算
    sigma = sqrt(ObjMSE(reshape(ones(N,1)*(1:N),N*N,1),:) + repmat(ObjMSE,N,1));
    mean  = PopObj(reshape(ones(N,1)*(1:N),N*N,1),:) - repmat(PopObj,N,1);
    
    % 使用正态分布累积分布函数计算概率
    x_PD = normcdf((0-mean)./sigma);  % 解i支配解j的概率
    y_PD = 1 - x_PD;                   % 解j支配解i的概率（互补概率）
    
    % 初始化支配关系矩阵
    dominate = false(N);
    
    %% 逐对计算概率支配关系
    for i = 1 : N-1
        for j = i+1 : N
            % 获取两个解之间的概率值
            Pi = x_PD(N*(i-1)+j,:);  % 解i的支配概率向量
            Pj = y_PD(N*(i-1)+j,:);  % 解j的支配概率向量
            
            % 寻找差异显著的概率值（用于概率支配判断）
            index1 = find(abs(Pi - Pj) <= epsilon);  % 差异较小的概率值
            index2 = 1 : length(Pi);                 % 所有概率值索引
            index2(index1) = [];                     % 移除差异小的概率值
            
            % 计算概率支配度（PD）：差异显著的概率值乘积
            PDi = prod(Pi(index1));  % 解i的概率支配度
            PDj = prod(Pj(index1));  % 解j的概率支配度
    
            if mark == 1
                % === 无约束模式的概率支配判断 ===
                % 比较[-Pi(index2),-PDi]与[-Pj(index2),-PDj]
                if all([-Pi(index2),-PDi] <= [-Pj(index2),-PDj]) && ...
                   ~all([-Pi(index2),-PDi] == [-Pj(index2),-PDj])
                    flag = 1;  % 解i支配解j
                elseif all([-Pi(index2),-PDi] >= [-Pj(index2),-PDj]) && ...
                       ~all([-Pi(index2),-PDi] == [-Pj(index2),-PDj])
                    flag = 2;  % 解j支配解i
                else
                    flag = 3;  % 互不支配
                end
            else 
                % === 约束优化模式的概率支配判断 ===
                % 基于可行概率的约束处理
                if ((LPoF(i) >= 0.5) && (LPoF(j) >= 0.5)) || (LPoF(i) == LPoF(j))
                    % 两个解都可行或可行概率相等，使用概率支配判断
                    if all([-Pi(index2),-PDi] <= [-Pj(index2),-PDj]) && ...
                       ~all([-Pi(index2),-PDi] == [-Pj(index2),-PDj])
                        flag = 1;  % 解i支配解j
                    elseif all([-Pi(index2),-PDi] >= [-Pj(index2),-PDj]) && ...
                           ~all([-Pi(index2),-PDi] == [-Pj(index2),-PDj])
                        flag = 2;  % 解j支配解i
                    else
                        flag = 3;  % 互不支配
                    end
                else
                    % 至少一个解不可行，选择可行概率更大的解
                    [~,flag] = max([TPoF(i),TPoF(j)]);
                end
            end
            
            % 更新支配关系矩阵
            if flag == 1
                dominate(i,j) = true;   % 解i支配解j
            elseif flag == 2
                dominate(j,i) = true;   % 解j支配解i
            end
            % flag == 3时，互不支配，矩阵中保持false
        end
    end
    
    %% 非支配排序
    FrontNo = inf(1,N);      % 初始化前沿层号（无穷大表示未排序）
    MaxFNo  = 0;             % 当前最大前沿层数
    
    % 逐层排序，直到达到要求的排序数量或所有解都被排序
    while sum(FrontNo~=inf) < min(nSort,N)
        MaxFNo = MaxFNo + 1;  % 增加一个前沿层
        
        % 找到当前未排序的解
        current = find(FrontNo==inf);
        
        % 计算每个解被多少个其他解支配
        dominate_ = sum(dominate(current,current),1);
        
        % 选择被支配数量最少的解（可能是第一个前沿）
        index = find(dominate_==min(dominate_));
        
        % 将选中的解分配到当前前沿层
        FrontNo(current(index)) = MaxFNo;
        
        % 从支配矩阵中移除已排序的解
        dominate(current(index),:) = false;
    end
end

function [LPoF,TPoF] = Feasible_Probability(PopCon,ConMSE)
% Feasible_Probability - 计算约束可行概率
% 该函数计算每个解满足约束条件的概率，基于正态分布假设
%
% 输入参数:
% PopCon - 约束条件矩阵（负值表示违反约束）
% ConMSE - 约束条件预测误差矩阵
%
% 输出参数:
% LPoF - 局部可行概率（取所有约束条件的最小可行概率）
% TPoF - 总体可行概率（所有约束条件同时满足的概率）

    [N,M] = size(PopCon);    % N：解的数量，M：约束条件的数量
    LPoF  = ones(N,1);        % 初始化局部可行概率为1
    TPoF  = ones(N,1);        % 初始化总体可行概率为1
    
    %% 逐个计算每个解的可行概率
    for i = 1 : N
        for j = 1 : M
            % 计算约束j的可行概率（使用正态分布累积分布函数）
            prob = normcdf((0-PopCon(i,j))/sqrt(ConMSE(i,j)));
            
            % 局部可行概率：取所有约束的最小可行概率
            LPoF(i) = min([LPoF(i),prob]);
            
            % 总体可行概率：所有约束同时满足的概率（独立假设）
            TPoF(i) = TPoF(i)*prob;
        end
    end
end