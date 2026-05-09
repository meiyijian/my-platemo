function [Population,FrontNo,CrowdDis] = EnvironmentalSelection(Population,N)
% EnvironmentalSelection：环境选择算子（基于NSGA-II）
% 使用非支配排序和拥挤距离选择下一代种群
%
% 输入参数：
%   Population - 当前种群（包含多个个体）
%   N          - 需要选择的个体数量
%
% 输出参数：
%   Population - 选择后的种群（大小为N）
%   FrontNo    - 每个个体的前沿编号
%   CrowdDis   - 每个个体的拥挤距离

    %% ==================== 步骤1：非支配排序 ====================
    % NDSort：非支配排序函数
    % 输入：Population.objs（目标值矩阵），N（参考数量）
    % 输出：FrontNo（前沿编号），MaxFNo（最大前沿编号）
    % 前沿编号越小，解的质量越高（1=第一前沿，最优）
    [FrontNo,MaxFNo] = NDSort(Population.objs,N);

    % Next：逻辑数组，标记哪些个体被选中
    % false(1,length(FrontNo))：初始化为全false
    Next = false(1,length(FrontNo));

    % 选择所有前沿编号小于MaxFNo的个体（即非支配解）
    Next(FrontNo<MaxFNo) = true;

    %% ==================== 步骤2：计算拥挤距离 ====================
    % CrowdingDistance：拥挤距离计算函数
    % 拥挤距离衡量解的密度，距离越大表示解越稀疏（更优）
    % 用于在同一前沿中选择更分散的解
    CrowdDis = CrowdingDistance(Population.objs,FrontNo);

    %% ==================== 步骤3：选择最后一个前沿的解 ====================
    % find(FrontNo==MaxFNo)：找到最后一个前沿的所有个体
    Last = find(FrontNo==MaxFNo);

    % sort(CrowdDis(Last),'descend')：按拥挤距离降序排序
    % ~：忽略排序后的值，Rank：排序后的索引
    [~,Rank] = sort(CrowdDis(Last),'descend');

    % 选择拥挤距离最大的个体，直到达到N个
    % N-sum(Next)：还需要选择的个体数量
    Next(Last(Rank(1:N-sum(Next)))) = true;

    %% ==================== 步骤4：返回选择后的种群 ====================
    % 逻辑索引：只保留被选中的个体
    FrontNo = FrontNo(Next);
    CrowdDis = CrowdDis(Next);
    Population = Population(Next);
end