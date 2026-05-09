function score = CalHV(PopObj,optimum)
% CalHV：超体积（Hypervolume, HV）指标计算
% 计算多目标解集的超体积，用于评估解集的质量
%
% 超体积：Pareto前沿与参考点之间所围成的超立方体体积
% HV值越大，表示解集质量越高
%
% 输入参数：
%   PopObj   - 解集的目标值矩阵，大小为 N x M
%   optimum  - 参考点（通常是理想点或最差点）
%
% 输出参数：
%   score    - 超体积值

%------------------------------- Reference --------------------------------
% E. Zitzler and L. Thiele, Multiobjective evolutionary algorithms: A
% comparative case study and the strength Pareto approach, IEEE
% Transactions on Evolutionary Computation, 1999, 3(4): 257-271.
%------------------------------- Copyright --------------------------------
% Copyright (c) 2022 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    %% ==================== 步骤1：检查输入参数 ====================
    % 如果目标维度不匹配，返回NaN
    if size(PopObj,2) ~= size(optimum,2)
        score = nan;
    else
        [N,M] = size(PopObj);  % N：解的数量，M：目标数

        %% ==================== 步骤2：目标值归一化 ====================
        % fmin：各目标的最小值（取实际最小值和0的较小者）
        fmin = min(min(PopObj,[],1),zeros(1,M));

        % fmax：各目标的最大值
        fmax = max(optimum,[],1);

        % 归一化到[0,1]区间
        % (fmax-fmin)*1.1：留出10%的余量
        PopObj = (PopObj-repmat(fmin,N,1))./repmat((fmax-fmin)*1.1,N,1);

        % 删除超出参考点的解（目标值>1的解）
        PopObj(any(PopObj>1,2),:) = [];

        % RefPoint：参考点，设置为全1向量
        RefPoint = ones(1,M);

        %% ==================== 步骤3：计算超体积 ====================
        if isempty(PopObj)
            % 如果没有有效解，返回0
            score = 0;
        elseif M < 4
            %% --- 目标数<4：使用精确算法（递归切片法） ---
            % sortrows：按行排序
            pl = sortrows(PopObj);

            % S：存储切片信息
            S = {1,pl};

            % 递归切片计算
            for k = 1 : M-1
                S_ = {};
                for i = 1 : size(S,1)
                    % Slice：在第k维进行切片
                    Stemp = Slice(cell2mat(S(i,2)),k,RefPoint);
                    for j = 1 : size(Stemp,1)
                        % 合并切片结果
                        temp(1) = {cell2mat(Stemp(j,1))*cell2mat(S(i,1))};
                        temp(2) = Stemp(j,2);
                        S_ = Add(temp,S_);
                    end
                end
                S = S_;
            end

            % 计算最终超体积
            score = 0;
            for i = 1 : size(S,1)
                p = Head(cell2mat(S(i,2)));
                score = score + cell2mat(S(i,1))*abs(p(M)-RefPoint(M));
            end
        else
            %% --- 目标数>=4：使用蒙特卡洛估计 ---
            % SampleNum：采样点数量
            SampleNum = 1e6;  % 100万个采样点

            % MaxValue/MinValue：采样范围
            MaxValue = RefPoint;
            MinValue = min(PopObj,[],1);

            % unifrnd：均匀分布随机数生成
            % 在[MinValue, MaxValue]范围内生成SampleNum个采样点
            Samples = unifrnd(repmat(MinValue,SampleNum,1),repmat(MaxValue,SampleNum,1));

            % 逐个解检查哪些采样点被支配
            for i = 1 : size(PopObj,1)
                % drawnow('limitrate')：允许MATLAB处理其他事件（如中断）
                drawnow('limitrate');

                % domi：标记哪些采样点被当前解支配
                domi = true(size(Samples,1),1);
                m = 1;

                % 检查所有目标维度
                while m <= M && any(domi)
                    % 如果当前解在第m个目标上优于采样点，则可能支配
                    domi = domi & PopObj(i,m) <= Samples(:,m);
                    m = m + 1;
                end

                % 删除被支配的采样点
                Samples(domi,:) = [];
            end

            % 超体积估计 = 超矩形体积 * 被支配比例
            % prod(MaxValue-MinValue)：超矩形体积
            % (1-size(Samples,1)/SampleNum)：被支配的采样点比例
            score = prod(MaxValue-MinValue)*(1-size(Samples,1)/SampleNum);
        end
    end
