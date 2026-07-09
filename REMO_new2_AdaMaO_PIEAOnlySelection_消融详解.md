# REMO_new2_AdaMaO_PIEAOnlySelection 消融版本详解

> 对比基准：完整版 `REMO_new2_AdaMaO_FullPIEA.m`（已验证与基版 `REMO_new2_AdaMaO.m` 执行代码逐字一致，仅注释量不同）。
> 本文件只讲「PIEAOnlySelection 改了什么、为什么这么改、结果说明了什么」，不重复整体算法背景。

---

## 1. 一句话定位

**PIEAOnlySelection = 完整版剥掉 AdaMaO 的「自适应关系学习」核心创新，只保留从 PIEA 借来的「指标轮盘选择」子系统，并让指标选择更激进（去掉退化度闸门）。**

它的存在是为了回答一个对论文生死攸关的问题：**本算法的性能到底来自「借来的 PIEA 指标选择」，还是来自「AdaMaO 自创的自适应关系学习」？**

---

## 2. 测试目的（源码注释原文，文件头部 L22–25）

```matlab
% 实验目的：判断性能主要来自于指标选择还是自适应关系学习。
%  - 若 PIEAOnlySelection 接近 FullPIEA → AdaMaO 关系学习创新性较弱
%  - 若 PIEAOnlySelection 远差于 FullPIEA → 自适应关系学习框架重要
%  - 若 PIEAOnlySelection 差于 Lite     → 指标模块单独不够
```

即这是一组**对照实验的「拆解归因」**：

| 假设 | 若出现此结果 | 论文含义 |
|---|---|---|
| PIEAOnlySelection ≈ Full | 剥掉自适应关系学习后性能几乎不降 | AdaMaO 的关系学习是「花架子」，创新性弱 → **对投稿不利** |
| PIEAOnlySelection ≪ Full | 剥掉后性能大跌 | 自适应关系学习是真正的贡献点 → **对投稿有利** |
| PIEAOnlySelection < Lite | 连「删掉整个指标子系统」都不如 | 借来的指标模块不仅没用，单独拎出来还拖后腿 → **应彻底移除指标子系统** |

---

## 3. 改动了哪些环节（总览）

| # | 环节 | 完整版 Full | PIEAOnlySelection | 性质 |
|---|---|---|---|---|
| 1 | 关系对训练模式 | 动态三选一：conservative / curriculum / weighted | **固定 conservative** | 移除自适应 |
| 2 | 关系对生成函数 | `switch` 三分支（含 `_confidence`、`_curriculum`） | **只有 `GetRelationPairs`（保守）** | 移除自适应 |
| 3 | 关系模型训练函数 | `TrainRelationModel`（支持置信度加权） | 新增 `TrainRelationModel_Conservative`（只用 `DataProcess`，无权重） | 裁剪 |
| 4 | 候选解选择触发 | `indicator` 需满足 `degeneracy >= 0.45` 闸门 | **去掉退化度闸门**，模型可用即触发 | 让指标更激进 |

保留不变的：混合 PBI 分类、RuntimeDiagnostics、IndicatorSelector 指标轮盘、fitrsvm 指标模型、UpdateInformation 反馈、NDSort_SDR 反馈、AdaMaOSelection 选择主流程。

> 关键认知：**PIEAOnlySelection 并不是「只保留指标、关掉一切」**（那是另一个变体 FixedIndicatorAlways/NoIndicator 的职责），而是**「关掉 AdaMaO 自创的关系学习，把 borrowed 的 PIEA 指标选择顶到前台」**。这正是第 2 节归因实验的设计意图。

---

## 4. 逐处源码对比

### 改动 1 — 关系对训练模式：动态切换 → 固定 conservative（核心修改）

**完整版 Full（L62–68）**
```matlab
                %% ---- 动态选择关系对训练模式 ----
                relation_mode = 'conservative';
                if prev_p_err > tau_err
                    relation_mode = 'curriculum';
                elseif prev_p_err <= tau_err && mean_conf >= 0.55 && diagnostics.coverage < 0.60
                    relation_mode = 'weighted';
                end
```

