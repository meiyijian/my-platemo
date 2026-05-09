# REMO_C2RL 算法汇报

> **C**onfidence-aware **C**urriculum **R**elation **L**earning
> 面向高维昂贵多目标优化的置信度感知课程化关系学习算法

---

## 1. 研究背景与动机

### 1.1 问题定位

REMO 系列算法 (Hao et al., IEEE TEVC 2022) 通过 **关系学习** 替代传统代理模型,在 3 目标昂贵优化问题上取得显著效果。然而当目标维数 **M ≥ 5** 时,REMO_new2 (基线版本) 暴露三大痛点:

| 痛点 | 表现 | 根因 |
| :--- | :--- | :--- |
| **训练标签噪声大** | M=10 时关系网络误差 p_err 长期 > 0.4 | HPC 二分类边界模糊,"中间解"被强行归为非好类 |
| **聚合方式过于粗糙** | 简单算术平均导致低置信度对污染 C_SCORE | patternnet softmax 概率信号未被利用 |
| **末尾筛选机制失效** | 死阈值 `score > 3.9` 几乎从不触发 → 总是兜底回 top-4 | 高维下分数分布整体偏低,死阈值不自适应 |

### 1.2 设计哲学

REMO_C2RL 在 REMO_new2 (HybridPBI 分类 + 关系学习 + RefSelect) 基础上,引入 **三个一体化创新**,围绕一条主线展开:

> **"先学清楚的样本,再聚合可靠的信号,最后做敢于探索的选择。"**

三个创新分别对应模型生命周期的三个阶段:**训练前的样本筛选**、**预测中的信号融合**、**选择时的探索-利用权衡**。

---

## 2. 三大创新点详解

### 2.1 创新点 ①:课程化训练 (Curriculum Learning)

**位置**: `GetRelationPairs_Curriculum.m`
**理论依据**: Bengio et al. *Curriculum Learning*, ICML 2009

#### 思想

模仿人类学习路径:**先易后难**。早期阶段只让关系网络学"显然的对",待模型成熟后再挑战"模糊边界对"。

#### 双阶段策略

| 阶段 | 训练样本 | 触发条件 |
| :--- | :--- | :--- |
| **阶段 1 (易)** | 仅用 top-25% 好解 + 决策空间最远 25% "硬负例" | 默认起始阶段,或 p_err > τ_err |
| **阶段 2 (难)** | 全部 N 个解参与配对(与 REMO_new2 一致) | 上一代 p_err ≤ τ_err 时切换 |

#### 关键实现

- **硬负例选择**:计算每个非好解到 good 中心的欧氏距离,取最远的 N/4 个 → 配对时正负样本边界最清晰
- **自适应切换**:`p_err_prev <= tau_err` 时自动升级,避免硬编码代次节奏
- **三重兜底**:好/坏样本过少、子种群过小、关系对不足 20 时,自动退化为阶段 2

```matlab
% 课程切换核心逻辑(REMO_C2RL.m:72-76)
if p_err_prev <= tau_err
    stage = 2;     % 模型已学懂简单样本,挑战难样本
else
    stage = 1;     % 继续在简单样本上巩固
end
```

---

### 2.2 创新点 ②:置信度感知聚合 (Confidence-aware Aggregation)

**位置**: `model_select_confidence.m`
**核心洞察**: patternnet 的 softmax 输出本身就是天然置信度信号,**零额外计算开销**

#### 原方案缺陷

REMO_new2 的 `model_select` 在聚合关系预测时使用 **简单算术平均**:
```
pre_C1Xi = sum(pre_out(idx_C1Xi, :)) / C1_num
```
低置信度对(softmax 接近 [0.4, 0.3, 0.3])与高置信度对(softmax 接近 [0.9, 0.05, 0.05])贡献相同,**模型对边界样本的犹豫被稀释掉了**。

#### 改进公式

将每对的置信度定义为 softmax 最大概率,并用其作为加权平均权重:

$$\text{conf}_j = \max(p_{+1}^j, p_0^j, p_{-1}^j)$$

$$\bar{p} = \frac{\sum_j p_j \cdot \text{conf}_j}{\sum_j \text{conf}_j + \epsilon}$$

#### 副产品:候选解不确定性

聚合过程顺便算出每个候选解的整体不确定性,直接喂给创新点 ③:

