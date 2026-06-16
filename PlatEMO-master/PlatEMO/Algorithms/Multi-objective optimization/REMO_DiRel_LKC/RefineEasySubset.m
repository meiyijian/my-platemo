function S_easy = RefineEasySubset(S_cand, PopObj, d_score, k_easy)
% RefineEasySubset - 反向冗余检查（模块①辅助函数）
%
% 功能概述：
%   检查候选易目标子集中是否存在"高度冗余"的目标对
%   如果两个目标的 |Spearman ρ| > 0.95，说明它们高度相关（信息冗余）
%   此时保留难度较小的那个，剔除难度较大的那个，并补入下一个非冗余目标
%
% 为什么需要冗余检查？
%   假设目标1和目标3的 |ρ| = 0.98（几乎完全正相关）
%   它们提供的信息几乎相同，选两个等于浪费一个名额
%   应该保留较易的那个，把名额给另一个更有价值的目标
%
% 输入：
%   S_cand  - 1×k_easy 向量，候选易目标索引（已按难度升序排列）
%             例如 [1, 3, 5, 7, 9] 表示目标1最易，目标9最难
%   PopObj  - N×M 矩阵，种群目标值
%   d_score - M×1 向量，各目标的难度分数
%   k_easy  - 期望的易目标子集大小
%
% 输出：
%   S_easy  - 1×k_easy 向量，经过冗余检查后的易目标索引
%
% 调用示例：
%   S_cand = [1, 3, 5, 7, 9];  % 候选子集
%   S_easy = RefineEasySubset(S_cand, PopObj, d_score, 5);

    M = size(PopObj, 2);  % 总目标数

    % ===================================================================
    % 计算Spearman相关矩阵（用于判断冗余）
    % ===================================================================
    rho = corr(PopObj, 'type', 'Spearman');
    rho(isnan(rho)) = 0;

    % 按难度升序排列的所有目标索引（用于备选补位）
    [~, ord_all] = sort(d_score, 'ascend');

    % ===================================================================
    % 迭代检查并替换冗余目标
    % ===================================================================
    S_easy = S_cand(:)';  % 转为行向量
    pool_idx = 1;          % 备选池指针，指向 ord_all 中的位置

    while true
        replaced = false;  % 本轮是否有替换发生

        % 双重循环：检查 S_easy 中所有目标对 (i, j)
        for i = 1:length(S_easy)
            for j = i+1:length(S_easy)
                % 检查目标 S_easy(i) 和 S_easy(j) 的相关性
                if abs(rho(S_easy(i), S_easy(j))) > 0.95
                    % === 发现冗余对 ===
                    % 保留 d_score 较小的（更易建模）
                    if d_score(S_easy(i)) <= d_score(S_easy(j))
                        drop = S_easy(j);   % 剔除 j
                    else
                        drop = S_easy(i);   % 剔除 i
                    end

                    % 从备选池中找下一个尚未在 S_easy 中的目标
                    new_target = [];
                    while pool_idx <= M
                        cand = ord_all(pool_idx);  % 备选目标
                        pool_idx = pool_idx + 1;
                        if ~ismember(cand, S_easy)
                            % 找到一个不在 S_easy 中的备选目标
                            new_target = cand;
                            break;
                        end
                    end

                    if isempty(new_target)
                        % 备选池耗尽：直接剔除冗余者（接受 |S_easy| 缩小）
                        S_easy(S_easy == drop) = [];
                    else
                        % 用新目标替换被剔除的冗余目标
                        S_easy(S_easy == drop) = new_target;
                    end

                    replaced = true;
                    break;  % 跳出内层循环
                end
            end
            if replaced
                break;  % 跳出外层循环，重新开始检查
            end
        end

        % 如果本轮没有替换发生，说明没有冗余对了，退出循环
        if ~replaced
            break;
        end
    end

    % ===================================================================
    % 边界保护：确保 |S_easy| ∈ [2, M-1]
    % ===================================================================
    % 为什么至少2个？因为至少需要2个目标才有"多目标"的意义
    % 为什么最多M-1个？因为如果选了M个，就等于没选（退化为全目标）
    if length(S_easy) < 2
        % 用最易的两个目标兜底
        S_easy = ord_all(1:min(2, M))';
    elseif length(S_easy) > M-1
        % 截断到 M-1 个
        S_easy = S_easy(1:M-1);
    end

    % 去重并保持顺序
    S_easy = unique(S_easy, 'stable');

    % 再次确保至少 2 个（防止 unique 后数量减少）
    if length(S_easy) < 2
        diff_pool = setdiff(ord_all, S_easy, 'stable');
        S_easy = [S_easy, diff_pool(1)];
    end
end