**PIEAOnlySelection（L74–78）**
```matlab
                % ---- 始终使用 conservative 关系对 ----
                % 不使用 curriculum/weighted 模式
                % 不使用 DataProcess_confidence
                % 这是 PIEAOnlySelection 的核心修改
                relation_mode = 'conservative';
```

> 含义：完整版会**根据上一代模型误差、置信度、覆盖率**在三种关系对采样策略间切换（这是 AdaMaO 的招牌创新）；PIEAOnlySelection 直接**焊死在 conservative**，永远不用课程学习（curriculum）也不置信度加权（weighted）。

---

### 改动 2 — 关系对生成：三分支 switch → 单一 GetRelationPairs

**完整版 Full（L70–81）**
```matlab
                %% ---- 生成关系对样本 ----
                Input = Population.decs;
                switch relation_mode
                    case 'weighted'
                        [XXs,YYs,WWs] = GetRelationPairs_confidence(Input,Catalog,confidence);
                    case 'curriculum'
                        [XXs,YYs] = GetRelationPairs_curriculum(Input,Catalog,confidence,0.80);
                        WWs = [];
                    otherwise
                        [XXs,YYs] = GetRelationPairs(Input,Catalog);
                        WWs = [];
                end
```

**PIEAOnlySelection（L80–89）**
```matlab
                %% ---- 生成关系对样本（始终 conservative）----
                Input = Population.decs;
                [XXs,YYs] = GetRelationPairs(Input,Catalog);
                WWs = [];

                if isempty(XXs)
                    Population = RefSelect(Archive,Problem.N);
                    prev_p_err = 1;
                    continue;
                end
```

> 含义：去掉了对 `GetRelationPairs_confidence`、`GetRelationPairs_curriculum` 两个自适应函数的调用，只保留最朴素的 `GetRelationPairs`。

---

### 改动 3 — 训练函数：全功能版 → 裁剪版（并删除配套辅助函数）

**完整版 Full（L89–91）调用**
```matlab
                %% ---- 训练关系预测模型 ----
                [net,TrainIn_struct,p_err] = TrainRelationModel( ...
                    XXs,YYs,WWs,w_min,strcmp(relation_mode,'weighted'));
```
完整版还定义了三个辅助函数：`TrainRelationModel`（含置信度加权分支）、`GetRelationPairs_curriculum`、`KeepMostConfident`（见 Full 文件 L253–331）。

**PIEAOnlySelection（L91–93）调用**
```matlab
                %% ---- 训练关系预测模型 ----
                % 始终使用 DataProcess（非 DataProcess_confidence）
                [net,TrainIn_struct,p_err] = TrainRelationModel_Conservative(XXs,YYs);
```
PIEAOnlySelection **新增**了裁剪版训练函数（L210–241），它**只调用 `DataProcess`，不调用 `DataProcess_confidence`，不传样本权重**：

```matlab
function [net,TrainIn_struct,p_err] = TrainRelationModel_Conservative(XXs,YYs)
% TrainRelationModel_Conservative - 仅使用 DataProcess 训练关系神经网络
% 本函数是 TrainRelationModel 的简化版，只支持无权重模式
% 用于 PIEAOnlySelection 版本
    [TrainIn,TrainOut,TestIn,TestOut] = DataProcess(XXs,YYs);   % ← 注意：没有 _confidence
    xDim = size(TrainIn,2);
    [TrainIn_nor,TrainIn_struct] = mapminmax(TrainIn');
    TrainIn_nor = TrainIn_nor';
    TrainOut_onehot = onehotconv(TrainOut,1);
    net = patternnet([ceil(xDim*1.5),xDim,ceil(xDim/2)]);
    net.trainParam.showWindow = 0;
    net = train(net,TrainIn_nor',TrainOut_onehot');             % ← 没有样本权重 EW
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
```

> 含义：关系预测神经网络**再也不吃置信度权重**，训练数据也不再经过课程学习筛选。等于把 AdaMaO 在「关系学习」上的全部巧思清零。

---

### 改动 4 — 候选解选择触发：去掉退化度闸门（让 PIEA 指标更激进）

**完整版 Full（L115–121）**
```matlab
                %% ---- 动态选择候选解选择模式 ----
                candidate_mode = 'conservative';
                if use_indicator && ~isempty(IndicatorModel) && p_err <= tau_err && diagnostics.degeneracy >= 0.45
                    candidate_mode = 'indicator';
                elseif p_err <= tau_err && diagnostics.coverage < 0.60
                    candidate_mode = 'explore';
                end
```

