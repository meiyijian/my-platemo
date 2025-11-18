classdef TEA < ALGORITHM
% <2024> <multi/many> <real/integer> <expensive> <constrained/none>
% 两阶段进化算法（Two-phase Evolutionary Algorithm, TEA）
% 核心用途：解决昂贵约束多目标优化问题（测试/仿真成本高、需优化多个目标、含约束条件）
% 适配场景：多目标/超多目标、实数/整数变量、昂贵优化（少真实评估）、带约束/无约束问题
%
% 参数说明（可调整）：
% wmax --- 20 --- 进化搜索的迭代代数（每次进化过程的搜索步数）
% mu   ---  5 --- 候选解选择数量（每次迭代后筛选的最优待评估解个数）
%
%------------------------------- 参考文献 --------------------------------
% Z. Zhang, Y. Wang, J. Liu, G. Sun, and K. Tang. A two-phase Kriging-
% assisted evolutionary algorithm for expensive constrained multiobjective
% optimization problems. IEEE Transactions on Systems, Man, and
% Cybernetics: Systems, 2024, 54(8): 4579-4591.
%------------------------------- 版权声明 --------------------------------
% Copyright (c) 2025 BIMK Group. 可用于科研目的，使用时需引用PlatEMO平台文献
%--------------------------------------------------------------------------

% 代码作者：Zhiyao Zhang (邮箱: zhiyao_zhang0@163.com)
    
    methods
        % 算法主函数：接收算法对象（参数）和问题对象（优化任务），执行完整优化流程
        function main(Algorithm,Problem)
            %% 1. 全局变量与参数初始化
            % 全局变量：存储算法关键状态（当前阶段、种群规模、约束/目标函数数量）
            global phase NI Len_con Len_obj 
            % 读取/设置算法参数：wmax（进化代数）、mu（候选解数），默认值(20,5)，参数个数2
            [wmax,mu]      = Algorithm.ParameterSet(20,5,2);
            ct             = 0;          % 阶段切换计数器（记录满足切换条件的次数）
            ct_max         = 2;          % 阶段切换阈值（累计ct_max次满足条件则切换阶段）
            sample_success = 1;          % 采样成功标记（1=成功评估新解，0=未找到有效候选解）
            phase          = 1;          % 初始阶段：第一阶段（无约束导向搜索）

            %% 2. 初始种群生成与数据库建立
            NI        = Problem.N;       % 种群规模（从问题对象获取，固定数量的解）
            % 生成拉丁超立方采样的初始决策变量（均匀分布在变量空间，保证多样性）
            P         = UniformPoint(NI,Problem.D,'Latin');
            % 真实评估初始种群：将标准化的决策变量映射到实际变量范围，存入数据库
            % Database：存储所有已真实评估的解（含决策变量、目标值、约束值等）
            Database  = Problem.Evaluation(repmat(Problem.upper-Problem.lower,NI,1).*P+repmat(Problem.lower,NI,1));
            P         = Database;        % 初始种群 = 已评估的数据库（初始阶段无历史数据）
            Len_obj   = Problem.M;       % 目标函数个数（从问题对象获取，多目标优化的“目标数”）
            THETA_obj = 5.*ones(Len_obj,Problem.D);  % 目标函数Kriging模型的初始超参数（每个目标对应一组）
            Model_obj = cell(1,Len_obj); % 目标函数Kriging代理模型数组（每个目标一个模型）
            Len_con   = size(Database.cons,2);  % 约束函数个数（从数据库约束值维度获取）
            THETA_con = 5.*ones(Len_con,Problem.D);  % 约束函数Kriging模型的初始超参数
            Model_con = cell(1,Len_con); % 约束函数Kriging代理模型数组

            %% 3. 主优化循环（未满足终止条件则持续迭代）
            % Algorithm.NotTerminated(Database)：判断是否满足终止条件（如达到最大真实评估次数）
            while Algorithm.NotTerminated(Database)
                % 3.1 构建Kriging代理模型（仅当采样成功时更新模型，避免无效计算）
                if sample_success
                    % 调用model_train函数，用数据库中已真实评估的解训练/更新代理模型
                    % 输出：更新后的目标/约束代理模型，以及优化后的超参数
                    [Model_obj,Model_con,THETA_obj,THETA_con] = model_train(Database,THETA_obj,THETA_con);
                end

                % 3.2 进化搜索（基于代理模型生成新解）
                % 调用Evo_Search函数：用当前种群P，经过wmax代进化，基于代理模型预测
                % 输出：新生成的决策变量(PopDec)、预测目标值(PopObj)、预测约束值(PopCon)
                % 以及目标/约束预测的均方误差(ObjMSE/ConMSE，衡量预测不确定性)
                [PopDec,PopObj,PopCon,ObjMSE,ConMSE] = Evo_Search(P,wmax,Model_obj,Model_con,Problem);

                % 3.3 候选解选择（筛选最优待真实评估的解）
                % 调用Candi_Select函数：根据预测值、预测误差、现有数据库，筛选mu个最优候选解
                % 核心逻辑：平衡“目标最优性”“约束满足度”“预测不确定性”
                C = Candi_Select(PopDec,PopObj,PopCon,ObjMSE,ConMSE,Database,mu);

                % 3.4 阶段切换判断（第一阶段→第二阶段的触发逻辑）
                sample_success = 0;  % 初始化采样成功标记为0（默认未成功）
                if isempty(C) == 0   % 若筛选到有效候选解（C非空）
                    C = Problem.Evaluation(C);  % 真实评估候选解（昂贵操作，仅此处执行）
                    sample_success = 1;        % 标记采样成功（已获取真实目标/约束值）
                    % 调用Phase_Trans函数：判断是否满足阶段切换条件，更新阶段和计数器
                    [phase,ct]     = Phase_Trans(Database,C,ct,ct_max,phase);
                end

                % 3.5 种群重选（维持固定规模的优质种群）
                Database = [Database,C];  % 将新评估的解加入数据库（累计所有真实评估数据）
                % 调用Pop_Reselect函数：从数据库中筛选NI个最优解（考虑目标和约束），作为下一轮进化的父代种群
                index    = Pop_Reselect(Database.objs,Database.cons,NI);
                P        = Database(index);  % 更新种群P为筛选后的优质解
            end
        end
    end
