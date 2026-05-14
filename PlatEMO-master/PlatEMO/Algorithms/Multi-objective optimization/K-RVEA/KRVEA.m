classdef KRVEA < ALGORITHM
% <2018> <multi/many> <real/integer> <expensive>
% Surrogate-assisted RVEA
% alpha ---  2 --- The parameter controlling the rate of change of penalty
% wmax  --- 20 --- Number of generations before updating Kriging models
% mu    ---  5 --- Number of re-evaluated solutions at each generation

%------------------------------- Reference --------------------------------
% T. Chugh, Y. Jin, K. Miettinen, J. Hakanen, and K. Sindhya. A surrogate-
% assisted reference vector guided evolutionary algorithm for
% computationally expensive many-objective optimization. IEEE Transactions
% on Evolutionary Computation, 2018, 22(1): 129-142.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He
% 中文注释作者：李盛薪 (2026-05-14)，面向"看不懂 MATLAB 语法"的研究生

% =========================================================================
% 【一句话定位】
%   K-RVEA = Kriging 代理 + RVEA 进化框架 + 自适应模型管理。
%   是"昂贵超多目标"方向 2018 年的标杆论文 (IEEE TEVC)，你的 baseline 对照算法。
%
% 【核心思想三句话】
%   1) 真实评价太贵 → 用 Kriging（高斯过程）当代理；
%   2) 内部用 RVEA 跑 wmax 代（仅靠代理评估），不消耗真实预算；
%   3) 每代只挑 mu 个候选送真实评价，挑选时根据"不活跃参考向量数量"
%      在「偏收敛 (APD 最小)」与「偏多样性 (不确定度 MSE 最大)」之间切换。
%
% 【与 REMO 的本质区别】
%   - 代理：K-RVEA 用 Kriging 回归 (输出均值+方差)，REMO 用 FNN 学关系；
%   - 选择：K-RVEA 用 APD (角度惩罚距离)，REMO 用关系投票；
%   - 不确定性：K-RVEA 天然有 σ，REMO 没有 (这就是你的痛点 P0-13)。
% =========================================================================

    methods
        % MATLAB 类语法：所有算法都继承自 ALGORITHM 基类，必须实现 main 方法。
        % Algorithm —— 算法对象本身（用于读参数、判断是否终止）
        % Problem   —— 问题对象（含决策维 D、目标维 M、上下界、Evaluation 接口）
        function main(Algorithm,Problem)
            %% Parameter setting
            % ----- 1. 读取算法的 3 个超参 -----
            % alpha：控制 APD 中惩罚项随代数 t 的变化速率（默认 2）。
            %        前期 (t 小) 惩罚弱，鼓励探索；后期 (t 大) 惩罚强，强制贴参考向量收敛。
            % wmax ：内部用代理跑多少代后再更新 Kriging（默认 20）。越大代理利用越充分但越易"信代理过头"。
            % mu   ：每外层迭代，挑多少个候选送真实评价（默认 5），即每轮花掉的 FE 预算。
            [alpha,wmax,mu] = Algorithm.ParameterSet(2,20,5);

            %% Generate the reference points and population
            % ----- 2. 生成 RVEA 的均匀参考向量 V0 -----
            % UniformPoint(N,M)：在 M 维单纯形上生成约 N 个均匀点，作为参考向量方向。
            % 注意：实际生成数会重写 Problem.N (Das-Dennis 公式决定，可能略小于 N)。
            [V0,Problem.N] = UniformPoint(Problem.N,Problem.M);
            V     = V0;                       % V 是当前自适应后的参考向量；V0 永远保留原始版作为基准
            % ----- 3. 初始训练样本：拉丁超立方采样 NI = 11D-1 个点 -----
            % 这是 SAEA 经典初始预算，给 Kriging 足够样本起步。
            NI    = 11*Problem.D-1;
            P     = UniformPoint(NI,Problem.D,'Latin');                             % NI×D 的 [0,1] LHS 设计阵
            % 把 [0,1] 缩放到 [lower, upper]：repmat 是为了把行向量扩成 NI 行，可以写成 P.*(upper-lower)+lower
            A2    = Problem.Evaluation(repmat(Problem.upper-Problem.lower,NI,1).*P+repmat(Problem.lower,NI,1));
            % A1 = 用于训练 Kriging 的档案；A2 = 全部真实评价过的解（外部输出）。初始两者相同。
            A1    = A2;
            % THETA：每个目标 × 每个变量一个 Kriging 核宽度参数，初值 5。每代会被 dacefit 更新（warm start）。
            THETA = 5.*ones(Problem.M,Problem.D);
            % Model：M 个 Kriging 模型，每个目标一个，cell 数组存放。
            Model = cell(1,Problem.M);

            %% Optimization
            % NotTerminated：PlatEMO 标准接口，没耗完 maxFE 就返回 true。
            % 同时它会把 A2 当作"当前外部种群"用来记录指标（IGD/HV）。
            while Algorithm.NotTerminated(A2)
                % ---------- 阶段 A：用最新档案 A1 重新训练 M 个 Kriging ----------
                A1Dec = A1.decs;              % 解的决策变量矩阵 (NI × D)，.decs 是 SOLUTION 类的方法
                A1Obj = A1.objs;              % 解的目标值矩阵 (NI × M)
                for i = 1 : Problem.M
                    % The parameter 'regpoly1' refers to one-order polynomial
                    % function, and 'regpoly0' refers to constant function. The
                    % former function has better fitting performance but lower
                    % efficiency than the latter one
                    %
                    % dacefit 是 DACE 工具箱的 Kriging 训练函数，参数：
                    %   A1Dec, A1Obj(:,i)   —— 训练输入 X、训练输出 y（第 i 个目标的所有值）
                    %   'regpoly1'          —— 趋势项用一阶多项式（拟合更好但慢；'regpoly0' 更快）
                    %   'corrgauss'         —— 相关函数用高斯核（标准 Kriging）
                    %   THETA(i,:)          —— 核宽度初值（warm start，从上轮继承）
                    %   1e-5*ones, 100*ones —— 核宽度优化的下界 / 上界
                    dmodel     = dacefit(A1Dec,A1Obj(:,i),'regpoly1','corrgauss',THETA(i,:),1e-5.*ones(1,Problem.D),100.*ones(1,Problem.D));
                    Model{i}   = dmodel;      % 保存模型
                    THETA(i,:) = dmodel.theta;% 更新 THETA 给下一代复用
                end

                % ---------- 阶段 B：内部 RVEA 跑 wmax 代，只用代理评估，不花真实 FE ----------
                PopDec = A1Dec;               % 内部种群的决策变量初值 = 当前档案
                w      = 1;                   % 内部代数计数
                while w <= wmax
                    drawnow('limitrate');     % 让 PlatEMO GUI 有机会刷新（不影响算法逻辑）
                    % B1) GA 算子（SBX 交叉 + 多项式变异）产生 NI 个子代
                    OffDec = OperatorGA(Problem,PopDec);
                    PopDec = [PopDec;OffDec]; % 父+子合并 (μ+λ 风格)
                    [N,~]  = size(PopDec);
                    PopObj = zeros(N,Problem.M);  % 预测均值矩阵
                    MSE    = zeros(N,Problem.M);  % 预测方差矩阵 (不确定度，关键！)
                    % B2) 用 M 个 Kriging 对每个新解的每个目标做预测
                    for i = 1: N
                        for j = 1 : Problem.M
                            % predictor 返回：[均值, 梯度, MSE]
                            % 这里第 2 个输出 (梯度) 不要 → 用 ~ 占位
                            [PopObj(i,j),~,MSE(i,j)] = predictor(PopDec(i,:),Model{j});
                        end
                    end
                    % B3) RVEA 环境选择 (按参考向量 + APD)
                    % 第三个参数 (w/wmax)^alpha 就是 APD 公式里随时间增长的惩罚因子
                    index  = KEnvironmentalSelection(PopObj,V,(w/wmax)^alpha);
                    PopDec = PopDec(index,:);
                    PopObj = PopObj(index,:);
                    % B4) 自适应参考向量 (RVEA 的另一个特色)
                    % 每隔 wmax/10 代，把 V 按当前种群的目标范围缩放，使其贴合实际 PF 形状
                    % ~mod(w, k) 等价于 mod(w,k)==0
                    if ~mod(w,ceil(wmax*0.1))
                        V(1:Problem.N,:) = V0.*repmat(max(PopObj,[],1)-min(PopObj,[],1),size(V0,1),1);
                    end
                    w = w + 1;
                end

                % ---------- 阶段 C：从内部种群挑 mu 个候选送真实评价 ----------
                % NoActive：统计上一轮 A1 在原始 V0 下"没人关联"的参考向量数 NumVf
                % 这是 K-RVEA 模型管理的关键信号：
                %   不活跃参考向量在变多 → 多样性变差 → 应该优先填这些方向 (走收敛 APD 策略)
                %   不活跃在变少     → 多样性已经够 → 应该探索高 MSE 的解 (走不确定度策略)
                [NumVf,~] = NoActive(A1Obj,V0);
                % 0.05*Problem.N 是切换阈值 delta：当 |不活跃数变化| > delta 时走"走不确定度"，否则走"APD 收敛"
                PopNew    = KrigingSelect(PopDec,PopObj,MSE(index,:),V,V0,NumVf,0.05*Problem.N,mu,(w/wmax)^alpha);
                % 真正消耗 FE 的地方：mu 个解送真实仿真
                New       = Problem.Evaluation(PopNew);
                % A2 单调累积所有真实评价过的解（用于评估指标）
                A2        = [A2,New];
                % A1 用于训练 Kriging：保留 NI 个解 + 新评价的 mu 个，按多样性裁剪老解
                A1        = UpdataArchive(A1,New,V,mu,NI);
            end
        end
    end
end
