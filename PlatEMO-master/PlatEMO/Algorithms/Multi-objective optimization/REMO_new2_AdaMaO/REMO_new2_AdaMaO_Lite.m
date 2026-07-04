classdef REMO_new2_AdaMaO_Lite < ALGORITHM
% <2026> <multi/many> <real> <expensive>
% AdaMaO-Lite: 彻底移除指标子系统
%
% 本版本从代码层面完全移除 PIEA 风格的 indicator subsystem：
%  - 不初始化 indicator struct
%  - 不调用 IndicatorSelector / Shape_Estimate
%  - 不调用 calFitness_SDE / calFitness_epsilon / calFitness_MD
%  - 不训练 fitrsvm IndicatorModel
%  - 不调用 UpdateInformation / NDSort_SDR 反馈
%  - 候选模式仅保留 conservative 和 explore
%
% 保留核心 AdaMaO 框架：
%  - RuntimeDiagnostics（运行时诊断，用于 explore 触发）
%  - Dynamic relation-pair training（curriculum/weighted/conservative）
%  - 不确定性感知探索
%  - 多样性选择
%
% 实验目的：若 PIEA 指标子系统被完全移除后，核心 AdaMaO 框架是否仍有竞争力。
% 若 Lite 与 FullPIEA 性能相近 → 指标子系统不必要，推荐用作最终论文版本。

    methods
        function main(Algorithm, Problem)
            %% ============ 参数设置 ============
            [k,gmax,q_keep,lambda0,w_min,n_min,n_max,tau_err,~,debug] = ...
                Algorithm.ParameterSet(6,3000,0.80,0.35,0.30,4,6,0.35,1,0);

            %% ============ 初始化种群 ============
            if Problem.D <= 10
                N = 11*Problem.D - 1;
            else
                N = 100;
            end
            PopDec     = UniformPoint(N,Problem.D,'Latin');
            Population = Problem.Evaluation( ...
                repmat(Problem.upper-Problem.lower,N,1).*PopDec + ...
                repmat(Problem.lower,N,1));
            Archive    = Population;

            prev_p_err = 1;
            gen        = 0;

            %% ============ 主优化循环 ============
            while Algorithm.NotTerminated(Archive)
                gen   = gen + 1;
                ratio = Problem.FE / Problem.maxFE;

                %% ---- 自适应参考解数量 ----
                k_eff = min(Problem.N,max(k,ceil(1.5*Problem.M)));

                %% ---- 混合 PBI 分类 ----
                [~,~,Catalog,confidence,Ref] = HybridPBI_Classification( ...
                    Population,ratio,'Nref',N,'k',k_eff,'theta',5);

                %% ---- 运行时诊断 ----
                diagnostics = RuntimeDiagnostics(Population,N);
                mean_conf   = mean(confidence(:));

                %% ---- 动态选择关系对训练模式 ----
                relation_mode = 'conservative';
                if prev_p_err > tau_err
                    relation_mode = 'curriculum';
                elseif prev_p_err <= tau_err && mean_conf >= 0.55 && diagnostics.coverage < 0.60
                    relation_mode = 'weighted';
                end

                %% ---- 生成关系对样本 ----
                Input = Population.decs;
                switch relation_mode
                    case 'weighted'
                        [XXs,YYs,WWs] = GetRelationPairs_confidence(Input,Catalog,confidence);
                        % 加权模式 fallback
                        if isempty(XXs)
                            [XXs,YYs] = GetRelationPairs(Input,Catalog);
                            WWs = [];
                            relation_mode = 'conservative';
                        end
                    case 'curriculum'
                        [XXs,YYs] = GetRelationPairs_curriculum(Input,Catalog,confidence,0.80);
                        WWs = [];
                    otherwise
                        [XXs,YYs] = GetRelationPairs(Input,Catalog);
                        WWs = [];
                end

                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    prev_p_err = 1;
                    continue;
                end

                %% ---- 训练关系预测模型 ----
                [net,TrainIn_struct,p_err] = TrainRelationModel( ...
                    XXs,YYs,WWs,w_min,strcmp(relation_mode,'weighted'));

                %% ---- 候选解选择模式（仅 conservative / explore）----
                candidate_mode = 'conservative';
                if p_err <= tau_err && diagnostics.coverage < 0.60
                    candidate_mode = 'explore';
                end

                %% ---- 构建代理模型结构体 ----
                Smodel = struct();
                Smodel.X              = Input;
                Smodel.Y              = Catalog;
                Smodel.mp_struct      = TrainIn_struct;
                Smodel.net            = net;
                Smodel.p_err          = p_err;
                Smodel.lambda0        = lambda0;
                Smodel.ratio          = ratio;
                Smodel.IndicatorModel = [];
                Smodel.mode           = candidate_mode;
                Smodel.q_keep         = q_keep;
                Smodel.n_min          = n_min;
                Smodel.n_max          = n_max;

                %% ---- 代理模型辅助选择 ----
                Next = AdaMaOSelection( ...
                    Problem,Ref,Population.decs,gmax,Smodel,q_keep,n_min,n_max);

                remain = Problem.maxFE - Problem.FE;
                if isempty(Next) && remain > 0
                    Next = OperatorGA(Problem,[Population.decs;Ref.decs],{1,15,1,5});
                    Next = Next(1:min(n_min,size(Next,1)),:);
                end

                %% ---- 真实评估候选解 ----
                NewSols = [];
                if ~isempty(Next) && remain > 0
                    Next = Next(1:min(size(Next,1),remain),:);
                    NewSols = Problem.Evaluation(Next);
                    Archive = [Archive,NewSols];
                end

                %% ---- 调试输出 ----
                if debug
                    fprintf(['[%s] gen=%d ratio=%.3f rel=%s cand=%s p_err=%.3f ', ...
                             'cov=%.3f deg=%.3f conf=%.3f ind=disabled Lp=NaN nNext=%d\n'], ...
                        class(Algorithm), gen, ratio, relation_mode, candidate_mode, p_err, ...
                        diagnostics.coverage, diagnostics.degeneracy, mean_conf, ...
                        length(NewSols));
                end

                %% ---- 更新状态 ----
                prev_p_err = p_err;
                Population = RefSelect(Archive,Problem.N);
            end
        end
    end
