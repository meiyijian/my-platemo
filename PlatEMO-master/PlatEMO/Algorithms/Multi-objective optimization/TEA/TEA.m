classdef TEA < ALGORITHM
% <2024> <multi/many> <real/integer> <expensive> <constrained/none>
% TEA (Two-phase Evolutionary Algorithm) - 两阶段进化算法
% 该算法专为昂贵多目标约束优化问题设计，通过两阶段策略和克里金代理模型提高优化效率
%
% 参数说明:
% wmax --- 20 --- 进化搜索的最大代数（每阶段的进化迭代次数）
% mu   ---  5 --- 每代选择的新候选解数量（用于真实函数评估）
%
% 算法特点:
% 1. 两阶段优化策略：阶段1快速探索，阶段2精确优化
% 2. DACE克里金代理模型集成，显著减少昂贵函数评估
% 3. 智能候选解选择，最大化信息增益
% 4. 约束处理机制，适应约束优化问题
%    
%------------------------------- Reference --------------------------------
% Z. Zhang, Y. Wang, J. Liu, G. Sun, and K. Tang. A two-phase Kriging-
% assisted evolutionary algorithm for expensive constrained multiobjective
% optimization problems. IEEE Transactions on Systems, Man, and
% Cybernetics: Systems, 2024, 54(8): 4579-4591.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: zhiyao_zhang0@163.com)
    
    methods
        function main(Algorithm,Problem)
            %% =================== 参数设置模块 ===================
            % 定义全局变量，用于在不同函数间共享算法状态信息
            global phase NI Len_con Len_obj 
            
            % 从算法参数中获取进化搜索最大代数和每代选择候选解数量
            % wmax: 每阶段的进化迭代次数，默认为20
            % mu: 每代选择的新候选解数量，默认为5
            [wmax,mu]      = Algorithm.ParameterSet(20,5,2);
            
            % ct: 相变计数器，记录阶段转换次数
            ct             = 0;
            % ct_max: 最大相变次数，限制阶段转换的频率
            ct_max         = 2;
            
            % sample_success: 采样成功标志，指示是否需要重新训练代理模型
            % 当为1时表示新采样成功，需要更新代理模型；为0时表示无新采样
            sample_success = 1;
            % phase: 当前算法阶段，1表示探索阶段，2表示精化阶段
            phase          = 1;

            %% =================== 初始化模块 ===================
            % NI: 获取问题规模（种群大小）
            NI        = Problem.N;
            
            % 使用均匀拉丁超立方采样生成初始种群
            % UniformPoint生成在单位超立方体中均匀分布的NI个点
            P         = UniformPoint(NI,Problem.D,'Latin');
            
            % Database: 数据库结构体，存储评估过的解集及其目标函数值和约束值
            % 将标准化坐标转换为原始决策空间坐标并评估
            % repmat创建重复矩阵，Problem.upper-Problem.lower得到搜索空间大小
            % 乘以P再加上Problem.lower得到实际坐标值
            Database  = Problem.Evaluation(repmat(Problem.upper-Problem.lower,NI,1).*P+repmat(Problem.lower,NI,1));
            
            % P: 当前种群，用评估结果更新
            P         = Database;
            
            % Len_obj: 目标函数数量
            Len_obj   = Problem.M;
            
            % THETA_obj: 目标函数DACE模型的超参数矩阵
            % 初始化为5倍单位矩阵，每行对应一个目标函数
            THETA_obj = 5.*ones(Len_obj,Problem.D);
            
            % Model_obj: 目标函数DACE模型数组，每个元素对应一个目标函数的代理模型
            Model_obj = cell(1,Len_obj); 
            
            % Len_con: 约束条件数量（如果无约束则为0）
            Len_con   = size(Database.cons,2);
            
            % THETA_con: 约束条件DACE模型的超参数矩阵
            THETA_con = 5.*ones(Len_con,Problem.D);
            
            % Model_con: 约束条件DACE模型数组
            Model_con = cell(1,Len_con);

            %% =================== 主优化循环模块 ===================
            % 算法主循环：持续优化直到满足终止条件
            while Algorithm.NotTerminated(Database)
                
                %% ============== 代理模型构建模块 ==============
                % 如果采样成功（新的真实评估完成），则重新训练代理模型
                if sample_success
                    % 调用model_train函数训练所有目标函数和约束的DACE模型
                    [Model_obj,Model_con,THETA_obj,THETA_con] = model_train(Database,THETA_obj,THETA_con);
                end
                
                %% ============== 进化搜索模块 ==============
                % 执行进化搜索，基于代理模型生成新解
                % PopDec: 新生成的解的决策变量
                % PopObj: 新解的目标函数预测值
                % PopCon: 新解的约束条件预测值
                % ObjMSE: 目标函数预测的均方误差
                % ConMSE: 约束条件预测的均方误差
                [PopDec,PopObj,PopCon,ObjMSE,ConMSE] = Evo_Search(P,wmax,Model_obj,Model_con,Problem);
                
                %% ============== 候选解选择模块 ==============
                % 从进化搜索结果中智能选择最有价值的候选解
                % C: 选择的候选解集，用于真实函数评估
                C = Candi_Select(PopDec,PopObj,PopCon,ObjMSE,ConMSE,Database,mu);
                
                %% ============== 相变控制模块 ==============
                % 准备重置采样成功标志
                sample_success = 0;
                
                % 如果有候选解被选择，则进行真实函数评估
                if isempty(C) == 0
                    % 对候选解进行真实函数评估
                    C = Problem.Evaluation(C);
                    % 标记采样成功，准备更新代理模型
                    sample_success = 1;
                    
                    % 检查是否需要阶段转换
                    % Database: 当前数据库，C: 新评估的候选解
                    % ct: 当前相变次数，ct_max: 最大相变次数，phase: 当前阶段
                    [phase,ct]     = Phase_Trans(Database,C,ct,ct_max,phase);
                end
                
                %% ============== 种群重选模块 ==============
                % 将新评估的候选解加入数据库
                Database = [Database,C];
                
                % 从扩展的数据库中选择最优的NI个解作为新种群
                % index: 被选中解的索引
                index    = Pop_Reselect(Database.objs,Database.cons,NI);
                % P: 更新后的种群
                P        = Database(index);
            end
        end
    end
