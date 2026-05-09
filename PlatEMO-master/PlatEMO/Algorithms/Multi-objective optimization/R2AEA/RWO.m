function [Arc,Ar] = RWO(Algorithm,Problem,G2,Population,wD,N,Ar)
% RWO：径向权重优化（Radial Weight Optimization）
% 第一阶段：使用RBF代理模型在目标空间中沿径向方向搜索
%
% 输入参数：
%   Algorithm  - 算法对象
%   Problem    - 问题对象（包含目标函数、变量边界等信息）
%   G2         - DE进化的代数
%   Population - 当前种群
%   wD         - 权重优化中DE的种群规模
%   N          - DE种群大小
%   Ar         - 当前存档（已评估的所有解）
%
% 输出参数：
%   Arc - 本轮RWO产生的非支配解
%   Ar  - 更新后的存档

	%% ==================== 步骤1：选择参考解 ====================
	% Reference：参考点，用于计算超体积（HV）
	% max(Population.objs,[],1)：对种群目标值矩阵按列取最大值
	% Population.objs：种群中所有个体的目标值，大小为 N x M
	% 参考点通常设置为当前种群目标值的最差值
	Reference = max(Population.objs,[],1);

	% EnvironmentalSelection：环境选择算子
	% 从当前种群中选出wD个非支配解作为参考解
	% 返回值：RefPop（参考解），FrontNo（前沿编号），CrowdDis（拥挤距离）
	[RefPop,~,~] = EnvironmentalSelection(Population,wD);

	%% ==================== 步骤2：计算径向方向 ====================
	% Direction：方向向量的长度（欧氏距离）
	% 计算每个参考解到搜索空间边界（上界和下界）的距离
	% RefPop.decs：参考解的决策变量，大小为 wD x D
	% Problem.lower/upper：变量的下界和上界，大小为 1 x D
	% repmat()：矩阵复制函数，将矩阵复制成指定大小
	% .^2：矩阵元素平方，.^0.5：矩阵元素开方
	Direction = [sum((RefPop.decs-repmat(Problem.lower,wD,1)).^2,2).^(0.5);sum((repmat(Problem.upper,wD,1)-RefPop.decs).^2,2).^(0.5)];

	% Direct：单位方向向量
	% 将方向向量除以其长度，得到单位方向向量
	% 共有2*wD个方向：每个参考解对应两个方向（向上和向下）
	Direct = [(RefPop.decs-repmat(Problem.lower,wD,1));(repmat(Problem.upper,wD,1)-RefPop.decs)]./repmat(Direction,1,Problem.D);

	% wmax：权重的最大值
	% 计算搜索空间对角线长度的一半
	% sum((Problem.upper-Problem.lower).^2)：各维度边长平方和
	% ^0.5：开方得到对角线长度，*0.5：取一半
	wmax = sum((Problem.upper-Problem.lower).^2)^(0.5)*0.5;

	%% ==================== 步骤3：优化权重变量 ====================
	% w0：初始权重种群
	% rand(N,2*wD)：生成N行2*wD列的随机数矩阵，范围[0,1]
	% .*wmax：乘以最大权重，使权重范围在[0,wmax]之间
	w0 = rand(N,2*wD).*wmax;

	% fitfunc：适应度函数
	% 根据权重生成候选解，进行真实函数评估，计算负HV值作为适应度
	% fitness：适应度值（负HV值，越小越好）
	% PopNew：本轮产生的候选解
	% Ar：更新后的存档
	[fitness,PopNew,Ar] = fitfunc(Problem,w0,Direct,Reference,Ar);

	%% ==================== 步骤4：构建RBF代理模型 ====================
	% x_train：训练数据的输入（决策变量）
	% y_train：训练数据的输出（目标值）
	x_train = Ar.decs;
	y_train = Ar.objs;

	% ghxd：计算训练数据之间的欧氏距离矩阵
	% 用于确定RBF网络的扩展参数spr
	% real()：取实部，避免复数结果
	ghxd = real(sqrt(x_train.^2*ones(size(x_train'))+ones(size(x_train))*(x_train').^2-2*x_train*(x_train')));

	% D：变量维度
	D = size(x_train,2);

	% spr：RBF网络的扩展参数（spread parameter）
	% 控制RBF核函数的宽度
	% max(max(ghxd))：距离矩阵中的最大值
	% (D*size(x_train,1))^(1/D)：根据数据量和维度自适应计算
	spr = max(max(ghxd))/(D*size(x_train,1))^(1/D);

	% newrbe：创建径向基精确神经网络（Radial Basis Exact Network）
	% 输入：x_train'（转置后的决策变量），y_train'（转置后的目标值）
	% 输出：net（训练好的RBF网络）
	net = newrbe(x_train',y_train',spr);

	% FUN：代理模型函数句柄
	% @(x) sim(net,x')：定义匿名函数，调用RBF网络进行预测
	% sim()：MATLAB神经网络仿真函数
	FUN = @(x) sim(net,x');

	% Arc：存储本轮产生的非支配解
	% NDSort(PopNew.objs,1)：非支配排序，返回前沿编号
	% ==1：筛选第一前沿（非支配解）
	Arc = PopNew(NDSort(PopNew.objs,1)==1);

	%% ==================== 步骤5：DE进化优化 ====================
	% DE（差分进化）算法参数设置
	pCR = 0.2;          % 交叉概率（Crossover Rate）
	beta_min = 0.2;     % 缩放因子下界（Scaling Factor Lower Bound）
	beta_max = 0.8;     % 缩放因子上界（Scaling Factor Upper Bound）

	% 初始化DE种群结构体数组
	empty_individual.Position = [];  % 个体位置（权重向量）
	empty_individual.Cost = [];      % 个体适应度值
	pop = repmat(empty_individual,N,1);  % 创建N个空个体

	% 将初始权重和适应度值填入DE种群
	for i = 1 : N
		pop(i).Position = w0(i,:);    % 设置个体位置
		pop(i).Cost = fitness(i);     % 设置个体适应度
	end

	% DE进化主循环：迭代G2代
	for it = 1 : G2
		minfit = 100000000;  % 记录本轮最优适应度

		% 对每个个体进行变异、交叉和选择操作
		for i = 1 : N
			x = pop(i).Position;  % 当前个体的位置

			% randperm(N)：生成1到N的随机排列
			% A(A==i)=[]：从排列中删除当前个体索引i
			A = randperm(N);
			A(A==i) = [];
			a = A(1); b = A(2); c = A(3);  % 随机选择三个不同的个体

			%% 变异操作（Mutation）
			% beta：缩放因子，在[beta_min, beta_max]范围内随机生成
			% unifrnd()：均匀分布随机数生成函数
			beta = unifrnd(beta_min,beta_max,[1 2*wD]);

			% DE/rand/1变异策略：y = x_a + beta * (x_b - x_c)
			% pop(a/b/c).Position：第a/b/c个个体的位置
			y = pop(a).Position + beta.*(pop(b).Position - pop(c).Position);

			% min(max(y,0),wmax)：边界处理，将变异后的值限制在[0,wmax]范围内
			y = min(max(y,0),wmax);

			%% 交叉操作（Crossover）
			z = zeros(size(x));  % 初始化交叉后的位置

			% j0：随机选择一个位置，确保至少有一个基因来自变异个体
			j0 = randi([1 numel(x)]);

			% 二项式交叉：对每个基因位进行交叉
			for j = 1:numel(x)
				if j==j0 || rand<=pCR
					z(j) = y(j);    % 来自变异个体
				else
					z(j) = x(j);    % 来自当前个体
				end
			end

			% NewSol：新个体结构体
			NewSol.Position = z;

			% fitfuncsurrogate：使用代理模型计算适应度
			% 避免昂贵的真实函数评估
			[fit,PopNew] = fitfuncsurrogate(Problem,z,Direct,Reference,FUN,Ar);

			% 记录本轮最优解
			if fit<minfit || i==1
				minfit = fit;
				Popc = PopNew;
			end

			% 贪心选择：如果新个体更好，则替换当前个体
			NewSol.Cost = fit;
			if NewSol.Cost < pop(i).Cost
				pop(i) = NewSol;
			end
		end
	end

	%% ==================== 步骤6：更新存档 ====================
	% Problem.Evaluation(Popc)：对最优解进行真实函数评估
	temp = Problem.Evaluation(Popc);

	% 将新评估的解加入存档
	Ar = [Ar,temp];
	Arc = [Arc,temp];

	% 如果存档大小超过种群大小，只保留非支配解
	if length(Arc) > Problem.N
		[frontNo,~] = NDSort(Arc.objs,1);  % 非支配排序
		Arc = Arc(frontNo==1);              % 保留第一前沿
	end
end

function [Obj,OffSpring,Ar] = fitfunc(Problem,w0,direct,Reference,Ar)
% fitfunc：适应度函数（使用真实函数评估）
% 根据权重向量生成候选解，进行真实函数评估，计算负HV值
%
% 输入参数：
%   Problem   - 问题对象
%   w0        - 权重向量矩阵，大小为 SubN x (2*wD)
%   direct    - 方向向量矩阵，大小为 (2*wD) x D
%   Reference - 参考点，用于HV计算
%   Ar        - 当前存档
%
% 输出参数：
%   Obj       - 适应度值（负HV值）
%   OffSpring - 产生的候选解
%   Ar        - 更新后的存档

	[SubN,WD] = size(w0);  % SubN：权重种群大小，WD：权重维度
	WD = WD/2;              % WD：单个方向的权重数

	Obj = zeros(SubN,1);    % 初始化适应度数组
	OffSpring = [];         % 初始化候选解数组

	for i = 1 : SubN
		% 根据权重和方向向量生成候选解的决策变量
		% 第一部分：沿下界方向搜索
		% repmat(w0(i,1:WD)',1,Problem.D)：将权重复制D列
		% .*direct(1:WD,:)：乘以方向向量
		% +repmat(Problem.lower,WD,1)：加上下界
		PopDec = [repmat(w0(i,1:WD)',1,Problem.D).*direct(1:WD,:)+repmat(Problem.lower,WD,1);
		          repmat(Problem.upper,WD,1) - repmat(w0(i,WD+1:end)',1,Problem.D).*direct(WD+1:end,:)];

		% Problem.Evaluation(PopDec)：对候选解进行真实函数评估
		OffWPop = Problem.Evaluation(PopDec);

		% 将评估后的解加入存档
		Ar = [Ar,OffWPop];

		% OffSpring：存储所有候选解
		OffSpring = [OffSpring,OffWPop];

		% Obj(i)：计算负HV值作为适应度（最小化）
		% HV()：超体积计算函数
		Obj(i) = -HV(OffWPop,Reference);
	end
end

function [Obj,OffSpring] = fitfuncsurrogate(Problem,w0,direct,Reference,FUN,Arc)
% fitfuncsurrogate：适应度函数（使用代理模型评估）
% 使用RBF代理模型预测候选解的目标值，计算HV值
%
% 输入参数：
%   Problem   - 问题对象
%   w0        - 权重向量
%   direct    - 方向向量
%   Reference - 参考点
%   FUN       - 代理模型函数句柄
%   Arc       - 当前存档
%
% 输出参数：
%   Obj       - 适应度值（HV值）
%   OffSpring - 产生的候选解

	[SubN,WD] = size(w0);
	WD = WD/2;

	Obj = zeros(SubN,1);
	OffSpring = [];

	for i = 1 : SubN
		% 根据权重和方向向量生成候选解
		PopDec = [repmat(w0(i,1:WD)',1,Problem.D).*direct(1:WD,:)+repmat(Problem.lower,WD,1);
		          repmat(Problem.upper,WD,1) - repmat(w0(i,WD+1:end)',1,Problem.D).*direct(WD+1:end,:)];

		% FUN(PopDec)：使用代理模型预测候选解的目标值
		% 不进行真实函数评估，节省计算资源
		OffWPop = FUN(PopDec);

		% 获取存档的目标值
		yArc = Arc.objs;

		% 非支配排序
		[FrontNo,~] = NDSort(Arc.objs,inf);

		% 计算参考点（用于HV计算）
		% Ymin/Ymax：第一前沿的最小/最大目标值
		Ymin = min(yArc(FrontNo == 1,:));
		Ymax = max(yArc(FrontNo == 1,:));
		RefPoint = (Ymax - Ymin).*1.2;  % 参考点设置为范围的1.2倍

		% CalHV：计算超体积
		Obj(i) = CalHV(OffWPop',RefPoint);

		% OffSpring：存储候选解
		OffSpring = [OffSpring,PopDec];
	end
end