end

function S = Slice(pl,k,RefPoint)
% Slice：在第k维进行切片
% 递归切片法的核心函数
%
% 输入参数：
%   pl       - 目标值矩阵
%   k        - 当前切片的维度
%   RefPoint - 参考点
%
% 输出参数：
%   S        - 切片结果

    p = Head(pl);      % 取第一行
    pl = Tail(pl);     % 取剩余行
    ql = [];
    S = {};

    while ~isempty(pl)
        ql = Insert(p,k+1,ql);  % 插入到ql中
        p_ = Head(pl);           % 取下一行

        % 计算切片体积
        cell_(1,1) = {abs(p(k)-p_(k))};
        cell_(1,2) = {ql};
        S = Add(cell_,S);

        p = p_;
        pl = Tail(pl);
    end

    % 处理最后一个切片
    ql = Insert(p,k+1,ql);
    cell_(1,1) = {abs(p(k)-RefPoint(k))};
    cell_(1,2) = {ql};
    S = Add(cell_,S);
end

function ql = Insert(p,k,pl)
% Insert：将点p插入到列表pl中
% 保持列表的有序性，并删除被支配的点
%
% 输入参数：
%   p  - 要插入的点
%   k  - 比较的起始维度
%   pl - 点列表
%
% 输出参数：
%   ql - 插入后的列表

    flag1 = 0;
    flag2 = 0;
    ql = [];
    hp = Head(pl);

    % 找到插入位置
    while ~isempty(pl) && hp(k) < p(k)
        ql = [ql;hp];
        pl = Tail(pl);
        hp = Head(pl);
    end

    % 插入点p
    ql = [ql;p];

    m = length(p);

    % 处理剩余的点，删除被p支配的点
    while ~isempty(pl)
        q = Head(pl);
        for i = k : m
            if p(i) < q(i)
                flag1 = 1;
            else
                if p(i) > q(i)
                    flag2 = 1;
                end
            end
        end

        % 如果q不被p支配，则保留
        if ~(flag1 == 1 && flag2 == 0)
            ql = [ql;Head(pl)];
        end
        pl = Tail(pl);
    end
end

function p = Head(pl)
% Head：获取矩阵的第一行
% 如果矩阵为空，返回空矩阵
    if isempty(pl)
        p = [];
    else
        p = pl(1,:);
    end
end

function ql = Tail(pl)
% Tail：获取矩阵除第一行外的所有行
% 如果矩阵只有一行或为空，返回空矩阵
    if size(pl,1) < 2
        ql = [];
    else
        ql = pl(2:end,:);
    end
end

function S_ = Add(cell_,S)
% Add：将切片结果添加到集合S中
% 如果已存在相同的切片，则合并体积
%
% 输入参数：
%   cell_ - 新的切片结果
%   S     - 已有的切片集合
%
% 输出参数：
%   S_    - 更新后的切片集合

    n = size(S,1);
    m = 0;

    % 检查是否已存在相同的切片
    for k = 1 : n
        if isequal(cell_(1,2),S(k,2))
            % 如果存在，合并体积
            S(k,1) = {cell2mat(S(k,1))+cell2mat(cell_(1,1))};
            m = 1;
            break;
        end
    end

    % 如果不存在，添加新的切片
    if m == 0
        S(n+1,:) = cell_(1,:);
    end

    S_ = S;
end
