function [good_idx, bad_idx, Catalog, confidence, Ref] = HybridPBI_Classification(Population, ratio, varargin)
% 输入 ratio 为进化比例（0~1），用于自适应权重 alpha = ratio
% 输出 Ref 为选出的动态参考解
    %% 参数解析
    N = length(Population);
    M = size(Population(1).obj, 2);
    Nref = get_option(varargin, 'Nref', N);
    k = get_option(varargin, 'k', 6);
    theta = get_option(varargin, 'theta', 5);
    
    PopObj = [Population.objs];
    PopDec = [Population.decs];
    
    %% 参考向量场
    V = UniformPoint(Nref, M, 'ILD');
    V = V ./ vecnorm(V, 2, 2);
    
    %% 动态参考解选择
    Ref = RefSelect(Population, k);
    RefObj = [Ref.objs];
    Zmin = min(PopObj, [], 1);
    
    %% 计算参考向量场得分 score_v
    cosine = 1 - pdist2(PopObj, V, 'cosine');
    [~, ref_idx] = max(cosine, [], 2);
    d1 = zeros(N,1);
    d2 = zeros(N,1);
    for i = 1:N
        vi = ref_idx(i);
        w = V(vi,:);
        d1(i) = (PopObj(i,:) - Zmin) * w' / norm(w);
        proj = Zmin + d1(i) * w;
        d2(i) = norm(PopObj(i,:) - proj);
    end
    PBI_v = d1 + theta * d2;
    score_v = 1 ./ (1 + PBI_v);
    
    %% 动态标签（好=1，坏=0）
    label_dyn = GetOutput_PBI(PopObj, RefObj);
    
    %% 融合得分（自适应权重 alpha = ratio）
    alpha = ratio;   % 早期小，后期大？注意：原设计 alpha = 1 - t/T，但 ratio 是已评估比例，早期小后期大
    % 如果希望早期侧重全局（score_v），则 alpha 应大；但通常 alpha 随进化减小，这里取反：
    alpha = 1 - ratio;   % 这样早期 alpha 大，后期 alpha 小，符合原设计
    score_hybrid = alpha * score_v + (1-alpha) * double(label_dyn);
    
    %% 置信度
    confidence = 1 - abs(score_v - double(label_dyn));
    
    %% 排序选出好/坏
    [~, idx_sorted] = sort(score_hybrid, 'descend');
    good_num = ceil(N / 4);
    bad_num  = good_num;
    good_idx = idx_sorted(1:good_num);
    bad_idx  = idx_sorted(end-bad_num+1:end);
    
    %% Catalog 与原始 REMO 兼容（好=true，坏=false）
    Catalog = false(N,1);
    Catalog(good_idx) = true;
    % 坏解仍标记为 false，中间解也标记为 false，这与原始 REMO 一致（无中间解）
end

function val = get_option(args, name, default)
    for i = 1:2:length(args)
        if strcmpi(args{i}, name)
            val = args{i+1};
            return;
        end
    end
    val = default;
end