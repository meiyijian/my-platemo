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
        [sorted_index,~] = model_select(Smodel,Next);
        Input = Next(sorted_index(1:length(Ref)),:);
        Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i    = i + size(Next,1);
    end
    
    % ========== 修改部分：融合关系得分与指标得分 ==========
    % 获取关系投票得分
    [~, scores_rel] = model_select(Smodel, Next);
    
    % 预测 SDE 指标得分
    scores_ind = predict(Smodel.IndicatorModel, Next);
    
    % 归一化两种得分到 [0,1]
    scores_rel_norm = (scores_rel - min(scores_rel)) / (max(scores_rel) - min(scores_rel) + 1e-6);
    scores_ind_norm = (scores_ind - min(scores_ind)) / (max(scores_ind) - min(scores_ind) + 1e-6);
    
    % 自适应权重：早期 alpha 大，依赖指标全局探索；后期依赖关系局部收敛
    alpha = 1 - (Problem.FE / Problem.maxFE);
    scores_final = alpha * scores_ind_norm + (1-alpha) * scores_rel_norm;
    
    % 按融合得分重排候选解
    [~, idx] = sort(scores_final, 'descend');
    Next = Next(idx, :);
    % =====================================================
    
    % 原填充采样策略（可保留或后续替换为 PIEA 多样性筛选，此处保持原样）
    [~,scores_final_sorted] = model_select(Smodel,Next); % 实际调用关系得分，但顺序已按融合得分排好
    if sum(scores_final_sorted>3.9) < 4
        [~,ind] = sort(scores_final_sorted,'descend');
        Next = Next(ind(1:4),:); 
    else
        Next = Next(scores_final_sorted>3.9,:);
    end
end

function [ind,scores] = model_select(Smodel,Next)
    model_x = Smodel.X;    
    C1_data = model_x(Smodel.Y ==1,:);
    C2_data = model_x(Smodel.Y ~=1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);

    scores = zeros(Next_num,1);  % 注意：原代码是 scores = zeros(Next_num,2)，但实际只用第一列减第二列，改为1列
    
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
        
        scores(i) = C_SCORE(1) - C_SCORE(2);
    end      
    [~,ind] = sort(scores,'descend');  
end