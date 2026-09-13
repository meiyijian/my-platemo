function Next = DiversifiedInfillSelection(Problem,Ref,Input,wmax,Smodel,qKeep,nMax)
%DiversifiedInfillSelection Generate candidates and apply a pruned criterion.
%   Keeps the original relation-guided GA and candidate-pool accumulation.
%   Exploration uses a relation-score quantile and unweighted batch distance.
%   Indicator mode uses a 30-percent relation shortlist and direct ranking.

    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    allCandidates = Next;
    generated = size(Next,1);
    while generated < wmax && ~isempty(Next)
        [order,~] = model_select(Smodel,Next);
        keepNum = min(length(Ref),size(Next,1));
        if keepNum < 1
            break;
        end
        Input = Next(order(1:keepNum),:);
        Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        allCandidates = [allCandidates;Next]; %#ok<AGROW>
        generated = generated + size(Next,1);
    end
    allCandidates = unique(allCandidates,'rows','stable');
    if isempty(allCandidates)
        Next = allCandidates;
        return;
    end
    [~,scores] = model_select(Smodel,allCandidates);
    batchSize = min(nMax,max(0,floor(Problem.maxFE - Problem.FE)));
    switch Smodel.mode
        case 'explore'
            Next = QualityBatchDistanceSelection( ...
                allCandidates,scores,qKeep,batchSize);
        case 'indicator'
            Next = PrunedIndicatorSelection( ...
                allCandidates,scores,Smodel.IndicatorModel,batchSize);
        otherwise
            error('AdaMaO:InvalidMode','Expected explore or indicator mode.');
    end
end

function [ind,scores] = model_select(Smodel,Next)
%model_select 汇总有序解对的预测概率，计算关系得分。
%   每个候选 Xi 与正组 C1、非正组 C2 分别构造四类有序比较：
%   [C1,Xi]、[Xi,C1]、[C2,Xi]、[Xi,C2]。
%   网络输出顺序为 [+1,0,-1]，表示前者属于更高组、同组、前者属于更低组。
%   四类平均概率对应论文的 a、b、c、d，关系得分为
%   R(Xi) = 2*(c(-1)+d(+1)-a(+1)-b(-1))。
%
%   探索准则使用最大类别概率作为解对权重；指标准则使用算术平均。
%   scores 返回关系得分，ind 返回降序索引。

    model_x = Smodel.X;
    % 按 PAQC 的 Catalog 分离正组 C1 和非正组 C2。
    C1_data = model_x(Smodel.Y == 1,:);
    C2_data = model_x(Smodel.Y ~= 1,:);

    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);
    scores      = zeros(Next_num,1);

    % 任一训练组或候选集为空时，返回初始得分及原始顺序。
    if C1_num == 0 || C2_num == 0 || Next_num == 0
        ind = (1:Next_num)';
        return;
    end

    % 计算每个候选的测试样本数
    nPairPerSol = 2*(C1_num+C2_num);
    all_testdata = zeros(nPairPerSol*Next_num,2*size(C1_data,2));

    % 为每个候选构造 4 类样本对
    for i = 1:Next_num
        original = (i-1)*nPairPerSol;

        % [C1, Xi] 和 [Xi, C1]
        Xi = repmat(Next(i,:),C1_num,1);
        all_testdata(original+1:original+C1_num,:) = [C1_data,Xi];
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi,C1_data];

        % [C2, Xi] 和 [Xi, C2]
        Xi = repmat(Next(i,:),C2_num,1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:) = [C2_data,Xi];
        all_testdata(original+1+C1_num*2+C2_num:original+nPairPerSol,:) = [Xi,C2_data];
    end

    % 用网络预测所有测试样本
    TestIn_nor = mapminmax('apply',all_testdata',Smodel.mp_struct)';
    pre_out = Smodel.net(TestIn_nor')';
    % pair_conf 为每个有序解对的最大预测类别概率。
    pair_conf = max(pre_out,[],2);

    % 为每个候选计算关系得分 R。
    for i = 1:Next_num
        original = (i-1)*nPairPerSol;

        % 索引范围
        idx_C1Xi = original+1 : original+C1_num;
        idx_XiC1 = original+C1_num+1 : original+C1_num*2;
        idx_C2Xi = original+C1_num*2+1 : original+C1_num*2+C2_num;
        idx_XiC2 = original+C1_num*2+C2_num+1 : original+nPairPerSol;

        % 根据模式选择平均方式
        mode = 'conservative';
        if isfield(Smodel,'mode') && ~isempty(Smodel.mode)
            mode = Smodel.mode;
        end
        if strcmp(mode,'explore')
            % 探索模式：使用 softmax 最大类别概率作为加权平均权重
            pre_C1Xi = weighted_mean(pre_out(idx_C1Xi,:),pair_conf(idx_C1Xi));
            pre_XiC1 = weighted_mean(pre_out(idx_XiC1,:),pair_conf(idx_XiC1));
            pre_C2Xi = weighted_mean(pre_out(idx_C2Xi,:),pair_conf(idx_C2Xi));
            pre_XiC2 = weighted_mean(pre_out(idx_XiC2,:),pair_conf(idx_XiC2));
        else
            % 指标准则及关系得分回退分支：使用算术平均。
            pre_C1Xi = mean(pre_out(idx_C1Xi,:),1);
            pre_XiC1 = mean(pre_out(idx_XiC1,:),1);
            pre_C2Xi = mean(pre_out(idx_C2Xi,:),1);
            pre_XiC2 = mean(pre_out(idx_XiC2,:),1);
        end

        % 累加得分
        C_SCORE = zeros(1,2);
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2) + pre_C1Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);

        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);

        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);

        C_SCORE(1) = C_SCORE(1) + pre_XiC2(1);
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);

        % 汇总四类比较结果，得到相对于正组和非正组的关系得分 R。
        scores(i) = C_SCORE(1) - C_SCORE(2);
    end

    % 按得分降序排序
    [~,ind] = sort(scores,'descend');
end

%% ============ softmax 尖锐度加权平均 ============
function y = weighted_mean(x,w)
%weighted_mean 按解对的最大类别概率加权汇总预测概率。

    w = w(:);
    y = sum(x.*w,1)./(sum(w) + eps);
end

