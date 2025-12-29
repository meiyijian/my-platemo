function DB = LocalSearch(P,W,ideal,wmax,Model,DB,Problem)
% 局部搜索：基于权重向量和代理模型的局部搜索，用于自适应探索
% 输入：
%   P     - 进化搜索后的种群
%   W     - 识别出的最远权重向量
%   ideal - 理想点
%   wmax  - 局部搜索代数
%   Model - 克里金代理模型集合
%   DB    - 真实评估的种群
%   Problem - 优化问题对象
% 输出：
%   DB    - 更新后的真实评估种群

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: z.zhang0@csu.edu.cn)

    w     = 1; % 局部搜索代数计数器
    [N,~] = size(P.decs); % 种群规模
    while w <= wmax   % 局部搜索循环
        % 生成多种变异操作的后代
        OffDec1 = OperatorGA(Problem,P.decs); % 遗传算法
        OffDec2 = OperatorDE_current_rand_1(Problem,P.decs); % DE/current-to-rand/1
        OffDec3 = OperatorDE_rand_1(Problem,P.decs); % DE/rand/1
        OffDec4 = OperatorDE_current_rand_1(Problem,P.decs); % DE/current-to-rand/1
        P.decs  = [P.decs;OffDec1;OffDec2;OffDec3;OffDec4]; % 合并所有解
        P.decs  = unique(P.decs,'rows'); % 去重，避免重复计算
        
        [P.objs,P.objmse] = model_predict(Model,P.decs); % 代理模型预测
        P.objmse = sqrt(P.objmse); % 转换为标准差
                
        % 计算适应度：基于加权切比雪夫距离和代理模型不确定性
        fitness = max(abs(P.objs - ideal).*W,[],2) - 2*mean(P.objmse,2);       
        
        [~,Rank] = sort(fitness);    % 按适应度排序
        P.decs   = P.decs(Rank(1:N),:); % 保留前N个最优解
        P.objs   = P.objs(Rank(1:N),:);
        P.objmse = P.objmse(Rank(1:N),:);
        w = w + 1; % 搜索代数加1
    end
    
    % 最终选择最优解进行真实评估
    fitness  = max(abs(P.objs - ideal).*W,[],2) - 2*mean(P.objmse,2);
    [~,Rank] = sort(fitness);
    PopNew   = P.decs(Rank(1),:); % 选择最优解
    dist2    = pdist2(real(PopNew),real(DB.decs)); % 检查是否已存在于真实评估种群中
    if min(dist2) > 1e-50 % 如果是新解
        DB = [DB,Problem.Evaluation(PopNew)]; % 真实评估并添加到种群
    end
end

function [OffObj,Off_ObjMSE] = model_predict(Model,OffDec)
% 使用克里金模型预测目标函数值和均方误差（与DISK.m中的同名函数功能相同）
% 输入：
%   Model  - 克里金模型集合
%   OffDec - 需要预测的决策变量集合
% 输出：
%   OffObj     - 预测的目标函数值
%   Off_ObjMSE - 预测的均方误差
    N          = size(OffDec,1); % 需要预测的样本数量
    Len_obj    = length(Model); % 目标函数数量
    OffObj     = zeros(N,Len_obj); % 初始化预测目标值矩阵
    Off_ObjMSE = zeros(N,Len_obj); % 初始化预测均方误差矩阵
   
    for i = 1 : N % 遍历每个样本
        for j = 1 : Len_obj % 遍历每个目标函数
            [OffObj(i,j),~,Off_ObjMSE(i,j)] = predictor(OffDec(i,:),Model{j}); % 使用克里金模型预测
        end
    end
    OffObj     = real(OffObj); % 确保实数值
    Off_ObjMSE = abs(real(Off_ObjMSE)); % 确保均方误差为正数
end