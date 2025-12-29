function C = NewSelect(P,DB,alpha,Problem)
% 候选解选择：从进化搜索生成的解中选择最优的alpha个解进行真实评估
% 输入：
%   P       - 进化搜索后的种群
%   DB      - 真实评估的种群
%   alpha   - 需要选择的候选解数量
%   Problem - 优化问题对象
% 输出：
%   C - 选择的候选解（经过真实评估）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

% This function is written by Zhiyao Zhang (email: z.zhang0@csu.edu.cn)

    
    %% 数据准备
    C     = []; % 初始化候选解集
    index = []; % 初始化新解索引
    for i = 1 : size(P.decs,1)
        dist2 = pdist2(real(P.decs(i,:)),real(DB.decs)); % 计算与现有解的距离
        if min(dist2) > 1e-50 % 如果是新解（距离足够远）
            index = [index,i];
        end
    end
    
    % 如果新解数量小于等于alpha，直接全部选择
    if length(index) <= alpha
       PopNew = P.decs(index,:);
       if ~isempty(PopNew)
           PopNew = Problem.Evaluation(PopNew); % 真实评估
           C      = [C,PopNew]; % 添加到候选解集
       end
       return; 
    end
    
    % 提取新解的决策变量、预测目标值和预测误差
    PopDec = P.decs(index,:);
    PopObj = P.objs(index,:);
    ObjMSE = P.objmse(index,:);

    % 获取真实评估种群的第一前沿解
    A2Obj  = DB.objs;
    [F_,~] = NDSort(A2Obj,1);
    A2Obj  = unique(A2Obj(F_==1,:),'rows'); % 去重
    
    % 归一化处理
    zmin   = min([A2Obj;PopObj],[],1); zmax = max([A2Obj;PopObj],[],1);
    A2Obj  = (A2Obj - zmin)./max(zmax - zmin,10e-10);
    PopObj = (PopObj - zmin)./max(zmax - zmin,10e-10);
    ObjMSE = ObjMSE./(max(zmax - zmin,10e-10).^2); % 均方误差也需要归一化
    
    %% 第一阶段选择：基于DIPD的非支配排序
    [FrontNo,~] = NDSort_DIPD(PopDec,PopObj,ObjMSE,1); % DIPD排序
    PopDec      = PopDec(FrontNo==1,:); % 仅保留第一前沿解
    PopObj      = PopObj(FrontNo==1,:);
    ObjMSE      = ObjMSE(FrontNo==1,:);
    
    % 如果第一前沿解数量小于等于alpha，直接选择
    if size(PopDec,1) <= alpha
        C = [C,Problem.Evaluation(PopDec)]; % 真实评估并返回
        return;
    end
    
    %% 第二阶段选择：基于分布距离的选择
    Pindex = true(1,size(PopObj,1)); % 解选择标记
    while length(find(Pindex==0)) < alpha % 直到选择了alpha个解
        Last     = find(Pindex==1); % 当前可选解索引
        Dis      = Distance(PopObj(Last,:),A2Obj); % 计算每个解与真实前沿的距离
        [~,Rank] = sort(Dis,'descend'); % 按距离降序排序
        PopNew   = PopDec(Last(Rank(1)),:); % 选择距离最远的解
        C        = [C,Problem.Evaluation(PopNew)]; % 真实评估并添加到候选解集
        
        % 更新真实前沿解
        A2Obj    = [DB.objs;C.objs]; 
        [F_P,~]  = NDSort(A2Obj,1);
        A2Obj    = unique(A2Obj(F_P==1,:),'rows');
        A2Obj    = (A2Obj - zmin)./max(zmax - zmin,10e-10); % 重新归一化
        
        Pindex(Last(Rank(1))) = 0; % 标记为已选择
    end
end

function dis = Distance(PopObj,OffObj)
% 计算距离：基于角度的距离，用于分布评估
% 输入：
%   PopObj - 种群目标函数值
%   OffObj - 参考目标函数值
% 输出：
%   dis - 每个解到参考解的最小角度距离
    %% Calculate the angle-based distance between each two solutions
    dis = acos(1-pdist2(PopObj,OffObj,'cosine')); % 计算角度距离
    
    %% 取最近距离
    dis = sort(dis,2); % 按距离排序
    dis = dis(:,1); % 取最近距离
end