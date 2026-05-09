function res = onehotconv(val, type)
% onehotconv - Convert between labels and one-hot encoding
% [核心修复]: 彻底移除 varargout 细胞数组，直接返回实数矩阵，防止 net(train) 报错
% Copyright (c) 2025 BIMK Group.

    if type == 1
        res = zeros(size(val, 1), 3);
        res(val == 1, 1) = 1;
        res(val == 0, 2) = 1;
        res(val == -1, 3) = 1;
        
    elseif type == 2
        res = zeros(size(val, 1), 1);
        [~, maxind] = max(val,[], 2);
        res(maxind == 1) = 1;
        res(maxind == 3) = -1;
    end
end