$$\text{uncertainty}_i = 1 - \overline{\text{conf}_i}$$

```matlab
% model_select_confidence.m:78-81 加权聚合
pre_C1Xi = sum(pre_out(idx_C1Xi, :) .* w_C1Xi, 1) ./ (sum(w_C1Xi) + eps);
% ... 同理处理 XiC1, C2Xi, XiC2

% model_select_confidence.m:108-109 候选解整体不确定性
all_w           = [w_C1Xi; w_XiC1; w_C2Xi; w_XiC2];
uncertainty(i)  = 1 - mean(all_w);
```

---

### 2.3 创新点 ③:UCB 探索 + 分位数阈值 (Uncertainty-aware Selection)

**位置**: `RSurrogateAssistedSelection_C2RL.m`
**理论依据**: Auer et al. *UCB1*, Machine Learning 2002

#### 双重改进

##### (a) UCB 增广打分

借鉴多臂老虎机的 UCB1 思想:**给不确定性高的候选解一个探索奖励**。

$$\text{score}_{\text{aug}} = \text{score} + \lambda \cdot \text{uncertainty}$$

其中 λ 随进化进度衰减:

$$\lambda = \lambda_0 \cdot (1 - \text{ratio}), \quad \text{ratio} = \frac{\text{FE}}{\text{maxFE}}$$

- **早期 (ratio 小)**: λ 大 → 鼓励探索高不确定性区域
- **后期 (ratio 大)**: λ 小 → 偏向利用已有高分预测

##### (b) 分位数阈值替代死阈值

将 REMO_new2 的死阈值 `score > 3.9` 改为自适应分位数:

```matlab
q = quantile(score_aug, q_keep);      % q_keep 默认 0.7
keep_mask = score_aug >= q;
```

无论分数分布如何漂移,始终保留前 30% 候选,**彻底解决高维下死阈值失效问题**。

##### (c) GA 内循环保持纯净

值得注意的是,GA 内循环 (Stage A) 仍只用 `score` 排序,不引入 uncertainty,避免探索奖励干扰多代演化的稳定性。**UCB 仅在末尾打分(Stage B)发挥作用**。

```matlab
% RSurrogateAssistedSelection_C2RL.m:36-40 末尾打分
[~, scores, uncertainty] = model_select_confidence(Smodel, Next);
score_aug = scores + Smodel.lambda * uncertainty;
q = quantile(score_aug, q_keep);
```

---

## 3. 算法流程图

```
┌─────────────────────────────────────────────────────────────┐
│                  拉丁超立方初始化 (N 个真实评估)              │
└──────────────────────────┬──────────────────────────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │  主循环 (while 未达 maxFE)          │
         └─────────────────┬─────────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │ Step 1: HybridPBI 混合分类         │  (继承 REMO_new2)
         │   ratio 自适应权重 → Catalog        │
         └─────────────────┬─────────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │ Step 2: 课程阶段切换 (创新 ①)       │
         │   p_err_prev ≤ τ_err → stage=2     │
         │   否则 stage=1 (极端对)            │
         └─────────────────┬─────────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │ Step 3: 课程化关系对构造 (创新 ①)   │
         │   stage=1: good ⊕ hard-bad         │
         │   stage=2: 全部解配对               │
         └─────────────────┬─────────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │ Step 4: 训练 patternnet 关系网络    │
         │   3 隐层 [1.5D, D, 0.5D]           │
         │   输出 p_err → 留给下一代切换决策    │
         └─────────────────┬─────────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │ Step 5: 打包 Smodel (含 lambda)    │
         │   λ = λ0 · (1 - ratio)             │
         └─────────────────┬─────────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │ Step 6: 代理辅助选择                │
         │ ┌─ Stage A: GA 内循环              │
         │ │     model_select_confidence (创新 ②)│
         │ └─ Stage B: 末尾打分               │
         │       score_aug = score + λ·unc   │  (创新 ③)
         │       quantile(0.7) 阈值           │
         └─────────────────┬─────────────────┘
                           │
         ┌─────────────────▼─────────────────┐
         │ Step 7: RefSelect 环境选择         │  (继承 REMO_new2)
         └─────────────────┬─────────────────┘
                           │
                  (回到主循环判断)
```

---

## 4. 关键参数

