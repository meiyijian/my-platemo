clc; clear;

%% 1. 设置参数
% 你的数据路径
path_D_REMO = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Data\D_REMO\';
path_REMO   = 'D:\PlatEMO-master\PlatEMO-master\PlatEMO\Data\REMO\';

% 测试问题列表 (建议把 WFG 1-9 都填上)
problem_list = {'WFG1','WFG2','WFG3','WFG4','WFG5','WFG6','WFG7','WFG8','WFG9'};

% 实验参数
M = 3; 
D = 30;
Runs = 30;

% 截取设置
MaxFE_Real = 800;  % 你实际跑的数据是 800
Target_FE  = 500;  % 你想截取的时间点

%% 2. 开始提取和分析
fprintf('%-6s | %-12s | %-12s | %-12s\n', 'Prob', 'REMO(500)', 'D_REMO(500)', 'Result');
fprintf('------------------------------------------------------------\n');

for p = 1 : length(problem_list)
    prob = problem_list{p};
    
    data_REMO   = zeros(Runs, 1);
    data_D_REMO = zeros(Runs, 1);
    
    % --- 读取 D_REMO ---
    for r = 1 : Runs
        file = sprintf('%sD_REMO_%s_M%d_D%d_%d.mat', path_D_REMO, prob, M, D, r);
        if exist(file, 'file')
            load(file, 'metric');
            % 计算索引：假设数据是均匀记录的
            % 例如记录了 20 个点，那么 500/800 * 20 = 第 12.5 个点 -> 取第 13 个
            len = length(metric.IGD);
            idx = ceil((Target_FE / MaxFE_Real) * len);
            idx = max(1, min(idx, len)); % 防止越界
            data_D_REMO(r) = metric.IGD(idx);
        else
            data_D_REMO(r) = NaN; % 文件缺失
        end
    end
    
    % --- 读取 REMO ---
    for r = 1 : Runs
        file = sprintf('%sREMO_%s_M%d_D%d_%d.mat', path_REMO, prob, M, D, r);
        if exist(file, 'file')
            load(file, 'metric');
            len = length(metric.IGD);
            idx = ceil((Target_FE / MaxFE_Real) * len);
            idx = max(1, min(idx, len));
            data_REMO(r) = metric.IGD(idx);
        else
            data_REMO(r) = NaN;
        end
    end
    
    % --- 统计检验 ---
    % 剔除无效数据
    data_REMO(isnan(data_REMO)) = [];
    data_D_REMO(isnan(data_D_REMO)) = [];
    
    if ~isempty(data_REMO) && ~isempty(data_D_REMO)
        m_remo = mean(data_REMO);
        m_dremo = mean(data_D_REMO);
        
        % Rank Sum Test (显著性检验)
        p = ranksum(data_D_REMO, data_REMO, 'tail', 'left'); % D_REMO < REMO ?
        
        sign = '=';
        if p < 0.05
            sign = '+ (Win)';
        elseif mean(data_D_REMO) > mean(data_REMO) % 如果不显著且均值更差，检查是不是输了
             p_loss = ranksum(data_D_REMO, data_REMO, 'tail', 'right');
             if p_loss < 0.05
                 sign = '- (Loss)';
             end
        end
        
        fprintf('%-6s | %.4e   | %.4e   | %s\n', prob, m_remo, m_dremo, sign);
    else
        fprintf('%-6s | Data Missing | Data Missing | N/A\n', prob);
    end
end