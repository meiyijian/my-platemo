function Next = RSurrogateAssistedSelection(Problem,Ref,Input,wmax,Smodel)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes.
%--------------------------------------------------------------------------

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;
    while i < wmax
        [sorted_index,~]= model_select(Smodel,Next);
        % 防止索引越界
        num_to_select = min(length(Ref), length(sorted_index));
        Input = Next(sorted_index(1:num_to_select),:);
        
        Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i     = i + size(Next,1);
    end
    
    % 最后一次筛选
    [~,final_scores] = model_select(Smodel,Next);
    
    [~,ind] = sort(final_scores,'descend');
    
    % --- 阈值筛选逻辑 ---
    % 因为用了乘法校准，分数的绝对值范围变了，不再是固定的4.0
    % 最稳妥的方式是：优先选最好的N个，如果最好的不够，就降低标准
    
    target_num = Problem.N; % 或者是你想选出的数量
    if size(Next, 1) > 4
         % 直接选得分最高的 4 个（或者 Problem.N 个，根据原算法逻辑通常是少量）
         % 原算法这里写死了 < 4，我们保持稳健
         Next = Next(ind(1:min(4, length(ind))), :); 
    else
         Next = Next; % 都不够4个，全选
    end
end

function [ind,final_scores] = model_select(Smodel,Next)
    model_x = Smodel.X;    
    C1_data = model_x(Smodel.Y ==1,:);
    C2_data = model_x(Smodel.Y ~=1,:); 

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);

    % --- 1. 神经网络预测 (NN Prediction) ---
    all_testdata = zeros(2*(C1_num+C2_num)*Next_num,2*size(C1_data,2));
    for i = 1 : size(Next,1)
        original = (i-1)*2*(C1_num+C2_num);
        Xi       = repmat(Next(i,:),size(C1_data,1),1);
        all_testdata(original+1:original+C1_num,:)          = [C1_data,Xi];  
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi,C1_data]; 
        
        Xi = repmat(Next(i,:),size(C2_data,1),1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:)          = [C2_data,Xi]; 
        all_testdata(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2,:) = [Xi,C2_data];
    end
    
    TestIn_nor = mapminmax('apply',all_testdata',Smodel.mp_struct)';
    pre_out = Smodel.net(TestIn_nor')';  
    
    nn_scores = zeros(Next_num,1);
    for i = 1 : size(Next,1)
        C_SCORE    = zeros(1,2);
        original   = (i-1)*2*(C1_num+C2_num);
        
        pre_C1Xi   = sum(pre_out(original+1:original+C1_num,:),1)./C1_num;
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2)+pre_C1Xi(3);   
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);               
        
        pre_XiC1   = sum(pre_out(original+1+C1_num:original+C1_num*2,:),1)./C1_num;
        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);  
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);                 
        
        pre_C2Xi   = sum(pre_out(original+1+C1_num*2:original+C1_num*2+C2_num,:),1)./C2_num;
        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);
        
        pre_XiC2   = sum(pre_out(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2,:) ,1)./C2_num;
        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);
        
        nn_scores(i) = C_SCORE(1)-C_SCORE(2);
    end  
    
    % --- 2. 分布概率计算 (Distribution Calculation) ---
    dist_scores = calculate_distribution_score(Next, Smodel.mu, Smodel.K);
    
    % --- 3. 归一化与融合 (Normalization & Fusion) ---
    
    % 3.1 归一化分布得分到 [0, 1]
    d_min = min(dist_scores);
    d_max = max(dist_scores);
    if d_max - d_min > 1e-10
        dist_norm = (dist_scores - d_min) ./ (d_max - d_min);
    else
        dist_norm = zeros(size(dist_scores)); % 无区分度
    end
    
    % 3.2 加法校准策略 (Additive Calibration)
    % 逻辑：NN得分 + lambda * 分布得分
    % lambda = 0.8 是一个经验值，表示分布信息能带来的最大影响幅度
    lambda = 0.8;
    
    % 定义变量 final_scores
    final_scores = nn_scores + lambda * dist_norm * max(abs(nn_scores));
    % 加法策略：直接将归一化的分布得分线性叠加到NN得分上，乘以NN得分的最大绝对值以匹配量级
    
    % 最后的防呆检查：如果有 NaN，替换为极小值
    final_scores(isnan(final_scores)) = -1e10;
    
    [~,ind] = sort(final_scores,'descend');  
end

function [scores] = calculate_distribution_score(Next, mu, K)
% 计算基于马氏距离的分布得分
% 距离越小，得分越高（越接近分布中心）
    [N, D] = size(Next);
    % 防报错：正则化
    K = K + 1e-6 * eye(D); 
    % 防报错：求逆
    try
        inv_K = inv(K);
    catch
        inv_K = pinv(K); 
    end

    mahalanobis_sq = zeros(N, 1);
    
    for j = 1 : N
        diff = Next(j, :) - mu;
        % 计算马氏距离平方: (x-u)' * inv(K) * (x-u)
        mahalanobis_sq(j) = diff * inv_K * diff';
    end
    
    % 转化为得分 (类似于高斯核，距离越远分数越低)
    scores = exp(-0.5 * mahalanobis_sq);
    
    % 处理 NaN
    scores(isnan(scores)) = 0;
end