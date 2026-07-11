function snapshots = gen_snapshots(prob_handle, M, D, N, seed)
% gen_snapshots - 生成不同进化阶段的种群快照（E1/E2 共享）
%
% 用"代理进化"（GA 算子 + RefSelect 环境选择）产生从随机到收敛的一系列种群，
% 用于对 HybridPBI_Classification 做静态检验。
%
% 为什么用代理进化而不是真实 REMO 轨迹：
%   1. 第二轮的 .mat 只保存了统计量，没有保存逐代种群；
%   2. E1/E2 检验的是 confidence 度量的数学性质（与真值的相关性、尺度不变性），
%      只要求种群"真实且覆盖不同收敛程度"，不要求来自 REMO 本身；
%   3. 代理进化无模型训练，秒级完成。
%
% 快照阶段与 ratio 的对应：
%   REMO 真实运行中 ratio = FE/maxFE，初始化后即为 100/300≈0.33，随后升至 1。
%   这里按 5 个检查点线性铺开，代理代数越大 ratio 越大。
%
% 输入:
%   prob_handle - 问题句柄，如 @DTLZ2
%   M, D, N     - 目标数 / 决策维数 / 种群规模
%   seed        - 随机种子（E1/E2 用相同 seed 可得到完全相同的快照）
% 输出:
%   snapshots   - 1x5 结构体数组，字段:
%     .stage  - 阶段编号 1..5
%     .gen    - 代理进化代数（0=初始种群）
%     .ratio  - 传给 HybridPBI_Classification 的进度参数
%     .PopDec - N x D 决策变量
%     .PopObj - N x M 真实目标值

    rng(seed, 'twister');
    Problem = prob_handle('M',M, 'D',D, 'N',N, 'maxFE',1e9);

    % 初始化方式与 REMO_new2_AdaMaO_Stat 完全一致（Latin 超立方）
    PopDec0    = UniformPoint(N, Problem.D, 'Latin');
    Population = Problem.Evaluation( ...
        repmat(Problem.upper-Problem.lower,N,1).*PopDec0 + ...
        repmat(Problem.lower,N,1));

    checkpoints = [0, 2, 5, 10, 20];          % 代理进化代数
    ratios      = [1/3, 1/2, 2/3, 5/6, 1.0];  % 对应 REMO 的 FE 进度区间

    snapshots = struct('stage',{},'gen',{},'ratio',{},'PopDec',{},'PopObj',{});
    gen = 0;
    for s = 1:numel(checkpoints)
        while gen < checkpoints(s)
            gen = gen + 1;
            % 随机配对 + GA 算子产生子代（真实评估，基准问题评估开销可忽略）
            Parents    = Population(randi(length(Population),1,N));
            Offspring  = OperatorGA(Problem, Parents);
            % 与 REMO 相同的环境选择器截断
            Population = RefSelect([Population, Offspring], N);
        end
        snapshots(end+1) = struct('stage',s, 'gen',gen, 'ratio',ratios(s), ...
            'PopDec',Population.decs, 'PopObj',Population.objs); %#ok<AGROW>
    end
end
