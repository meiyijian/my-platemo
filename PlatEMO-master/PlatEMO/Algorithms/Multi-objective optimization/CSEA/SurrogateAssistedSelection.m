function Next = SurrogateAssistedSelection(Problem,net,p0,p1,Ref,Input,wmax,tr)
% SurrogateAssistedSelection - 基于代理模型选择有希望的解决方案
% 输入参数：
%   Problem: 优化问题对象
%   net: 训练好的神经网络代理模型
%   p0: 正样本的平均预测误差
%   p1: 负样本的平均预测误差
%   Ref: 参考解集合
%   Input: 当前种群的决策变量
%   wmax: 代理模型评估的最大解数量
%   tr: 阈值调整参数
% 输出参数：
%   Next: 选择的有希望的解决方案

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Cheng He

    % 使用遗传算法操作生成新的候选解
    % 参数说明：
    %   [Input;Ref.decs]: 父代种群，包括当前种群和参考解
    %   {1,15,1,5}: GA参数，分别表示选择概率、交叉概率、变异概率和变异步长
    Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    
    % 使用训练好的神经网络预测候选解的标签
    Label = predict(net,Next);
    
    % 设置阈值参数
    a     = tr;      % 负样本预测阈值
    b     = 1 - tr;  % 正样本预测阈值
    
    % 初始化计数器
    i     = 0;
    
    % 根据预测误差选择不同的搜索策略
    % 情况1：正样本预测误差小 或 (负样本预测误差小且正样本预测误差适中)
    % 这种情况下，算法倾向于寻找正样本（好解）
    if p0<0.4 || (p1<a&&p0<b)
        % 在代理模型评估的解数量不超过wmax的情况下进行迭代搜索
        while i < wmax
            % 按预测标签降序排序，选择预测最好的解
            [~,index] = sort(Label,'descend');
            % 选择前length(Ref)个解作为下一代的输入
            Input     = Next(index(1:length(Ref)),:);
            % 使用GA生成新的候选解
            Next      = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
            % 更新预测标签
            Label = predict(net,Next);
            % 更新计数器
            i = i+size(Next,1);
        end
        % 只保留预测标签大于0.9的解
        Next = Next(Label>0.9,:);
    
    % 情况2：正样本预测误差大且负样本预测误差小
    % 这种情况可能导致循环，因此随机选择一个解
    elseif p0>b && p1<a
        randindex = randperm(length(Next));
        Next = Next(randindex(1),:);
    
    % 情况3：负样本预测误差大
    % 这种情况下，算法倾向于避免负样本（差解），相当于寻找正样本
    elseif p1 > b
        % 在代理模型评估的解数量不超过wmax的情况下进行迭代搜索
        while i<wmax
            % 按预测标签升序排序，选择预测最差的解（将其排除）
            [~,index] = sort(Label);
            % 选择前length(Ref)个解作为下一代的输入
            Input     = Next(index(1:length(Ref)),:);
            % 使用GA生成新的候选解
            Next      = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
            % 更新预测标签
            Label = predict(net,Next);
            % 更新计数器
            i = i+size(Next,1);
        end
        % 只保留预测标签小于0.1的解
        Next = Next(Label<0.1,:);
    
    % 其他情况：随机选择一个解
    else
        Next = Next(randi(end),:);
    end
end