# 8 周科研 + Python Agent 开发执行计划

## 默认节奏

- 起点：2026-06-15 按完整周执行；2026-06-10 至 2026-06-14 用于预热、熟悉目录、整理文献。
- 每周 5 天主学习，每天 4-6 小时；周末只补漏，不开新坑。
- 第 1-4 周科研:开发约 6:4；第 5-8 周调整为 5:5。
- 科研主线：`REMO / D_REMO / REMO_DiRel / K-RVEA / MOEA-D-EGO / ParEGO / PC-SAEA / DAREMO_GPT`。
- 开发主线：`D:\MyCode\research-agent-suite`，完成 Paper RAG Agent 和 PlatEMO Experiment Agent。

## Phase Map

| Phase | Weeks | Research | Agent development | Deliverables |
|---|---:|---|---|---|
| Baseline and setup | 1-2 | Run REMO/D_REMO/K-RVEA/MOEA-D-EGO on small DTLZ/WFG cases | LLM API, tools, FastAPI, local RAG | baseline table, experiment log, Paper Agent prototype |
| Workload 1 | 3-4 | Implement difficulty-aware uncertainty infill for REMO | Finish Paper RAG Agent | algorithm code, ablation table, method draft |
| Workload 2 | 5-6 | Design Agent-assisted REMO strategy controller | Finish experiment analysis Agent core | strategy logs, report generator, framework draft |
| Consolidation | 7-8 | Expand experiments and paper text | Engineering packaging and resume | two workload packages, two Agent demos, thesis draft skeleton |

## Week 1

| Day | Research | Agent | Output |
|---|---|---|---|
| Mon | Read `REMO`, `D_REMO`, `REMO_DiRel` | Python venv, env vars, HTTP client basics | REMO flow note |
| Tue | Run REMO on DTLZ2 small case | Minimal OpenAI-compatible chat demo | baseline log |
| Wed | Read `K-RVEA`, `MOEA-D-EGO`, `ParEGO` | tool definitions: calculator/search/file_reader | tool demo |
| Thu | Build experiment log template | FastAPI `/health`, `/chat` | API skeleton |
| Fri | Lock Workload 1 idea | structured output with schema validation | 1-page Workload 1 brief |
| Sat |补 DTLZ/WFG baseline | README draft | reproducible command note |
| Sun | rest or one SAEA paper | light review | 5 interview talking points |

## Week 2

| Day | Research | Agent | Output |
|---|---|---|---|
| Mon | Fix benchmark matrix: DTLZ2/3, WFG4/9, M=5/10 | Design Paper RAG Agent I/O | project spec |
| Tue | Read REMO helper functions | document loading and chunking | local corpus |
| Wed | Compare baseline IGD/HV | local vector/search store | source-grounded QA |
| Thu | Finalize score = relation + uncertainty + diversity | search and summary tools | tool pipeline |
| Fri | Draw Workload 1 flow | `/paper/search`, `/paper/chat` | API demo |
| Sat |补 baseline | Paper Agent README | demo script |
| Sun | rest | rest | no new work |

## Week 3

| Day | Research | Agent | Output |
|---|---|---|---|
| Mon | Create `REMO_DiffUnc` branch/folder | Paper Agent citations and retry | DTLZ2 run |
| Tue | Add uncertainty score | Learn LangGraph state/node/edge | score note |
| Wed | Add difficulty weights | two-agent retrieval + summary | split-agent demo |
| Thu | Ablation: no uncertainty / no difficulty / full | streaming progress | ablation table |
| Fri | Run DTLZ/WFG M=5/10 quick seeds | finish README/API docs | portfolio-ready Project 1 |
| Sat | Plot IGD curves | interview notes | 3-minute project story |
| Sun | weekly review | rest | review note |

## Week 4

| Day | Research | Agent | Output |
|---|---|---|---|
| Mon | Extend M=10/15 | short and long-term memory | batch script |
| Tue | Compare REMO/D_REMO/K-RVEA/MOEA-D-EGO | user preference memory | mean/std table |
| Wed | Statistics: mean/std/win-tie-loss | async gather, timeout, retry | analysis note |
| Thu | Write Workload 1 method section | async search/summarize | 1000-1500 words |
| Fri | Write experiment section | final Paper Agent tests | Workload 1 package |
| Sat | organize tables/figures | resume bullets | submission folder |
| Sun | rest | rest | no new work |

## Week 5

| Day | Research | Agent | Output |
|---|---|---|---|
| Mon | Design Agent-assisted REMO | Design PlatEMO Experiment Agent | framework diagram |
| Tue | Define strategy pool | read CSV/XLSX and summarize IGD/HV | table analysis |
| Wed | Define state features | SVG/plot tool | first plot |
| Thu | Build rule controller | report writer | Markdown report |
| Fri | Add constrained LLM controller design | `/experiment/analyze`, `/experiment/report` | stable JSON |
| Sat | small controller run | README draft | end-to-end report |
| Sun | rest | rest | no new work |

## Week 6

| Day | Research | Agent | Output |
|---|---|---|---|
| Mon | Integrate controller logging | Plan-and-Execute concepts | strategy trace |
| Tue | Compare no-agent/random/rule/LLM | Data/Plot/Report agents | supervisor demo |
| Wed | Safety constraints | tool fallback and timeout | failure handling |
| Thu | DTLZ/WFG small validation | streaming progress | streaming demo |
| Fri | Workload 2 method draft | tests for read/plot/report | pytest/unittest pass |
| Sat | ablation experiments | demo data | full demo report |
| Sun | workflow docs or rest | light review | interview notes |

## Week 7

| Day | Research | Agent | Output |
|---|---|---|---|
| Mon | Extend Workload 2 to M=10/15 | Docker/requirements/env.example | reproducible setup |
| Tue | unify result tables | request ID and tool-call logs | traceable calls |
| Wed | Related Work draft | Streamlit/Gradio or API docs polish | visual demo |
| Thu | success/failure analysis | resume STAR stories | 3 bullets per project |
| Fri | failure cases | mock interview | 10 Q&A |
| Sat | missing seeds | demo recording/script | show materials |
| Sun | rest | rest | no new work |

## Week 8

| Day | Research | Agent | Output |
|---|---|---|---|
| Mon | final Workload 1 figures/tables | Project 1 final README | advisor-ready package |
| Tue | final Workload 2 figures/tables | Project 2 final README/tests | framework story |
| Wed | thesis intro + method | GitHub/Gitee cleanup | draft skeleton |
| Thu | experiment section and limitations | research/dev resumes | two resume versions |
| Fri | final review and delivery plan | project-deep-dive mock interview | 10-minute story |
| Sat | advisor feedback buffer | bug-fix buffer | archive |
| Sun | rest | rest | move to 9-12 week buffer |
