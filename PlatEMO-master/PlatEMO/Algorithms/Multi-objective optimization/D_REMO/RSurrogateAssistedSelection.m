function Next = RSurrogateAssistedSelection(Problem,Ref,Input,wmax,Smodel)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes.
%--------------------------------------------------------------------------

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;
    while i < wmax
        [sorted_index,~]= model_select(Smodel,Next);
        % 修复：防止索引越界，取最小值
        num_to_select = min(length(Ref), length(sorted_index));
        Input = Next(sorted_index(1:num_to_select),:);
        
        Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i     = i + size(Next,1);
    end
    [~,scores] = model_select(Smodel,Next);
    
    % --- 修改点：阈值判断逻辑 ---
    % 由于分数经过了归一化和融合，不再是纯粹的[-4, 4]，
    % 建议直接选最好的 N 个，或者动态设定阈值。
    % 这里保留原意，但优先保证选出 N 个解。
    N = Problem.N; % 或者是传入的需要选出的数量
    [~,ind] = sort(scores,'descend');
    
    % 策略：如果最好的解分数很高，选高分的；否则选前4个（防止报错）
    % 这里简单处理：直接返回前 N' 个最好的，或者按原逻辑
    if sum(scores > 0.8) < 4  % 假设归一化后好解接近1.0
         Next = Next(ind(1:min(4, size(Next,1))), :); 
    else
         Next = Next(scores > 0.8, :);
    end
end

function [ind,final_scores] = model_select(Smodel,Next)
    model_x = Smodel.X;    
    C1_data = model_x(Smodel.Y ==1,:);
    C2_data = model_x(Smodel.Y ~=1,:); % 注意：这里包含 -1 和 0

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);

    % --- 1. 神经网络预测 (Original REMO Logic) ---
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
        % ... (保留原有的投票累加逻辑，此处省略中间代码以节省篇幅，保持不变) ...
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
    
    % --- 2. 分布概率计算 (DISK Logic) ---
    % 注意：Smodel.mu 和 Smodel.K 必须在训练阶段计算好并存入 Smodel
    dist_scores = calculate_distribution_score(Next, Smodel.mu, Smodel.K);
    
    % --- 3. 健壮的归一化与融合 ---
    % 将 NN 得分归一化到 [0, 1]
    if max(nn_scores) - min(nn_scores) > 1e-6
        nn_norm = (nn_scores - min(nn_scores)) ./ (max(nn_scores) - min(nn_scores));
    else
        nn_norm = ones(size(nn_scores)) * 0.5; % 如果都一样，给中间值
    end
    
    % 将 分布得分 归一化到 [0, 1]
    if max(dist_scores) - min(dist_scores) > 1e-6
        dist_norm = (dist_scores - min(dist_scores)) ./ (max(dist_scores) - min(dist_scores));
    else
        dist_norm = ones(size(dist_scores)) * 0.5;
    end
    
    % 加权融合
    lambda = 0.5; % 权重建议设为 0.3 - 0.5，避免喧宾夺主
    final_scores = (1 - lambda) * nn_norm + lambda * dist_norm;
    
    [~,ind] = sort(final_scores,'descend');  
end

function [scores] = calculate_distribution_score(Next, mu, K)
% 计算基于马氏距离的分布得分
% 距离越小，得分越高（越接近分布中心）

    [N, D] = size(Next);
    
    % --- 关键修复 1: 正则化协方差矩阵 ---
    % 防止矩阵奇异导致求逆失败
    K = K + 1e-6 * eye(D); 
    
    % --- 关键修复 2: 使用伪逆或更稳定的求逆 ---
    % 也可以用 pinv(K)，但正则化后的 inv 通常够用
    try
        inv_K = inv(K);
    catch
        inv_K = pinv(K); % 兜底
    end
    
    mahalanobis_sq = zeros(N, 1);
    
    % --- 关键修复 3: 计算马氏距离平方 ---
    % 不计算 exp，防止数值下溢出
    for j = 1 : N
        diff = Next(j, :) - mu;
        mahalanobis_sq(j) = diff * inv_K * diff';
    end
    
    % --- 关键修复 4: 转化为得分 ---
    % 马氏距离越小越好。我们希望输出与概率正相关。
    % 使用 exp(-0.5 * d^2) 模拟高斯核，不需要前面的常数项（归一化会抵消它）
    scores = exp(-0.5 * mahalanobis_sq);
    
    % 处理可能的 NaN
    scores(isnan(scores)) = 0;
end