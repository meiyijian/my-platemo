function Offspring = OperatorDE_current_rand_1(Problem,Parent)
% DE/current-to-rand/1：差分进化算法的一种变体，结合当前解和随机解的信息生成新解
% 输入：
%   Problem - 优化问题对象
%   Parent  - 父代种群
% 输出：
%   Offspring - 生成的后代种群

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: z.zhang0@csu.edu.cn)

    %% 参数设置
    [N,D] = size(Parent); % N：种群规模，D：决策变量维度
    Fm    = [0.6,0.8,1.0]; % 缩放因子候选集合
    CRm   = [0.1,0.2,1.0]; % 交叉概率候选集合
    
    % 为每个个体随机选择缩放因子
    index = randi([1,length(Fm)],N,1);
    F     = Fm(index);
    F     = F';
    F     = F(:, ones(1,D)); % 扩展为矩阵形式，便于元素级运算
    
    % 为每个个体随机选择交叉概率
    index = randi([1,length(CRm)],N,1);
    CR    = CRm(index);
    CR    = CR';
    
    %% 差分进化操作
    Site            = rand(N,D) < CR; % 确定交叉位置，每个变量独立决定是否交叉
    Parent1         = Parent(randperm(N),:); % 随机选择个体1
    Parent2         = Parent(randperm(N),:); % 随机选择个体2
    Parent3         = Parent(randperm(N),:); % 随机选择个体3
    Offspring       = Parent; % 初始化后代为父代
    % DE/current-to-rand/1公式：x_i(t+1) = x_i(t) + F*(x_p1(t)-x_i(t)) + F*(x_p2(t)-x_p3(t))
    % 结合当前解和两个随机差分向量
    Offspring(Site) = Parent(Site) + F(Site).*(Parent1(Site)-Parent(Site)) + F(Site).*(Parent2(Site)-Parent3(Site));

    %% 多项式变异
    proM  = 1; % 总变异概率
    disM  = 20; % 变异分布指数，控制变异步长分布，值越大变异步长越集中
    Lower = repmat(Problem.lower,N,1); % 决策变量下界矩阵
    Upper = repmat(Problem.upper,N,1); % 决策变量上界矩阵
    Site  = rand(N,D) < proM/D; % 确定变异位置，每个变量的变异概率为proM/D
    mu    = rand(N,D); % 生成[0,1]之间的随机数矩阵
    
    % 第一类变异位置处理（mu <= 0.5）
    temp  = Site & mu<=0.5;
    Offspring       = min(max(Offspring,Lower),Upper); % 边界处理，确保解在可行域内
    Offspring(temp) = Offspring(temp)+(Upper(temp)-Lower(temp)).*...
                      ((2.*mu(temp)+(1-2.*mu(temp)).*...
                      (1-(Offspring(temp)-Lower(temp))./(Upper(temp)-Lower(temp))).^(disM+1)).^(1/(disM+1))-1);
    
    % 第二类变异位置处理（mu > 0.5）
    temp = Site & mu>0.5; 
    Offspring(temp) = Offspring(temp)+(Upper(temp)-Lower(temp)).*...
                      (1-(2.*(1-mu(temp))+2.*(mu(temp)-0.5).*...
                      (1-(Upper(temp)-Offspring(temp))./(Upper(temp)-Lower(temp))).^(disM+1)).^(1/(disM+1)));
end