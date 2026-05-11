function Next = RSurrogateAssistedSelection_uncertainty(Problem,Ref,Input,wmax,Smodel,q_keep)
% RSurrogateAssistedSelection_uncertainty -- 不确定性感知的代理辅助选择
% 在原 RSurrogateAssistedSelection 基础上引入 UCB (Upper Confidence Bound) 策略:
%   - GA 内循环: 仅用性能得分排序 (保持搜索方向一致性)
%   - 最终选择: score_aug = scores + lambda * uncertainty (鼓励探索高不确定性区域)
%   - 阈值: 自适应分位数替代硬编码 3.9

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ========== GA 内循环: 纯性能得分引导 ==========
    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;
    while i < wmax
        [sorted_index,~] = model_select_uncertainty(Smodel,Next);
        Input = Next(sorted_index(1:length(Ref)),:);
        Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i     = i + size(Next,1);
    end

    %% ========== 最终选择: UCB = 性能 + lambda * 不确定性 ==========
    [~,scores,uncertainty] = model_select_uncertainty(Smodel,Next);

    % UCB 综合得分: lambda 随进化进度衰减
    score_aug = scores + Smodel.lambda * uncertainty;

    % 自适应分位数阈值
    threshold = quantile(score_aug, q_keep);
    cand_idx  = score_aug >= threshold;

    if sum(cand_idx) < 4
        % 高置信度解不足, 取 top-4
        [~,ind] = sort(score_aug,'descend');
        Next    = Next(ind(1:min(4,size(Next,1))),:);
    else
        % 从超过阈值的解中选 4-8 个
        n_keep = min(8, sum(cand_idx));
        [~,ind] = sort(score_aug(cand_idx),'descend');
        cand    = find(cand_idx);
        Next    = Next(cand(ind(1:n_keep)),:);
    end
end