end

%% =================== 代理模型训练模块 ===================
function [Model_obj,Model_con,THETA_obj,THETA_con] = model_train(Database,THETA_obj,THETA_con)
    % 全局变量声明，用于访问主函数中的参数
    global Len_con Len_obj phase 
    
    % 提取数据库中的决策变量
    Dec     = Database.decs;
    % 提取数据库中的目标函数值
    Obj     = Database.objs;
    % 提取数据库中的约束条件值
    Con     = Database.cons;
    
    % Len_dec: 决策变量维度
    Len_dec = size(Dec,2);
    % Len_obj: 目标函数数量
    Len_obj = size(Obj,2);
    % Len_con: 约束条件数量
    Len_con = size(Con,2);
    
    %% ============== 目标函数DACE模型训练 ==============
    % 遍历每个目标函数，为其训练独立的DACE模型
    for i = 1 : Len_obj
        % 找出决策变量和第i个目标函数的唯一有效数据点
        % 避免重复或数值精度问题导致的无效数据
        [~,distinct1]  = unique(round(Dec*1e12)/1e12,'rows');
        [~,distinct2]  = unique(round(Obj(:,i)*1e12)/1e12,'rows');
        % 取交集确保数据点同时在决策空间和目标空间唯一
        distinct       = intersect(distinct1,distinct2);
        
        % 使用DACE方法拟合克里金模型
        % 'regpoly1': 使用一阶多项式作为回归函数
        % 'corrgauss': 使用高斯相关函数
        % THETA_obj(i,:): 第i个目标函数的初始超参数
        % 1e-5.*ones(1,Len_dec): 参数下界，防止过拟合
        % 100.*ones(1,Len_dec): 参数上界，保证模型灵活性
        dmodel         = dacefit(Dec(distinct,:),Obj(distinct,i),'regpoly1','corrgauss',THETA_obj(i,:),1e-5.*ones(1,Len_dec),100.*ones(1,Len_dec));
        
        % 存储训练好的模型
        Model_obj{i}   = dmodel;
        % 更新超参数，为下次训练提供更好的初始值
        THETA_obj(i,:) = dmodel.theta;
    end
    
    %% ============== 约束条件DACE模型训练 ==============
    % 仅在算法第二阶段训练约束模型（阶段1主要关注目标函数优化）
    if phase == 2
        % 遍历每个约束条件，为其训练独立的DACE模型
        for i = 1 : Len_con
            % 找出决策变量和第i个约束条件的唯一有效数据点
            [~,distinct1]  = unique(round(Dec*1e12)/1e12,'rows');
            [~,distinct2]  = unique(round(Con(:,i)*1e12)/1e12,'rows');
            distinct       = intersect(distinct1,distinct2);
            
            % 使用DACE方法拟合约束条件的克里金模型
            dmodel         = dacefit(Dec(distinct,:),Con(:,i),'regpoly1','corrgauss',THETA_con(i,:),1e-5.*ones(1,Len_dec),100.*ones(1,Len_dec));
            % 存储训练好的约束模型
            Model_con{i}   = dmodel;
            % 更新约束模型超参数
            THETA_con(i,:) = dmodel.theta;
        end
    else
        % 阶段1不训练约束模型，设置为空
        Model_con = [];
    end
end