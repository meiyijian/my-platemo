classdef SVM
% MCEA/D 中的 SVM（支持向量机）分类器定义
%
% ==== 核心角色 ====
% 每个子问题拥有一个专属的 SVM，它的任务是：
% 给定一个候选解 x，预测它是否比当前"邻居最优解"更好。
%   → 预测为 +1（正类）：该解有望改善当前子问题的求解质量 → 送去真实评估
%   → 预测为 -1（负类）：该解可能不如当前最优 → 丢弃或标记为备用
%
% ==== 为什么用 SVM？ ====
% 1. SVM 在小样本下泛化能力好（昂贵优化场景中，已评估的解很少）
% 2. 使用 RBF（径向基函数）核能够学习非线性分类边界
% 3. 训练和预测的计算开销远小于真实目标函数评估
%
% ==== 属性说明 ====
% Problem : 问题实例（含维度 D、变量上下界等）
% index   : 子问题编号（1 到 N）
% x       : SVM 训练输入（自变量，即已评估解的决策向量）
% label   : SVM 训练标签（因变量，+1=正类/好解, -1=负类/差解）
% mdl     : 训练好的 MATLAB SVM 模型对象
% C       : SVM 正则化参数（控制对误分类的惩罚力度，C=1.0）
% gamma   : RBF 核参数（gamma=1.0，控制核函数的宽度）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Masaya Nakata

    properties
        Problem        % 问题实例
        index          % 子问题编号
        x              % 训练输入矩阵（每行是一个已评估解的决策向量）
        label          % 训练标签向量（+1 或 -1）
        mdl            % 训练好的 SVM 模型
        C              % SVM 正则化参数 C（默认 1.0）
        gamma          % RBF 核参数 γ（默认 1.0，控制高斯核宽度）
    end

    methods
        %% ===== 构造函数：初始化 N 个 SVM 对象 =====
        function obj = SVM(Problem)
            % nargin 是 "Number of ARGuments IN" 的缩写
            % nargin == 1 表示调用时传入了 1 个参数（即 Problem）
            if nargin == 1
                % 创建 1 行 × Problem.N 列的 SVM 对象数组
                % 每个子问题对应一个独立的 SVM
                obj(1, Problem.N) = SVM;
                for i = 1 : length(obj)
                    obj(i).index   = i;          % 子问题编号
                    obj(i).Problem = Problem;     % 绑定问题实例
                    obj(i).C       = 1.0;         % SVM 参数 C
                    obj(i).gamma   = 1.0;         % RBF 核参数 γ
                    obj(i).x       = [];          % 训练输入初始为空
                    obj(i).label   = [];          % 训练标签初始为空
                    obj(i).mdl;                   % 模型初始为空（尚未训练）
                end
            end
        end

        %% ===== 模型构建：为子问题 i 训练 SVM =====
        function obj = ModelConstruction(obj, A, B_i, W, Z)
            % ==== 输入参数 ====
            % obj : 当前 SVM 对象（子问题 i 专属）
            % A   : 存档（所有已评估的解，结构体数组）
            % B_i : 子问题 i 的邻居索引列表（T 个邻居）
            % W   : 权重向量矩阵（N 行 × M 列）
            % Z   : 理想点（1 行 × M 列，每个目标的最小值）

            % ----- 步骤1：准备训练数据（所有存档解初始标记为 -1）-----
            indices = [1 : length(A)];            % 存档中所有解的索引
            for i = 1 : length(A)
                obj.x(i, :)     = A(i).dec;       % 输入：解的决策向量
                obj.label(i, 1) = -1;              % 默认标签全为负类（差解）
            end

            % ----- 步骤2：找出邻居中的最优解，标记为正类 -----
            % 核心思想：对每个邻居子问题，用切比雪夫标量函数找到其最优解
            % 这些最优解就是"正样本"——它们代表了"什么是一个好解"
            C_i = [];  % 已选为正类解的索引集合
            for i = 1 : length(B_i)
                % 计算所有存档解相对于邻居权重向量 w_Bi 的切比雪夫标量值
                % g(x|w,Z) = max_{j=1..M} { |f_j(x) - Z_j| * w_j }
                % 注意：|...| 是 abs(), .* 是按元素乘, max(..., [], 2) 是沿第2维（列）取最大
                g_data = max(abs(A(indices).objs - repmat(Z, length(indices), 1)) .* W(B_i(i), :), [], 2);

                % 按 g 值从小到大排序（g 值越小，解越接近理想方向）
                [~, sorted_index] = sort(g_data);
                % 选择该邻居子问题的最优解（排除已选过的，避免重复）
                for j = 1 : length(sorted_index)
                    if ~ismember(sorted_index(j), C_i)  % ismember 检查是否已在集合中
                        C_i = [C_i, sorted_index(j)];    % 加入已选集合
                        obj.label(sorted_index(j), 1) = 1;  % 标记为正类！
                        break  % 每个邻居只选一个最优解
                    end
                end
            end

            % ----- 步骤3：训练 SVM -----
            % 对输入数据做归一化：将每个决策变量缩放到 [0, 1] 区间
            uniformed_xdata = zeros(length(obj.label), obj.Problem.D);
            for i = 1 : length(obj.label)
                uniformed_xdata(i, :) = obj.UniformInput(obj.x(i, :));
            end
            % RBF 核的 sigma 参数计算（控制高斯核的宽度）
            sigma   = sqrt(1 / (2 * obj.gamma));
            % 调用 MATLAB 内置函数训练 SVM
            % fitcsvm → "FIT a C-Support Vector Machine"
            % BoxConstraint：控制对误分类样本的惩罚（越大越不允误分类，可能过拟合）
            % KernelScale：RBF 核的尺度参数 sigma
            % KernelFunction：选择径向基（高斯）核函数
            obj.mdl = fitcsvm(uniformed_xdata, obj.label, ...
                'BoxConstraint', obj.C, ...
                'KernelScale', sigma, ...
                'KernelFunction', 'rbf');
            % 此时 obj.mdl 包含了训练完成的 SVM 模型
        end

        %% ===== 预测：判断候选解是否为好解 =====
        function [predicted_class, score] = PredictClass(obj, x)
            % ==== 输入 ====
            % x : 一个候选解的决策向量（1 行 × D 列）
            %
            % ==== 输出 ====
            % predicted_class : SVM 预测的类别（1=正类/好解, -1=负类/差解）
            % score           : 决策函数值（即该解到 SVM 超平面的有符号距离）
            %                    数值越大，越确信它是正类

            % 先对输入做归一化（和训练时保持一致）
            uniformed_x = obj.UniformInput(x);

            % 用训练好的 SVM 模型进行预测
            % predict：MATLAB 分类模型的内置方法
            % score_list 返回两列：[负类分数, 正类分数]
            [predicted_class, score_list] = obj.mdl.predict(uniformed_x);

            % 返回正类的决策函数分数（第2列）
            score = score_list(2);
        end

        %% ===== 归一化：将决策变量缩放到 [0, 1] =====
        function uniformed_x = UniformInput(obj, x)
            % 将每个决策变量 x(j) 从其实际范围 [lower(j), upper(j)] 线性映射到 [0, 1]
            % 归一化公式：x_normalized = (x - x_min) / (x_max - x_min)
            %
            % 为什么要归一化？
            % SVM 的 RBF 核对特征的尺度敏感。如果不同决策变量的取值范围
            % 差异很大（例如 x1∈[-10,10], x2∈[-0.01, 0.01]），不归一化会导致
            % 距离计算被大尺度变量主导，SVM 无法正确学习。

            uniformed_x = ones(1, obj.Problem.D);     % 初始化为全 1 向量
            for i = 1 : obj.Problem.D
                x_min = obj.Problem.lower(i);         % 第 i 个决策变量的下界
                x_max = obj.Problem.upper(i);         % 第 i 个决策变量的上界
                uniformed_x(i) = (x(i) - x_min) / (x_max - x_min);  % Min-Max 归一化
            end
        end

    end
end