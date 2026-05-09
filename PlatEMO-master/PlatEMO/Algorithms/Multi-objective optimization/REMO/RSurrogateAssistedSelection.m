function Next = RSurrogateAssistedSelection(Problem,Ref,Input,wmax,Smodel)
% 代理模型辅助的选择函数：用训练好的关系模型指导遗传算法生成新解
% Problem  - 优化问题定义
% Ref      - 参考解（当前最好的几个解）
% Input    - 当前种群的决策变量
% wmax     - 最多生成多少个候选解（代理模型评估次数上限）
% Smodel   - 训练好的代理模型（含神经网络）
% Next     - 筛选出的最有潜力的新解（将送去真实评估）

%------------------------------- Copyright --------------------------------
% Copyright (c) 2025 BIMK Group. You are free to use the PlatEMO for
% research purposes. All publications which use this platform or any code
% in the platform should acknowledge the use of "PlatEMO" and reference "Ye
% Tian, Ran Cheng, Xingyi Zhang, and Yaochu Jin, PlatEMO: A MATLAB platform
% for evolutionary multi-objective optimization [educational forum], IEEE
% Computational Intelligence Magazine, 2017, 12(4): 73-87".
%--------------------------------------------------------------------------

    % 第一步：用遗传算子(GA)生成初始子代
    % OperatorGA = 遗传算法操作（模拟二进制交叉+多项式变异）
    % {1,15,1,5} 是遗传算子的参数，控制交叉和变异的强度
    % [Input;Ref.decs] = 把当前种群和参考解拼在一起作为父代
    Next = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
    i    = 0;  % 已经生成的解的数量计数器

    % 循环生成新解，直到达到 wmax 上限
    while i < wmax
        % model_select：用模型评估所有候选解，按潜力从高到低排序
        [soerted_index,~] = model_select(Smodel,Next);
        % 只保留排名前 length(Ref) 个最好的解
        Input = Next(soerted_index(1:length(Ref)),:);
        % 用这些选中的好解 + 参考解，再次通过遗传算子生成下一代
        Next  = OperatorGA(Problem,[Input;Ref.decs],{1,15,1,5});
        i     = i + size(Next,1);  % 更新计数器
    end

    % 循环结束后，对最终所有候选解进行评分排序
    [~,scores] = model_select(Smodel,Next);
    % 阈值筛选：分数 > 3.9 的解被认为很有潜力
    if sum(scores>3.9) < 4
        % 如果高分解不足4个，就取分数最高的4个
        [~,ind] = sort(scores,'descend');
        Next    = Next(ind(1:4),:);
    else
        % 否则取所有分数 > 3.9 的解
        Next = Next(scores>3.9,:);
    end
    % 这些筛选出的 Next 将返回给主函数进行真实的昂贵评估
end

