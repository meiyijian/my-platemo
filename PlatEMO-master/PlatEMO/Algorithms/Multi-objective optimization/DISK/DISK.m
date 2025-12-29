classdef DISK < ALGORITHM
% <2024> <multi/many> <real/integer> <expensive>
% Distribution-based Kriging-assisted evolutionary algorithm
% wmax  --- 60 --- Generations of evolutionary search
% alpha ---  5 --- Number of selected candidates

%------------------------------- Reference --------------------------------
% Z. Zhang, Y. Wang, G. Sun, and T. Pang. A distribution information based 
% Kriging-assisted evolutionary algorithm for expensive many-objective 
% optimization problems. IEEE Transactions on Evolutionary Computation, 
% 2024.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: z.zhang0@csu.edu.cn)

% 算法概述：基于分布信息的克里金辅助昂贵多目标进化算法
% 核心思想：
% 1. 使用克里金代理模型近似目标函数，减少真实评估次数
% 2. 学习种群分布信息，引导进化搜索
% 3. 结合基于分布信息的非支配排序（NDSort_DIPD）
% 4. 自适应探索机制，平衡全局探索和局部开发
% 5. 多阶段环境选择策略，保证种群多样性和收敛性

    methods
        function main(Algorithm,Problem)
            %% Parameter setting
            global NI mu K % 全局变量：种群规模、均值向量、协方差矩阵
            [wmax,alpha] = Algorithm.ParameterSet(60,5); % 设置算法参数：进化代数(60)和候选选择数量(5)
            
            %% Initialization
            NI    = Problem.N; % 种群规模
            OP    = UniformPoint(NI,Problem.D,'Latin'); % Latin超立方体采样生成初始种群决策变量
            A2    = Problem.Evaluation(repmat(Problem.upper-Problem.lower,NI,1).*OP+repmat(Problem.lower,NI,1)); % 初始种群真实评估
            A1    = A2; % 辅助种群，用于进化搜索
            THETA = 5.*ones(Problem.M,Problem.D); % 克里金模型的超参数初始值
            Model = cell(1,Problem.M); % 初始化M个克里金模型（每个目标函数一个）
              
            while Algorithm.NotTerminated(A2) % 算法终止条件判断
                %% Surrogate Construction
                [Model,THETA] = model_train(A2,Model,THETA); % 构建/更新克里金代理模型
                
                %% Learning Distribution
                % 从当前种群中学习分布信息
                [F,~]  = NDSort(A2.objs,inf); % 非支配排序
                PopDec = A2(F==1).decs; % 获取第一前沿解的决策变量
                if size(PopDec,1) <= 1 % 如果第一前沿解太少，加入第二前沿解
                    PopDec = [PopDec; A2(F==2).decs];
                end
                mu = mean(PopDec,1); % 计算均值向量
                K  = (PopDec-mu)'*(PopDec-mu)/(size(PopDec,1)-1); % 计算协方差矩阵
                  
                %% Evolutionary Search
                % 使用代理模型辅助进化搜索，生成新的候选解
                OP = optimizaiton(A1,wmax,Model,Problem);
                
                %% Candidate Selection
                % 从候选解中选择最优的alpha个解进行真实评估
                C = NewSelect(OP,A2,alpha,Problem);
                
                %% Adaptive Exploration
                % 自适应探索机制，判断是否需要进行局部搜索
                flag = 0; % 局部搜索标志
                if ~isempty(C) % 如果有新选择的候选解
                    flag = judgeLS(C,A2); % 判断是否需要进行局部搜索
                    A2   = [A2,C]; % 将新候选解添加到真实评估种群
                end
                if flag == 1 % 如果需要局部搜索
                    % 重新构建代理模型
                    [Model,THETA] = model_train(A2,Model,THETA);
                    % 识别探索方向
                    [W,ideal]     = IdentifyW(A2,Problem.N,Problem.M);
                    % 执行局部搜索
                    A2            = LocalSearch(OP,W,ideal,wmax,Model,A2,Problem);
                end
                
                %% Population Update
                % 环境选择，保持种群规模为NI
                index = EnvironmentalSelection(A2.objs,NI);
                A1    = A2(index); % 更新辅助种群
            end
        end
    end