end

%% ============ 辅助函数：运行时诊断 ============
function diagnostics = RuntimeDiagnostics(Population,Nref)
    PopObj = Population.objs;
    PopObj = NormalizeObjectives(PopObj);
    [N,M] = size(PopObj);

    if N == 0 || M == 0
        diagnostics.coverage   = 0;
        diagnostics.degeneracy = 0;
        return;
    end

    V = UniformPoint(Nref,M,'ILD');
    V = V ./ max(vecnorm(V,2,2),eps);

    Direction = PopObj;
    rowNorm = vecnorm(Direction,2,2);
    zeroRows = rowNorm < 1e-12;
    Direction(zeroRows,:) = 1 ./ max(M,1);
    rowNorm(zeroRows) = vecnorm(Direction(zeroRows,:),2,2);
    Direction = Direction ./ max(rowNorm,eps);

    cosine = 1 - pdist2(Direction,V,'cosine');
    [~,assigned] = max(cosine,[],2);
    diagnostics.coverage = numel(unique(assigned)) / size(V,1);

    Centered = PopObj - mean(PopObj,1);
    if size(Centered,1) < 2 || all(abs(Centered(:)) < 1e-12)
        diagnostics.degeneracy = 0;
        return;
    end
    s = svd(Centered,'econ');
    energy = s.^2;
    total = sum(energy);
    if total < 1e-12
        rank90 = M;
    else
        rank90 = find(cumsum(energy)./total >= 0.90,1,'first');
    end
    diagnostics.degeneracy = max(0,min(1,1 - rank90/max(M,1)));
end

%% ============ 辅助函数：目标值归一化 ============
function PopObj = NormalizeObjectives(PopObj)
    zmin = min(PopObj,[],1);
    zmax = max(PopObj,[],1);
    span = zmax - zmin;
    span(span < 1e-12) = 1;
    PopObj = (PopObj - zmin) ./ span;
    PopObj(isnan(PopObj) | isinf(PopObj)) = 0;
end

%% ============ 辅助函数：课程学习模式的关系对生成 ============
function [XXs,YYs] = GetRelationPairs_curriculum(Input,Catalog,confidence,q_keep)
    Catalog = Catalog(:);
    confidence = confidence(:);

    good_idx = find(Catalog == 1);
    rest_idx = find(Catalog ~= 1);

    good_idx = KeepMostConfident(good_idx,confidence,q_keep);
    rest_idx = KeepMostConfident(rest_idx,confidence,q_keep);

    keep_idx = [good_idx;rest_idx];

    if numel(good_idx) < 1 || numel(rest_idx) < 1 || numel(keep_idx) < 2
        XXs = zeros(0,2*size(Input,2));
        YYs = zeros(0,1);
        return;
    end

    Catalog2 = false(numel(keep_idx),1);
    Catalog2(1:numel(good_idx)) = true;

    [XXs,YYs] = GetRelationPairs(Input(keep_idx,:),Catalog2);
end

%% ============ 辅助函数：保留最置信的样本 ============
function idx = KeepMostConfident(idx,confidence,q_keep)
    idx = idx(:);
    if isempty(idx)
        return;
    end
    [~,order] = sort(confidence(idx),'descend');
    n_keep = max(1,ceil(q_keep*numel(idx)));
    idx = idx(order(1:n_keep));
end

%% ============ 辅助函数：训练关系预测模型 ============
function [net,TrainIn_struct,p_err] = TrainRelationModel(XXs,YYs,WWs,w_min,use_weights)
    if use_weights
        [TrainIn,TrainOut,TrainW,TestIn,TestOut,~] = DataProcess_confidence(XXs,YYs,WWs);
    else
        [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);
        TrainW = [];
    end

    xDim = size(TrainIn,2);

    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';

    TrainOut_onehot = onehotconv(TrainOut,1);

    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;

    if use_weights && ~isempty(TrainW)
        EW = TrainW(:)';
        if mean(EW) > 1e-12
            EW = EW ./ mean(EW);
        else
            EW = ones(size(EW));
        end
        EW = max(EW,w_min);
        net = train(net,TrainIn_nor',TrainOut_onehot',[],[],EW);
    else
        net = train(net,TrainIn_nor',TrainOut_onehot');
    end

    if isempty(TestIn)
        p_err = 1;
    else
        TestIn_nor = mapminmax('apply',TestIn',TrainIn_struct)';
        TestPre = onehotconv(net(TestIn_nor')',2);
        p_err = sum(TestPre ~= TestOut) / size(TestPre,1);
    end
    if isnan(p_err) || isinf(p_err)
        p_err = 1;
    end
end