end

% 辅助函数：训练/更新Kriging代理模型（目标函数+约束函数）
% 输入：Database（已真实评估的解）、THETA_obj/THETA_con（模型超参数）
% 输出：训练好的目标/约束模型、优化后的超参数
function [Model_obj,Model_con,THETA_obj,THETA_con] = model_train(Database,THETA_obj,THETA_con)
    global Len_con Len_obj phase  % 全局变量：约束/目标个数、当前算法阶段
    Dec     = Database.decs;      % 所有已评估解的决策变量（输入特征）
    Obj     = Database.objs;      % 所有已评估解的目标函数值（输出标签-目标）
    Con     = Database.cons;      % 所有已评估解的约束函数值（输出标签-约束）
    Len_dec = size(Dec,2);        % 决策变量维度（变量个数）
    Len_obj = size(Obj,2);        % 目标函数个数（重新确认，避免全局变量误差）
    Len_con = size(Con,2);        % 约束函数个数（重新确认）

    % 1. 训练目标函数的Kriging模型（每个目标独立训练一个模型）
    for i = 1 : Len_obj
        % 去重：删除决策变量完全相同的重复解（避免数值干扰，提高模型精度）
        [~,distinct1]  = unique(round(Dec*1e12)/1e12,'rows');
        % 去重：删除目标函数值完全相同的重复解（进一步净化训练数据）
        [~,distinct2]  = unique(round(Obj(:,i)*1e12)/1e12,'rows');
        distinct       = intersect(distinct1,distinct2);  % 同时满足决策变量和目标值唯一的索引
        % 训练Kriging模型：dacefit为Kriging建模函数
        % 核函数设置：regpoly1（一阶多项式趋势项）、corrgauss（高斯相关函数）
        % 超参数范围：1e-5~100（避免超参数过大/过小导致模型失效）
        dmodel         = dacefit(Dec(distinct,:),Obj(distinct,i),'regpoly1','corrgauss',THETA_obj(i,:),1e-5.*ones(1,Len_dec),100.*ones(1,Len_dec));
        Model_obj{i}   = dmodel;  % 存储训练好的第i个目标的模型
        THETA_obj(i,:) = dmodel.theta;  % 更新超参数为模型优化后的值（下次训练的初始值）
    end

    % 2. 训练约束函数的Kriging模型（仅第二阶段训练，第一阶段不考虑约束）
    if phase == 2
        for i = 1 : Len_con
            % 去重：删除决策变量完全相同的重复解
            [~,distinct1]  = unique(round(Dec*1e12)/1e12,'rows');
            % 去重：删除约束函数值完全相同的重复解
            [~,distinct2]  = unique(round(Con(:,i)*1e12)/1e12,'rows');
            distinct       = intersect(distinct1,distinct2);  % 同时唯一的索引
            % 训练约束函数的Kriging模型（参数设置与目标函数一致）
            dmodel         = dacefit(Dec(distinct,:),Con(distinct,i),'regpoly1','corrgauss',THETA_con(i,:),1e-5.*ones(1,Len_dec),100.*ones(1,Len_dec));
            Model_con{i}   = dmodel;  % 存储训练好的第i个约束的模型
            THETA_con(i,:) = dmodel.theta;  % 更新约束模型的超参数
        end
    else
        Model_con = [];  % 第一阶段：约束模型为空（不使用约束进行搜索）
    end
end