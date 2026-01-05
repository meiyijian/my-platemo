function Next = RSurrogateAssistedSelection(Problem,Ref,Input,wmax,Smodel)

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;
    while i < wmax
        [soerted_index,~]= model_select(Smodel,Next);
        Input = Next(soerted_index(1:length(Ref)),:);
        Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i     = i + size(Next,1);
    end
    [~,scores] = model_select(Smodel,Next);
    if sum(scores>3.9) < 4
        [~,ind] = sort(scores,'descend');
        Next    = Next(ind(1:4),:); 
    else
        Next = Next(scores>3.9,:);
    end
end

function [ind,scores] = model_select(Smodel,Next)
    model_x = Smodel.X;    
    C1_data = model_x(Smodel.Y ==1,:);
    C2_data = model_x(Smodel.Y ~=1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);

    scores = zeros(Next_num,2);
    
    all_testdata = zeros(2*(C1_num+C2_num)*Next_num,2*size(C1_data,2));
    for i = 1 : size(Next,1)
        original = (i-1)*2*(C1_num+C2_num);
        Xi       = repmat(Next(i,:),size(C1_data,1),1);
        all_testdata(original+1:original+C1_num,:)          = [C1_data,Xi];  %C1_Xi
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi,C1_data]; %Xi_C1
        
        Xi = repmat(Next(i,:),size(C2_data,1),1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:)          = [C2_data,Xi]; %C2_Xi
        all_testdata(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2,:) = [Xi,C2_data];%Xi_C2
    end
    
    TestIn_nor = mapminmax('apply',all_testdata',Smodel.mp_struct)';
    pre_out = Smodel.net(TestIn_nor')';  
    
    % 计算神经网络预测得分（原始REMO的投票评分）
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
        
        pre_XiC2   = sum(pre_out(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2,:),1)./C2_num;
        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);
        
        nn_scores(i) = C_SCORE(1)-C_SCORE(2);
    end  
    
    % 计算分布概率（DISK算法的分布概率模块）
    dist_probs = calculate_distribution_prob(Next, Smodel.mu, Smodel.K);
    
    % 归一化分布概率，使其量级与神经网络得分匹配
    dist_probs_norm = (dist_probs - min(dist_probs)) / (max(dist_probs) - min(dist_probs));
    nn_scores_norm = (nn_scores - min(nn_scores)) / (max(nn_scores) - min(nn_scores));
    
    % 结合神经网络得分和分布概率，计算最终得分
    % 权重参数lambda，默认设为1.0
    lambda = 1.0;
    scores = nn_scores + lambda * dist_probs_norm * max(nn_scores);
    
    [~,ind] = sort(scores,'descend');  
end

function [dist_probs] = calculate_distribution_prob(Next, mu, K)
% 计算每个解的分布概率密度
% 输入：
%   Next - 候选解的决策变量
%   mu   - 分布均值向量
%   K    - 分布协方差矩阵
% 输出：
%   dist_probs - 每个解的分布概率密度
    [N, D] = size(Next); % 解的数量和决策变量维度
    dist_probs = zeros(N, 1);
    
    % 多元高斯分布概率密度函数
    det_K = det(K); % 协方差矩阵的行列式
    inv_K = inv(K); % 协方差矩阵的逆矩阵
    
    % 防止行列式为零导致计算错误
    if det_K < 1e-10
        det_K = 1e-10;
    end
    
    % 计算多元高斯分布概率密度
    for j = 1 : N
        x = Next(j, :) - mu;
        exponent = -0.5 * x * inv_K * x';
        dist_probs(j) = (1 / (det_K^(1/2) * (2*pi)^(D/2))) * exp(exponent);
    end
end