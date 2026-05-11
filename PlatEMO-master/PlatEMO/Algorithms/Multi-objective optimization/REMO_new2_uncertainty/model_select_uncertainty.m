function [ind,scores,uncertainty] = model_select_uncertainty(Smodel,Next)
% model_select_uncertainty -- 不确定性感知的关系模型打分
% 融合 R2AEA 信息熵不确定性度量 + C2RL 置信度加权聚合
%
% 输出:
%   ind        - 按性能得分降序排列的索引
%   scores     - 每个候选解的性能得分
%   uncertainty - 每个候选解的归一化不确定性 [0,1]

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ========== 数据准备 ==========
    model_x = Smodel.X;
    C1_data = model_x(Smodel.Y == 1, :);
    C2_data = model_x(Smodel.Y ~= 1, :);

    C1_num   = size(C1_data, 1);
    C2_num   = size(C2_data, 1);
    Next_num = size(Next, 1);

    %% ========== 生成测试数据对 ==========
    all_testdata = zeros(2*(C1_num+C2_num)*Next_num, 2*size(C1_data,2));
    for i = 1:Next_num
        original = (i-1)*2*(C1_num+C2_num);
        Xi       = repmat(Next(i,:), C1_num, 1);
        all_testdata(original+1:original+C1_num,:)          = [C1_data, Xi];
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi, C1_data];

        Xi = repmat(Next(i,:), C2_num, 1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:)          = [C2_data, Xi];
        all_testdata(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2,:) = [Xi, C2_data];
    end

    %% ========== 模型预测 ==========
    TestIn_nor = mapminmax('apply', all_testdata', Smodel.mp_struct)';
    pre_out    = Smodel.net(TestIn_nor')';

    %% ========== 计算得分与不确定性 ==========
    scores      = zeros(Next_num, 1);
    entropy_all = zeros(Next_num, 1);

    for i = 1:Next_num
        C_SCORE  = zeros(1,2);  % [性能得分, 不确定性得分(熵)]
        original = (i-1)*2*(C1_num+C2_num);

        %% --- C1Xi: 好解在前, 候选在后 ---
        pre_raw  = pre_out(original+1:original+C1_num, :);
        w        = max(pre_raw, [], 2);                    % 每对置信度
        pre_C1Xi = sum(pre_raw .* w, 1) / (sum(w) + eps);  % 置信度加权平均
        % 性能: Xi 优于 C1 的证据
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);
        % 不确定性: 预测熵 (与好解比较, 熵越高越不利)
        C_SCORE(2) = C_SCORE(2) - sum(pre_C1Xi .* log2(pre_C1Xi + eps));

        %% --- XiC1: 候选在前, 好解在后 ---
        pre_raw  = pre_out(original+1+C1_num:original+C1_num*2, :);
        w        = max(pre_raw, [], 2);
        pre_XiC1 = sum(pre_raw .* w, 1) / (sum(w) + eps);
        C_SCORE(1) = C_SCORE(1) + pre_XiC1(1) + pre_XiC1(2);
        C_SCORE(2) = C_SCORE(2) - sum(pre_XiC1 .* log2(pre_XiC1 + eps));

        %% --- C2Xi: 差解在前, 候选在后 ---
        pre_raw  = pre_out(original+1+C1_num*2:original+C1_num*2+C2_num, :);
        w        = max(pre_raw, [], 2);
        pre_C2Xi = sum(pre_raw .* w, 1) / (sum(w) + eps);
        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + sum(pre_C2Xi .* log2(pre_C2Xi + eps));

        %% --- XiC2: 候选在前, 差解在后 ---
        pre_raw  = pre_out(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2, :);
        w        = max(pre_raw, [], 2);
        pre_XiC2 = sum(pre_raw .* w, 1) / (sum(w) + eps);
        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + sum(pre_XiC2 .* log2(pre_XiC2 + eps));

        scores(i)      = C_SCORE(1);
        entropy_all(i) = C_SCORE(2);
    end

    %% ========== 归一化不确定性到 [0,1] ==========
    e_min = min(entropy_all);
    e_max = max(entropy_all);
    if e_max - e_min > eps
        uncertainty = (entropy_all - e_min) / (e_max - e_min);
    else
        uncertainty = zeros(size(entropy_all));
    end

    [~,ind] = sort(scores, 'descend');
end