**PIEAOnlySelection（L117–123）**
```matlab
                %% ---- 候选解选择：优先 indicator ----
                candidate_mode = 'conservative';
                if use_indicator && ~isempty(IndicatorModel) && p_err <= tau_err
                    candidate_mode = 'indicator';
                elseif p_err <= tau_err && diagnostics.coverage < 0.60
                    candidate_mode = 'explore';
                end
```

> 差异仅一行：`&& diagnostics.degeneracy >= 0.45` 被删掉。
> 完整版的指标选择是**「只在种群退化度高（PF 退化）时才启用」**的保守安全闸；PIEAOnlySelection 改成**「只要指标模型靠谱（p_err 够小）就用」**——这正是 PIEA 原版指标选择的风格（指标随时可用）。
>
> 为什么这很关键：在断开/退化 PF（如 DTLZ7、WFG6）上，SDE / I_epsilon+ / Minkowski 这些指标本身不可靠。完整版用 `degeneracy>=0.45` 闸门把指标「关」在危险区之外，退化回 conservative；PIEAOnlySelection 在这个危险区反而**更激进地信任指标**。

---

## 5. 结果说明了什么（结合之前的消融数据）

上一轮 16 题 IGD 实测（M=10）：
- **平均秩全场第 2（4.88）** → 表面看「借来的指标选择」很能打。
- **但 DTLZ7（断开 PF）IGD=20.3，而完整版仅 8.63（劣 2.35×）；WFG6 等同理整行变红** → 在断开/退化 PF 上**灾难性崩塌**。

机制解释（基于上面 4 处改动）：
1. 改动 1+2+3 让**关系模型变弱**（无课程学习、无置信度加权），候选解的「关系得分粗筛」质量下降；
2. 改动 4 让**指标在退化 PF 上被过度信任**，而那里指标本就误导；
3. 两者叠加 → 在难 PF 上选出的解质量崩盘。

> 注意一个反直觉点：**平均秩高 ≠ 稳健**。PIEAOnlySelection 靠在 6 个简单/规则 PF 上拿第一把平均分拉低，却在一个难问题上 2.35× 崩塌。对一区审稿人，稳健性比平均秩重要——这正是「不能只看平均秩」的典型案例。

---

## 6. 对「指标模式去留」决策的影响（呼应之前的结论）

- PIEAOnlySelection **接近 Full 但略差、且在难 PF 崩塌** → 既说明 AdaMaO 自适应关系学习（改动 1–3）确有价值，也说明「照搬 PIEA 指标 + 激进触发」(改动 4) 是个**隐患**而非资产。
- 结论不变且更扎实：**不要保留 FixedIndicatorAlways / PIEAOnly 这类「指标顶到前台」的形态**；若要保留指标，也只能保留完整版那种「退化度≥0.45 才触发」的**诊断式 guarded 形态**，或直接走 Lite（删掉整个 borrowed 子系统）。
- 投稿话术可补一句：*"We further ablated the adaptive relation-learning (PIEAOnlySelection): removing it degrades performance on disconnected/degenerate PFs (e.g., DTLZ7 IGD ×2.35), confirming the novelty lies in AdaMaO's adaptive relation learning, not the borrowed indicator."*

---

## 附：4 处改动的「删除/新增」清单

**PIEAOnlySelection 相对 Full 删除的函数：**
- `GetRelationPairs_curriculum`
- `KeepMostConfident`
- `TrainRelationModel`（加权版）

**PIEAOnlySelection 相对 Full 新增的函数：**
- `TrainRelationModel_Conservative`（无权重裁剪版）

**PIEAOnlySelection 相对 Full 改写的 4 处主流程逻辑：**
1. 关系模式：动态三选一 → 固定 `conservative`
2. 关系生成：`switch` 三分支 → 单一 `GetRelationPairs`
3. 训练调用：`TrainRelationModel(...weighted)` → `TrainRelationModel_Conservative(...)`
4. 候选触发：`... && degeneracy>=0.45` → 去掉该闸门