function [ind,scores] = model_select(Smodel,Next)
% 用训练好的关系模型给候选解打分
% Smodel  - 训练好的代理模型
% Next    - 待评估的候选解
% ind     - 按分数从高到低排序的索引
% scores  - 每个候选解的分数（越高表示越有潜力）

    model_x = Smodel.X;     % 训练时使用的所有解（决策变量）
    % C1 = 之前被分为"好"类的解，C2 = "不好"类的解
    C1_data = model_x(Smodel.Y ==1,:);
    C2_data = model_x(Smodel.Y ~=1,:);

    % 各类别和解的数量
    C1_num   = size(C1_data,1);
    C2_num   = size(C2_data,1);
    Next_num = size(Next,1);

    scores = zeros(Next_num,2);

    % 构建所有候选解与已知解的配对数据
    % 每个候选解要跟C1和C2中的每个解配对，形成(C1,Xi)、(Xi,C1)、(C2,Xi)、(Xi,C2)四种配对
    % 这样模型可以通过比较候选解与已知优劣解的关系来判断候选解的质量
    all_testdata = zeros(2*(C1_num+C2_num)*Next_num,2*size(C1_data,2));
    for i = 1 : size(Next,1)
        original = (i-1)*2*(C1_num+C2_num);
        % 配对类型1：候选解Xi 与 C1类解配对，标签应为"不同类"(好关系)
        Xi       = repmat(Next(i,:),size(C1_data,1),1);
        all_testdata(original+1:original+C1_num,:)          = [C1_data,Xi];  % C1在前,Xi在后
        all_testdata(original+1+C1_num:original+C1_num*2,:) = [Xi,C1_data];  % Xi在前,C1在后

        % 配对类型2：候选解Xi 与 C2类解配对，标签也应为"不同类"（但方向不同）
        Xi = repmat(Next(i,:),size(C2_data,1),1);
        all_testdata(original+1+C1_num*2:original+C1_num*2+C2_num,:)          = [C2_data,Xi];  % C2在前,Xi在后
        all_testdata(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2,:) = [Xi,C2_data];  % Xi在前,C2在后
    end

    % 用训练好的归一化参数对测试数据进行归一化
    TestIn_nor = mapminmax('apply',all_testdata',Smodel.mp_struct)';
    % 用神经网络预测所有配对的优劣关系
    pre_out = Smodel.net(TestIn_nor')';

    % 根据预测结果计算每个候选解的得分
    % 核心思想：如果Xi跟C1(好解)关系好，且跟C2(差解)关系差，则Xi得分高
    for i = 1 : size(Next,1)
        C_SCORE    = zeros(1,2);
        original   = (i-1)*2*(C1_num+C2_num);

        % --- 分析 Xi 与 C1 类解的关系 ---
        % pre_out的每一行是3个值，分别对应 [好, 相等, 差] 的概率
        % 对C1_Xi配对：如果C1比Xi好 → Xi应该被淘汰(不好)；如果Xi比C1好或相等 → Xi好
        pre_C1Xi   = sum(pre_out(original+1:original+C1_num,:),1)./C1_num;
        C_SCORE(1) = C_SCORE(1) + pre_C1Xi(2)+pre_C1Xi(3);   % Xi优于或等于C1 → 加分给"好"类
        C_SCORE(2) = C_SCORE(2) + pre_C1Xi(1);               % C1优于Xi → 加分给"差"类

        % 对Xi_C1配对：与上面方向相反但逻辑互补
        pre_XiC1   = sum(pre_out(original+1+C1_num:original+C1_num*2,:),1)./C1_num;
        C_SCORE(1) = C_SCORE(1) + pre_XiC1(2) + pre_XiC1(1);  % Xi优于或等于C1 → 好
        C_SCORE(2) = C_SCORE(2) + pre_XiC1(3);                % C1优于Xi → 差

        % --- 分析 Xi 与 C2 类解的关系 ---
        % 如果Xi比C2好或相等 → Xi好；如果C2比Xi好 → Xi差
        pre_C2Xi   = sum(pre_out(original+1+C1_num*2:original+C1_num*2+C2_num,:),1)./C2_num;
        C_SCORE(1) = C_SCORE(1) + pre_C2Xi(3);                % C2优于Xi → 差
        C_SCORE(2) = C_SCORE(2) + pre_C2Xi(2) + pre_C2Xi(1);  % Xi优于或等于C2 → 好

        pre_XiC2   = sum(pre_out(original+1+C2_num+C1_num*2:original+C2_num*2+C1_num*2,:),1)./C2_num;
        C_SCORE(1) = C_SCORE(1) + pre_XiC1(1);                % Xi优于C2 → 好
        C_SCORE(2) = C_SCORE(2) + pre_XiC2(2) + pre_XiC2(3);  % C2优于或等于Xi → 差

        % 最终得分 = "好"得分 - "差"得分（越高代表Xi越有潜力）
        scores(i) = C_SCORE(1)-C_SCORE(2);
    end
    % 按得分从高到低排序返回
    [~,ind] = sort(scores,'descend');
end
