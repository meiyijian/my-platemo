function S_easy = RefineEasySubset(S_cand, PopObj, d_score, k_easy)
% RefineEasySubset - 模块①辅助：反向冗余检查
%
% 若候选易子集中存在高度相关的目标对（|Spearman ρ| > 0.95），保留 d_score 较小者
% （更易），把另一个目标剔出，从剩余目标中按难度顺序补入。
% 同时强制 |S_easy| ∈ [2, M-1]。
%
% 输入：
%   S_cand  : k_easy × 1 候选索引（已按 d_score 升序）
%   PopObj  : N × M 目标值
%   d_score : M × 1 难度分（升序排序所依据）
%   k_easy  : 目标子集大小
%
% 输出：
%   S_easy  : 1 × k_easy 经冗余检查后的易目标索引

    M = size(PopObj, 2);
    rho = corr(PopObj, 'type', 'Spearman');
    rho(isnan(rho)) = 0;

    % 按难度排序的所有目标编号（备用补位池）
    [~, ord_all] = sort(d_score, 'ascend');

    % 从 S_cand 开始，迭代检查并替换冗余目标
    S_easy = S_cand(:)';
    pool_idx = 1;
    % pool 表示备选目标在 ord_all 中的位置；S_easy 用完 k_easy 个后停止
    while true
        replaced = false;
        for i = 1:length(S_easy)
            for j = i+1:length(S_easy)
                if abs(rho(S_easy(i), S_easy(j))) > 0.95
                    % 冗余对：保留 d_score 较小者
                    if d_score(S_easy(i)) <= d_score(S_easy(j))
                        drop = S_easy(j);
                    else
                        drop = S_easy(i);
                    end
                    % 从备选池中找下一个尚未在 S_easy 的目标
                    new_target = [];
                    while pool_idx <= M
                        cand = ord_all(pool_idx);
                        pool_idx = pool_idx + 1;
                        if ~ismember(cand, S_easy)
                            new_target = cand;
                            break;
                        end
                    end
                    if isempty(new_target)
                        % 池耗尽：直接剔除冗余者（接受 |S_easy| 缩小）
                        S_easy(S_easy == drop) = [];
                    else
                        S_easy(S_easy == drop) = new_target;
                    end
                    replaced = true;
                    break;
                end
            end
            if replaced
                break;
            end
        end
        if ~replaced
            break;
        end
    end

    % 边界保护：|S_easy| ∈ [2, M-1]
    if length(S_easy) < 2
        % 用最易的两个非冗余目标兜底
        S_easy = ord_all(1:min(2, M))';
    elseif length(S_easy) > M-1
        S_easy = S_easy(1:M-1);
    end

    S_easy = unique(S_easy, 'stable');
    % 再次确保至少 2 个
    if length(S_easy) < 2
        diff_pool = setdiff(ord_all, S_easy, 'stable');
        S_easy = [S_easy, diff_pool(1)];
    end
end