| 参数 | 默认值 | 含义 | 调参建议 |
| :--- | :---: | :--- | :--- |
| `k` | 6 | 参考解数量 | 高维问题可适当增大至 8~10 |
| `gmax` | 3000 | 代理评估上限 (GA 内循环) | 评估预算紧张时减至 1500 |
| `tau_err` | 0.30 | 课程切换阈值 | 越小越保守(更长时间停留阶段 1) |
| `lambda0` | 0.50 | UCB 初始权重 | 探索性问题可增至 0.7 |
| `q_keep` | 0.70 | 末尾分位数 | 保留前 30% 候选,与 8 个评估配合 |

---

## 5. 与已有版本对比

| 版本 | 核心特征 | 相对 REMO_C2RL 的差异 |
| :--- | :--- | :--- |
| REMO (TEVC 2022) | 二分类关系学习 + 简单平均 | 无 HybridPBI、无课程、无 UCB |
| REMO_new2 | HybridPBI 分类 + RefSelect | **缺三大创新**,M≥5 时性能受限 |
| REMO_new2_PIEA3 | 加 PIEA 性能指标体系 | 搬运较多,故事性弱 |
| **REMO_C2RL** | **课程化 + 置信度 + UCB** | **三个创新一体化,自洽故事** |

---

## 6. 创新点关联性 (一体化设计)

三个创新并非独立堆砌,而是 **环环相扣**:

```
       创新 ①                创新 ②                创新 ③
   课程化训练            置信度聚合            UCB + 分位数
   (改善输入)            (改善预测)            (改善选择)
        │                    │                    │
        ▼                    ▼                    ▼
   降低 p_err  ──触发──►  softmax 更可靠 ──喂给──►  uncertainty
                          ↑                      ↓
                          └──── 反过来 ──────────┘
                          uncertainty 反映
                          训练样本是否充分
                          (与课程阶段呼应)
```

- **① → ②**: 课程化让训练更干净 → softmax 概率更尖锐 → 置信度信号更可靠
- **② → ③**: 置信度聚合产生的 uncertainty 直接作为 UCB 的不确定性来源
- **③ → ①**: UCB 探索的高不确定区往往是边界样本 → 真实评估后回流为下一代训练数据 → 帮助阶段 1 → 阶段 2 切换

---

## 7. 实验关注点 (建议)

针对 M = 5, 8, 10 的 DTLZ / WFG 测试集,建议关注以下指标:

1. **p_err 收敛曲线**:验证课程化是否加速训练误差下降
2. **lambda 衰减下的 IGD/HV 变化**:验证早探索后利用的有效性
3. **分位数阈值触发率**:对比死阈值 vs `quantile(0.7)` 的真实评估利用率
4. **stage 切换时机**:统计平均切换代数,确认 τ_err 设置合理

---

## 8. 文件结构

```
REMO_C2RL/
├── REMO_C2RL.m                          # 主算法入口
├── GetRelationPairs_Curriculum.m        # 创新 ①:课程化关系对构造
├── model_select_confidence.m            # 创新 ②:置信度感知聚合
├── RSurrogateAssistedSelection_C2RL.m   # 创新 ③:UCB + 分位数选择
├── HybridPBI_Classification.m           # 继承 REMO_new2:混合分类
├── RefSelect.m                          # 继承 REMO_new2:参考解选择
├── DataProcess.m                        # 继承 REMO:数据预处理
├── Delequalsamples.m                    # 继承 REMO:重复样本去除
├── GetOutput_PBI.m                      # 继承 REMO:PBI 标签生成
├── GetRelationPairs.m                   # 继承 REMO:基础关系对(阶段 2 用)
└── onehotconv.m                         # 继承 REMO:one-hot 编码
```

---

## 9. 总结

REMO_C2RL 通过 **课程学习 → 置信度聚合 → UCB 选择** 三个一体化创新,系统性解决了 REMO_new2 在 M ≥ 5 高维场景下的训练标签噪声、聚合粗糙、阈值失效三大痛点。三个创新各自有明确理论依据 (Curriculum Learning, Softmax Confidence, UCB1),组合起来形成一条 **"清洁数据 → 可靠预测 → 智慧选择"** 的完整故事链,适合在论文写作中作为整体贡献提出。

---

*文档生成日期: 2026-05-05*