end

function [Model,THETA] = model_train(A2,Model,THETA)
% 构建/更新克里金代理模型
% 输入：
%   A2     - 真实评估的种群
%   Model  - 当前的克里金模型集合
%   THETA  - 当前的超参数矩阵
% 输出：
%   Model  - 更新后的克里金模型集合
%   THETA  - 更新后的超参数矩阵
    Dec     = A2.decs; % 决策变量
    Obj     = A2.objs; % 目标函数值
    Len_dec = size(Dec,2); % 决策变量维度
    Len_obj = size(Obj,2); % 目标函数数量
    for i = 1 : Len_obj % 为每个目标函数构建克里金模型
        % 去除重复样本，避免过拟合
        [~,distinct1] = unique(round(Dec*1e100)/1e100,'rows'); % 决策变量去重
        [~,distinct2] = unique(round(Obj(:,i)*1e100)/1e100,'rows'); % 目标函数值去重
        distinct      = intersect(distinct1,distinct2); % 交集，确保每个样本唯一

        % 训练克里金模型：使用regpoly1（一阶多项式回归）和corrgauss（高斯核函数）
        dmodel     = dacefit(Dec(distinct,:),Obj(distinct,i),'regpoly1','corrgauss',THETA(i,:),1e-5.*ones(1,Len_dec),100.*ones(1,Len_dec));
        Model{i}   = dmodel; % 保存模型
        THETA(i,:) = dmodel.theta; % 更新超参数
    end
end

function [OffObj,Off_ObjMSE] = model_predict(Model,OffDec)
% 使用克里金模型预测目标函数值和均方误差
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

function P = optimizaiton(Population,wmax,Model,Problem)
% 使用遗传算法进行代理辅助进化搜索
% 输入：
%   Population - 初始种群
%   wmax       - 进化代数
%   Model      - 克里金模型集合
%   Problem    - 优化问题对象
% 输出：
%   P          - 进化后的种群，包含决策变量、预测目标值和预测误差
    w      = 1; % 进化代数计数器
    [N,~]  = size(Population.decs); % 初始种群规模
    P.decs = Population.decs; % 初始化种群结构
    while w <= wmax    % 进化循环
        OffDec = OperatorGA(Problem,P.decs); % 使用遗传算法生成后代
        P.decs = [P.decs;OffDec]; % 合并父代和子代
        [P.objs,P.objmse] = model_predict(Model,P.decs); % 代理模型预测目标值和误差
                
        index = SEnvironmentalSelection(P,N);  % 基于代理模型的环境选择
        
        P.decs   = P.decs(index,:); % 更新种群决策变量
        P.objs   = P.objs(index,:); % 更新种群预测目标值
        P.objmse = P.objmse(index,:); % 更新种群预测误差
              
        w = w + 1; % 进化代数加1
    end
end

function flag = judgeLS(C,A2)
% 判断是否需要进行局部搜索
% 输入：
%   C   - 新选择的候选解
%   A2  - 真实评估的种群
% 输出：
%   flag - 1表示需要局部搜索，0表示不需要
    [F1,~] = NDSort(C.objs,1); % 候选解的非支配排序
    AObj   = C(F1==1).objs; % 候选解中的非支配解
    [F2,~] = NDSort(A2.objs,1); % 真实评估种群的非支配排序
    A2Obj  = A2(F2==1).objs; % 真实评估种群中的非支配解
    N1     = size(AObj,1); % 候选解中非支配解数量
    N2     = size(A2Obj,1); % 真实评估种群中非支配解数量

    dominate = zeros(N1,N2); % 支配关系矩阵
    for i = 1 : N1 % 遍历候选解中的非支配解
        for j = 1 : N2 % 遍历真实评估种群中的非支配解
            if all(AObj(i,:) <= A2Obj(j,:)) && ~all(AObj(i,:) == A2Obj(j,:)) % 判断支配关系
                dominate(i,j) = true; % 候选解i支配真实评估解j
            end
        end
    end
    if any(any(dominate)) % 如果有候选解支配真实评估解
        flag = 0; % 不需要局部搜索
    else % 否则需要局部搜索
        flag = 1;
    end
end