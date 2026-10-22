# SkillOpt 项目深度分析报告

> 分析日期：2026-10-10  
> 项目地址：https://github.com/microsoft/SkillOpt  
> 版本：v0.2.0  
> 许可证：MIT  
> 所属机构：Microsoft Research

---

## 1. 项目概述

**SkillOpt** 是微软研究院开源的 **智能体技能优化框架**，核心思想是：**将 Agent 技能文档视为可训练参数，用类似深度学习的方法对其进行优化——无需修改模型权重**。

其核心理念可以类比为：

| 深度学习 | SkillOpt |
|---|---|
| 模型权重 | 技能文档 (`skill.md`) |
| 训练数据 | 任务 rollout 轨迹 |
| 梯度 | 反思 → 聚合产生的编辑补丁 |
| 优化器 | LLM 驱动的 bounded edit 选择器 |
| 学习率 | 每步最大编辑数 (edit budget) |
| 验证集 | held-out validation gate |
| Epoch | 对训练数据的完整遍历 |

### 核心成果

- 在 **6 个 benchmark × 7 个目标模型 × 3 种执行 harness** 的全部 52 个评测单元中取得最优或并列最优
- GPT-5.5 上平均准确率提升：**直接对话 +23.5 分，Codex 循环 +24.8 分，Claude Code +19.1 分**
- 优化后的技能跨模型规模、跨 harness、跨 benchmark 可迁移
- 部署产物仅为一个 300–2000 token 的 `best_skill.md`，推理时零额外模型调用

### 论文与引用

- 论文：[arXiv:2605.23904](https://arxiv.org/abs/2605.23904)
- 项目主页：https://microsoft.github.io/SkillOpt/
- PyPI：https://pypi.org/project/skillopt/

---

## 2. 项目规模统计

| 指标 | 数值 |
|---|---|
| 总文件数 | 476 |
| Python 文件数 | 244 |
| Python 代码总行数 | ~75,772 |
| 测试文件数 | 89 |
| 测试函数数 | 1,466 |
| Git 提交总数 | 575 |
| 项目时间跨度 | 2026-05-21 ~ 2026-10-06 |
| 贡献者（活跃） | 20+ |
| Benchmark 环境数 | 6 |
| 模型后端数 | 10+ |
| 插件系统数 | 7 |
| 文档页面数 | 20+ |

---

## 3. 项目架构

### 3.1 顶层目录结构

```
SkillOpt/
├── skillopt/              # 核心研究包 — ReflACT 训练循环
├── skillopt_sleep/        # 夜间离线自进化引擎 (Sleep 模块)
├── skillopt_webui/        # Gradio WebUI 监控面板
├── scripts/               # 训练/评估入口脚本
├── configs/               # YAML 配置文件 (每 benchmark 一份)
├── tests/                 # 测试套件 (89 文件, 1466 测试)
├── plugins/               # Agent 平台集成插件
├── docs/                  # MkDocs 文档源
├── blog/                  # 技术博客
├── data/                  # 数据 split 目录
├── ckpt/                  # 检查点目录
├── skillopt-assets/       # 静态资源
├── .cursor-plugin/        # Cursor IDE 插件配置
├── .github/               # CI/CD (GitHub Actions)
├── pyproject.toml         # 项目元数据与依赖
├── mkdocs.yml             # 文档站点配置
└── index.html             # 项目主页
```

### 3.2 三大核心包关系

```
┌────────────────────────────────────────────────────────────┐
│                      skillopt (核心研究包)                    │
│  ┌─────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐   │
│  │  engine  │  │ gradient │  │ optimizer│  │   model  │   │
│  │(Trainer) │→ │(reflect/ │→ │(skill/   │→ │(backends)│   │
│  │         │  │ aggregate│  │ clip/lr) │  │         │   │
│  └────┬────┘  └──────────┘  └──────────┘  └──────────┘   │
│       │                                                     │
│       ├── envs/ (6 benchmarks)                              │
│       ├── evaluation/ (validation gate)                     │
│       ├── datasets/ (data loading)                          │
│       ├── prompts/ (prompt registry)                        │
│       └── utils/ (json, scoring, console)                   │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│               skillopt_sleep (Sleep 自进化引擎)               │
│  ┌─────────┐  ┌──────┐  ┌───────┐  ┌───────────┐         │
│  │ harvest │→ │ mine │→ │ replay│→ │consolidate│→ gate   │
│  │(收割转录)│  │(挖掘) │  │(回放) │  │(巩固)      │         │
│  └─────────┘  └──────┘  └───────┘  └───────────┘         │
│       + adapters/ (superpowers)                             │
│       + experiments/ (gbrain, transfer, sweep)              │
└────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────┐
│               skillopt_webui (Gradio 监控面板)                │
│  配置 → 启动 → 监控训练过程                                    │
└────────────────────────────────────────────────────────────┘
```

---

## 4. 核心模块分析

### 4.1 skillopt — 研究核心包 (~14,522 行)

#### 4.1.1 engine/trainer.py (2,535 行) — 训练循环主控制器

`ReflACTTrainer` 是核心训练器，编排完整的 6 阶段 pipeline：

1. **Rollout** — 用当前技能执行 episode，收集轨迹
2. **Reflect** — 分析轨迹，生成编辑补丁 (patch)
3. **Aggregate** — 层次化合并补丁
4. **Select** — 排序并选择 top 编辑
5. **Update** — 将编辑应用到技能文档
6. **Evaluate** — 验证候选技能，accept/reject

特点：
- 环境无关，所有环境特定逻辑委托给 `EnvAdapter`
- 支持多后端配置（optimizer 和 target 可用不同模型）
- 内置学习率调度、慢更新、元技能等高级机制

#### 4.1.2 gradient/ — 梯度计算

| 模块 | 功能 |
|---|---|
| `reflect.py` (648 行) | Minibatch 轨迹分析 — 将轨迹分组为 minibatch 一起分析（类似 minibatch SGD） |
| `aggregate.py` (275 行) | 层次化补丁合并 — 将独立生成的 patch 合并为连贯的单一 patch |

Reflect 阶段的关键创新：**minibatch 反思** — 不是独立分析每条轨迹，而是将失败案例分成 minibatch 一起分析，类似神经网络训练中的 minibatch SGD vs per-sample SGD。

#### 4.1.3 optimizer/ — 优化器

| 模块 | 功能 | 类比 |
|---|---|---|
| `skill.py` | 编辑应用 — 将 ranked edits 应用到技能文档 | `optimizer.step()` |
| `clip.py` | 编辑排序与选择 — 按重要性排序，选 top-L | Gradient clipping |
| `scheduler.py` | 学习率调度器 (constant/linear/cosine/autonomous) | LR scheduler |
| `slow_update.py` (429 行) | Epoch 级纵向精化 — 在技能文档保护区写入长期指导 | Weight decay |
| `meta_skill.py` | 跨 epoch 优化器记忆 — 从相邻 epoch 技能对比中提炼指导 | Meta-learning |
| `rewrite.py` | 全技能重写模式 | Full fine-tuning |
| `lr_autonomous.py` | 优化器驱动的自主更新大小决策 | Auto LR |
| `appendix.py` | EmbodiSkill 保护区附录字段 | Protected params |
| `skill_aware.py` | 技能感知反思 — 区分 SKILL_DEFECT vs EXECUTION_LAPSE | Error attribution |
| `update_modes.py` | patch / rewrite_from_suggestions / full_rewrite_minibatch 切换 | Update strategy |

#### 4.1.4 model/ — 多后端模型路由 (~6,000+ 行)

支持的 **Chat 后端** (optimizer + target):
| 后端 | 文件 | 说明 |
|---|---|---|
| `openai_chat` | (via azure_openai.py) | Azure OpenAI / 标准 OpenAI |
| `claude_chat` | `claude_backend.py` (376 行) | Anthropic Claude |
| `qwen_chat` | `qwen_backend.py` (613 行) | 阿里通义千问 (vLLM) |
| `minimax_chat` | `minimax/backend.py` (424 行) | MiniMax |
| `copilot_chat` | `copilot_backend.py` (277 行) | GitHub Copilot CLI |
| `openai_compatible` | `openai_compatible_backend.py` (453 行) | 通用 OpenAI 兼容接口 |

支持的 **Exec 后端** (target only):
| 后端 | 文件 | 说明 |
|---|---|---|
| `codex_exec` | `codex_backend.py` (677 行) + `codex_harness.py` (2,036 行) | OpenAI Codex CLI |
| `claude_code_exec` | `claude_code_backend.py` (313 行) | Claude Code CLI |
| `cursor_exec` | (in codex_harness) | Cursor Agent CLI |
| `copilot_exec` | (in copilot_backend) | Copilot CLI exec 模式 |

架构特点：
- Optimizer 和 Target 可以使用不同的后端和模型
- `codex_harness.py` 是所有 exec 后端的共享基础设施
- 通过 `backend_config.py` 统一管理配置
- `router.py` 提供统一调用接口

#### 4.1.5 envs/ — Benchmark 环境

6 个内置 benchmark，每个都实现 `EnvAdapter` 抽象接口：

| Benchmark | 类型 | 关键文件 | 说明 |
|---|---|---|---|
| **ALFWorld** | 交互式文本游戏 | adapter, dataloader, reflect, rollout | 家庭机器人任务 |
| **DocVQA** | 文档视觉问答 | adapter, dataloader, evaluator, rollout | 文档理解 |
| **LiveMathematicianBench** | 数学 MCQ | adapter, dataloader, evaluator, reflect, rollout | 定理驱动的数学推理 |
| **OfficeQA** | 办公软件问答 | adapter, dataloader, evaluator, rollout, tool_runtime | Office 工具使用 |
| **SearchQA** | 检索式问答 | adapter, dataloader, evaluator, reflect, rollout | 开放域 QA |
| **SpreadsheetBench** | 电子表格操作 | adapter, dataloader, evaluator, executor, react_agent, codegen_agent, reflect, rollout | 表格代码生成 |

每个 benchmark 包含：
- `adapter.py` — EnvAdapter 实现
- `dataloader.py` — 数据加载
- `rollout.py` — 执行和评分
- `evaluator.py` (可选) — 评估指标
- `reflect.py` (可选) — 环境特定反思提示
- `prompts/` — 提示词模板
- `skills/` — 初始种子技能

还包含 `_template/` 目录提供新 benchmark 的模板。

#### 4.1.6 evaluation/ — 验证门控

`gate.py` 实现 SkillOpt 的核心安全机制：

- `GateResult` — 门控决策 (accept_new_best / accept / reject)
- `select_gate_score()` — 将 (hard, soft) 分数投影为单一比较指标
- `evaluate_gate()` — 只有当候选技能**严格改进** held-out 验证分数时才接受

#### 4.1.7 其他核心模块

| 模块 | 说明 |
|---|---|
| `types.py` | 标准化数据类型 — Edit, Patch, RolloutResult, GateResult 等 |
| `config.py` | 配置加载与合并 |
| `datasets/base.py` (512 行) | 数据加载基类 — BatchSpec, SplitDataLoader |
| `prompts/` | 提示词注册表 |
| `utils/json_utils.py` (267 行) | JSON 提取与修复 |
| `utils/scoring.py` | 评分工具 |
| `utils/console.py` | 控制台输出 |

---

### 4.2 skillopt_sleep — 夜间离线自进化引擎 (~15,254 行)

这是 v0.2.0 的旗舰新功能，为本地编码 Agent（Claude Code / Codex / Copilot）提供"睡眠周期"。

#### 4.2.1 核心 Pipeline

```
run_sleep_cycle():
  harvest → mine → replay → consolidate(gate) → stage → (optional adopt)
```

| 阶段 | 模块 | 行数 | 功能 |
|---|---|---|---|
| **Harvest** | `harvest.py` + `harvest_sources.py` + `harvest_*.py` | ~2,000+ | 读取本地 Agent 会话记录（只读），规范化为 SessionDigest |
| **Mine** | `mine.py` + `llm_miner.py` | ~700 | 将 SessionDigest 转为 TaskRecord 训练单元 |
| **Replay** | `replay.py` | — | 在给定 (skill, memory) 下离线回放 TaskRecord 并评分 |
| **Consolidate** | `consolidate.py` + `dream.py` | ~800 | 提出有界编辑 → 应用到候选技能 → 验证门控 |
| **Stage/Adopt** | `staging.py` | 3,161 | 写入提案到 staging 目录；显式 adopt 步骤覆盖 live 文件 |

#### 4.2.2 Harvest 源支持

支持从多种 Agent 平台的转录记录中收割数据：

| 源 | 模块 | 说明 |
|---|---|---|
| Claude Code | `harvest.py` | 读取 ~/.claude/ 下的 JSONL 记录 |
| Codex CLI | `harvest_codex.py` | Codex 会话记录 |
| GitHub Copilot | `harvest_copilot.py` (443 行) | Copilot 会话记录 |
| Copilot CLI | `harvest_copilot_cli.py` | Copilot CLI 特定格式 |
| Cursor | `harvest_cursor.py` (316 行) | Cursor IDE 会话 |
| OpenCode | `harvest_opencode.py` (364 行) | OpenCode SQLite 历史 |
| π (Pi) | `harvest_pi.py` (311 行) | Pi Agent 会话 |

#### 4.2.3 关键设计特点

**安全机制 (Dreams 安全契约)**：
- 循环**从不直接修改**用户的 live CLAUDE.md / SKILL.md
- 所有更改先写入 staging 目录的提案
- 需要显式 `adopt` 步骤才会覆盖 live 文件（同时创建备份）

**验证门控**：
- `gate.py` — 自包含的验证门控（从研究包 vendored，零依赖）
- 只有严格改进 held-out 分数的候选才被接受

**Dream 机制**：
- `dream.py` — 离线记忆巩固
- Dream rollouts — 每个任务跑 K 次，从好/坏对比中学习
- Associative recall — 每晚拉取与今晚新任务最相似的 K 个历史任务
- 合成增强 — 对真实任务进行轻量级确定性改述

**预算管理**：
- `budget.py` — 控制 token 和时间的预算
- `scheduler.py` — 内置 crontab / Windows 计划任务调度器

**多技能支持**：
- `multi_skill.py` — 一晚巩固多个技能组
- `skill_resolver.py` — 将发现的技能名解析到本地 SKILL.md
- 每个技能独立巩固、独立门控决策

**Handoff 后端**：
- `handoff_backend.py` — 无需模型子进程或 API key 运行
- 将每个模型调用写入 PROMPTS.md，由用户的 Agent 会话回答
- 通常每晚 3-6 轮

#### 4.2.4 附加组件

| 模块 | 说明 |
|---|---|
| `backend.py` (2,603 行) | 统一后端接口 — Backend 抽象 + 构建器 |
| `judges.py` (344 行) | 评判器 — 规则检查 / LLM 评分 |
| `evidence.py` | 证据日志 — 每晚可追溯的决策链 |
| `memory.py` | 记忆管理 — CLAUDE.md / SKILL.md 脚手架 |
| `evalkit.py` (718 行) | 配对 A/B 评估工具包 — McNemar 检验 + 百分位数 bootstrap CI |
| `config.py` | 配置加载 |
| `state.py` | 状态管理 |
| `types.py` | 类型定义 |
| `prompts.py` (250 行) | 提示词注册表 |
| `adapters/superpowers.py` (1,379 行) | Superpowers 技能评估适配器 |
| `experiments/` | 实验脚本 (gbrain, transfer, sweep, personas) |

---

### 4.3 skillopt_webui — Gradio 监控面板 (~814 行)

基于 Gradio 的 Web 界面，用于配置、启动和监控训练过程。

核心特性：
- 浏览器内配置训练参数
- 实时训练进度监控
- 路径安全验证（防止路径遍历攻击）
- 支持 Gradio 5.x 和 6.x 两个大版本
- 默认仅绑定 loopback (127.0.0.1)

---

## 5. 插件系统

SkillOpt 为 7 个 Agent 平台提供集成插件：

### 5.1 插件概览

| 插件 | 平台 | 关键文件 | 功能 |
|---|---|---|---|
| **claude-code** | Claude Code | plugin.json, hooks/, commands/, skills/, scripts/ | Sleep 技能 + 会话结束钩子 + cron 调度 |
| **codex** | OpenAI Codex | install.sh/ps1, skills/ | Sleep 技能 + 安装脚本 |
| **copilot** | GitHub Copilot | mcp_server.py, copilot-instructions.snippet.md | MCP 服务器 + 指令片段 |
| **cursor** | Cursor IDE | plugin.json, install.sh/ps1, commands/, skills/ | Sleep 命令 + 技能 |
| **devin** | Devin AI | mcp_server.py, harvest_devin.py, judge.py, hooks/ | 会话结束钩子 + 转录收割 + MCP |
| **dsh** | DSH | package.json, src/index.js, scripts/, skills/ | Node.js 集成 + 审计脚本 |
| **openclaw** | OpenClaw | SKILL.md, run_sleep.py, config.json | 参考适配 + cron 运行 |

### 5.2 通用 Sleep 运行脚本

```
plugins/
├── run-sleep.sh       # Unix 通用脚本
├── run-sleep.ps1      # PowerShell 版本
└── run-sleep.cmd      # CMD 版本
```

---

## 6. 配置系统

### 6.1 配置层级

```
configs/
├── _base_/default.yaml           # 基础配置（所有 benchmark 继承）
├── alfworld/default.yaml         # ALFWorld 特定配置
├── docvqa/default.yaml           # DocVQA 特定配置
├── livemathematicianbench/       # LiveMath 特定配置
├── officeqa/default.yaml         # OfficeQA 特定配置
├── searchqa/default.yaml         # SearchQA 特定配置
├── spreadsheetbench/default.yaml # SpreadsheetBench 特定配置
└── features/soft_gate.yaml       # 特征配置 (soft gate)
```

### 6.2 主要配置项

- **model** — 后端选择、模型名称、推理力度、各后端的详细参数（Azure, Qwen, MiniMax, Copilot, Codex, Cursor 等）
- **train** — epoch 数、训练集大小、batch size、累积步数、随机种子
- **gradient** — minibatch 大小、合并批大小、分析师并行数、failure_only 模式
- **optimizer** — 学习率、调度器、控制模式、更新模式、慢更新、元技能、EmbodiSkill
- **evaluation** — 门控开关、验证/测试环境数
- **env** — 环境名、技能初始化、split 模式、数据路径、超时

---

## 7. 测试体系

### 7.1 测试统计

| 指标 | 数值 |
|---|---|
| 测试文件 | 89 |
| 测试函数 | 1,466 |
| 最大测试文件 | `test_sleep_engine.py` (3,680 行) |

### 7.2 测试覆盖范围

**核心框架测试**：
- `test_scoring.py` — 评分逻辑
- `test_json_utils.py` — JSON 工具
- `test_types.py` — 类型系统
- `test_mcp_schema.py` — MCP schema
- `test_hierarchical_merge.py` — 层次化合并
- `test_semantic_density.py` — 语义密度
- `test_optimizer_feedback_flow.py` — 优化器反馈流
- `test_unmatched_edits_reporting.py` — 未匹配编辑报告

**后端测试**：
- `test_claude_code_backend.py` / `test_claude_backend_tempdir.py`
- `test_copilot_exec_backend.py` / `test_copilot_tool_scope.py` / `test_copilot_harvest.py`
- `test_cursor_exec_backend.py`
- `test_qwen_backend.py` / `test_minimax_backend.py` / `test_minimax_region.py`
- `test_backend_opencode.py` / `test_backend_opencode_live.py`
- `test_openai_compatible_config.py`

**Sleep 模块测试**：
- `test_sleep_engine.py` (3,680 行) — Sleep 引擎完整测试
- `test_sleep_state.py` — 状态管理
- `test_sleep_multi_skill.py` — 多技能
- `test_sleep_skill_resolver.py` / `test_sleep_skill_hint.py`
- `test_sleep_dream_metric.py` — Dream 指标
- `test_sleep_adopt_skill_subset.py` (2,282 行) — 子集采用
- `test_sleep_skill_group_report.py` — 技能组报告
- `test_run_sleep_fallback.py` — 回退逻辑

**Harvest 测试**：
- `test_harvest_opencode_live.py` / `test_harvest_project_scope.py`
- `test_harvest_copilot_cli.py`
- `test_harvest_pi.py`
- `test_harvest_race.py` — 竞争条件

**WebUI 测试**：
- `test_webui_build_gradio.py` — Gradio 构建
- `test_webui_env_preflight.py` — 环境预检
- `test_webui_security.py` — 安全测试

**安全与鲁棒性测试**：
- `test_split_hardening_2x3.py`
- `test_executor_env_isolation.py`
- `test_console_encoding.py`
- `test_workspace_symlink.py`
- `test_latest_pointer_race.py`
- `test_superpowers_scenarios.py` (1,201 行)
- `test_systematic_debugging_scenarios.py`

---

## 8. CI/CD 与质量保证

### 8.1 GitHub Actions CI

三个并行 job：

| Job | 矩阵 | 内容 |
|---|---|---|
| **test** | Python 3.10 / 3.11 / 3.12 | 核心 pytest 套件 |
| **webui** | Gradio 5.50.0 / 6.26.0 | WebUI 主题兼容性测试 |
| **docs** | Python 3.11 | MkDocs 严格构建 |

安全实践：
- GitHub Actions 固定到完整 commit SHA（非 tag）
- Dependabot 自动依赖更新
- Live backend 测试通过环境变量门控（CI 中关闭）

### 8.2 代码质量

- **Ruff** 作为 linter/formatter
  - 行宽 120
  - 目标 Python 3.10
  - 规则：E, F, I (isort), W
  - 忽略 E501（行长度）

---

## 9. 文档体系

### 9.1 文档站点 (MkDocs Material)

```
docs/
├── index.md                    # 首页
├── contributing.md             # 贡献指南
├── review_guidelines.md        # 代码审查指南
├── guideline.html              # 渲染后的文档与复现指南
├── guide/
│   ├── installation.md         # 安装指南
│   ├── first-experiment.md     # 首次实验
│   ├── configuration.md        # 配置说明
│   ├── training-loop.md        # 训练循环详解
│   ├── skill-document.md       # 技能文档格式
│   ├── dl-analogy.md           # 深度学习类比
│   ├── new-backend.md          # 添加新后端
│   ├── new-benchmark.md        # 添加新 benchmark
│   └── local-env-smoke.md      # 本地环境冒烟测试
├── reference/
│   ├── api.md                  # API 参考
│   ├── cli.md                  # CLI 参考
│   └── config.md               # 配置参考
├── sleep/
│   ├── README.md               # Sleep 概述
│   ├── evalkit.md              # 配对 A/B 评估工具包
│   ├── multi-skill-staging.md  # 多技能 staging
│   ├── openai-compatible-endpoints.md  # OpenAI 兼容端点
│   ├── RESULTS.md              # 实验结果
│   └── examples/               # 示例脚本 (runner.py, watchdog.py)
└── superpowers/
    ├── SECURITY.md             # Superpowers 安全文档
    └── specs/                  # 设计规格
```

### 9.2 技术博客

- `blog/gating-reflection-safe-updates/` — 门控反思与安全更新的技术分析

### 9.3 其他文档

- `CHANGELOG.md` — 详细的版本变更记录
- `CONTRIBUTING.md` — 贡献指南
- `SECURITY.md` — Microsoft 安全策略
- `README.md` — 项目概述（含新闻、概览、引用）
- 各 `plugins/*/README.md` — 插件特定文档

---

## 10. 依赖分析

### 10.1 核心依赖

| 包 | 版本要求 | 用途 |
|---|---|---|
| `openai` | ≥1.30.0 | OpenAI API 客户端 |
| `pyyaml` | ≥6.0 | YAML 配置解析 |
| `numpy` | ≥1.24.0 | 数值计算 |
| `openpyxl` | ≥3.1.0 | Excel 文件处理 (SpreadsheetBench) |
| `azure-identity` | ≥1.15.0 | Azure 认证 |
| `azure-core` | ≥1.30.0 | Azure 核心库 |
| `httpx` | ≥0.27.0 | HTTP 客户端 |

### 10.2 可选依赖

| Extra | 包 | 用途 |
|---|---|---|
| `alfworld` | alfworld, gymnasium | ALFWorld benchmark |
| `claude` | claude-agent-sdk, json_repair | Claude 后端 |
| `qwen` | vllm, json_repair | Qwen 本地模型 |
| `searchqa` | datasets | SearchQA 数据物化 |
| `docs` | mkdocs-material, mkdocstrings | 文档站点 |
| `webui` | gradio ≥5.50.0,<7 | WebUI 面板 |
| `dev` | ruff, pytest | 开发工具 |

### 10.3 构建系统

- **setuptools ≥ 68.0** + **wheel**
- Python ≥ 3.10
- 5 个包：skillopt, skillopt.*, skillopt_sleep, skillopt_sleep.*, skillopt_webui, skillopt_webui.*, scripts*

---

## 11. CLI 入口

| 命令 | 入口 | 说明 |
|---|---|---|
| `skillopt-train` | `scripts.train:main` | 启动训练循环 |
| `skillopt-eval` | `scripts.eval_only:main` | 仅评估 |
| `skillopt-sleep` | `skillopt_sleep.__main__:main` | Sleep 夜间自进化 |

### Sleep CLI 子命令

```
python -m skillopt_sleep run          # 完整周期
python -m skillopt_sleep dry-run      # 仅报告
python -m skillopt_sleep status       # 显示状态
python -m skillopt_sleep adopt        # 采用提案
python -m skillopt_sleep harvest      # 调试收割
```

---

## 12. 安全设计

### 12.1 代码级安全

- **路径遍历防护** — WebUI 中所有路径经过 `_ensure_under_project()` 验证
- **命令注入防护** — PR #264 加固
- **秘密值脱敏** — staging.py 中的 `_UNQUOTED_SECRET_VALUE` 正则用于脱敏
- **JSON 加固** — 硬化 JSON 解析 (json_utils.py)
- **GitHub Actions SHA 固定** — 防止供应链攻击

### 12.2 运行时安全

- **Dreams 安全契约** — 永远不直接修改 live 文件
- **验证门控** — 只有严格改进才接受变更
- **Handoff 后端** — 每晚任务固定，回答会话无法偏移任务集
- **Skill 解析** — 不信任的字符串经过窄化解析
- **Superpowers 适配器** — 仅限可信本地技能，证据收集 tamper-evident

### 12.3 默认安全

- WebUI 默认绑定 `127.0.0.1`（仅本地）
- Live 后端测试默认关闭
- Copilot exec 需要显式 `allow_all_tools` 启用
- Sleep scope 默认 `invoked`（而非 `all`）

---

## 13. 贡献者分析

| 排名 | 贡献者 | 提交数 |
|---|---|---|
| 1 | Yifan Yang | 167 |
| 2 | Yif-Yang | 35 |
| 3 | Christopher Haugen | 34 |
| 4 | Lliar-liar | 30 |
| 5 | WODE25500 | 25 |
| 6 | Yif Yang | 22 |
| 7 | Cuzyoung | 21 |
| 8 | NovusEdge | 18 |
| 9 | carpedkm | 17 |
| 10 | Dan Baciu | 15 |

核心团队为微软研究院的 Yifan Yang 等人，社区贡献活跃（20+ 贡献者）。

---

## 14. 关键创新点

### 14.1 ReflACT — 反思式 Agent 调优

- 首次将技能文档作为可训练参数
- 6 阶段 pipeline 类比深度学习训练循环
- Minibatch 反思（类似 minibatch SGD）
- 文本学习率 + 拒绝编辑缓冲区 + 慢更新 → 稳定训练

### 14.2 SkillOpt-Sleep — 离线自进化

- 将 SkillOpt 的验证门控优化引入日常 Agent 使用
- Harvest → Mine → Replay → Consolidate → Gate → Stage 完整流水线
- Dreams 安全契约 — 从不直接修改 live 文件
- Dream rollouts + associative recall — 从好/坏对比中学习
- 多源收割（7 种 Agent 平台）
- Handoff 后端 — 零 API 成本运行

### 14.3 EmbodiSkill 集成

- 技能感知反思 — 区分 SKILL_DEFECT vs EXECUTION_LAPSE
- 保护区附录字段 — 只强调已有规则，不引入新规则
- 与 slow_update 保护区并列的双保护区架构

### 14.4 跨平台可移植性

- 优化后的技能跨模型规模迁移
- 跨 Codex / Claude Code harness 迁移
- 跨相邻 benchmark 迁移（无需额外优化）

---

## 15. 项目成熟度评估

| 维度 | 评级 | 说明 |
|---|---|---|
| 代码质量 | ⭐⭐⭐⭐ | 类型注解完整，模块化清晰，安全加固到位 |
| 测试覆盖 | ⭐⭐⭐⭐⭐ | 1,466 个测试函数覆盖所有核心模块 |
| 文档完整度 | ⭐⭐⭐⭐ | MkDocs 文档站 + 技术博客 + CHANGELOG + 多语言 README |
| CI/CD | ⭐⭐⭐⭐ | 多 Python 版本 + 多 Gradio 版本 + 严格文档构建 |
| 安全性 | ⭐⭐⭐⭐⭐ | 多层安全设计（路径验证、门控、Dreams 契约、SHA 固定） |
| 可扩展性 | ⭐⭐⭐⭐⭐ | 插件系统 + EnvAdapter 抽象 + 多后端路由 + 配置继承 |
| 社区活跃度 | ⭐⭐⭐⭐ | 20+ 贡献者，575 提交，被多个外部项目集成 |
| 学术支撑 | ⭐⭐⭐⭐⭐ | 正式论文 (arXiv)，Microsoft Research 官方报道 |

---

## 16. 总结

**SkillOpt** 是一个设计精良、工程成熟的研究级框架，将深度学习训练的方法论系统性地引入到 Agent 技能优化领域。其核心贡献在于：

1. **理论创新** — 将技能文档类比为可训练参数，建立了完整的"训练循环"范式
2. **工程实现** — 高度模块化、可扩展的架构，支持 6 个 benchmark 和 10+ 模型后端
3. **实用工具** — Sleep 模块将研究突破转化为日常可用的自进化工具
4. **安全设计** — 多层验证门控确保优化过程的安全性和可控性
5. **生态建设** — 7 个 Agent 平台插件 + WebUI + 完整文档 + 活跃社区

项目从 2026-05 启动到 2026-10 已达 v0.2.0，发展迅速且质量稳定，是 Agent 技能优化领域的重要开源贡献。

---

## 附录 A：提示词体系

项目的提示词管理采用 Markdown 文件注册表模式：

### 核心包提示词 (`skillopt/prompts/`)
- 20+ 个 `.md` 提示词文件，覆盖：
  - **Analyst 提示词** — 失败/成功分析师
  - **Merge 提示词** — 层次化合并
  - **Rewrite 提示词** — 全技能重写
  - **Slow-update 提示词** — 慢更新指导
  - **Meta-skill 提示词** — 元技能记忆
  - **Ranking 提示词** — 编辑排序

### Sleep 模块提示词 (`skillopt_sleep/prompts.py`)
- 集中式提示词注册表 (250 行)
- 支持用户运行时覆盖
- WebUI 面板可实时展示和修改

### 环境特定提示词 (`skillopt/envs/<benchmark>/prompts/`)
- 每个 benchmark 有自己定制的反思提示词模板
- 两级优先解析：环境自定义 > 通用默认

---

## 附录 B：数据管理

### 预分片数据 (`data/`)

| 数据集 | Split 类型 | 目录 |
|---|---|---|
| ALFWorld | path-based split | `alfworld_path_split/` |
| DocVQA | ID-based split | `docvqa_id_split/` |
| LiveMathematicianBench | ID-based split | `livemathematicianbench_id_split/` |
| OfficeQA | ID-based split | `officeqa_id_split/` |
| SearchQA | ID-based split | `searchqa_id_split/` |
| SpreadsheetBench | ID-based split | `spreadsheetbench_id_split/` |

每个 split 目录包含 `train/`, `val/`, `test/` 子目录，内含 `split_manifest.json` + `items.json`。

大型原始数据目录被 gitignore（`BabyVision/`, `MMRB/`, `SpreadsheetBench/`, `dl4ir-searchQA/`）。

### 检查点管理 (`ckpt/`)
- 按 benchmark 组织的检查点目录
- 训练可恢复：`runtime_state.json` + `history.json` + `skills/skill_vNNNN.md` 版本化

---

## 附录 C：高级特性详解

### C.1 EmbodiSkill 技能感知反思

将反思分为两类：
- **SKILL_DEFECT** — 技能文档本身有缺陷，需要修改技能主体 (body)
- **EXECUTION_LAPSE** — 技能规则正确但执行者未遵循，写入保护区附录 (appendix)

附录字段 (`appendix.py`) 与慢更新保护区并列，形成**双保护区架构**。

### C.2 语义密度门控

`evaluation/gate.py` 中的 `compute_semantic_density()` 对候选技能进行语义密度正则化，防止技能文档膨胀。

### C.3 纵向配对策略

`longitudinal_pair_policy` 控制 epoch 间比较的样本对构建方式：
- `mixed` — 混合使用变更/未变更样本
- `changed` — 仅使用性能变化的样本
- `unchanged` — 仅使用性能未变的样本

### C.4 学习率控制模式

- `fixed` — 由 scheduler.py 中的 cosine/linear/constant 调度
- `autonomous` — LLM 自主决定每步的编辑预算 (`lr_autonomous.py`)
- `none` — 不施加学习率控制

### C.5 技能更新模式

- `patch` — 有界 add/delete/replace 编辑（默认）
- `rewrite_from_suggestions` — 基于选中建议的全技能重写
- `full_rewrite_minibatch` — 整个 minibatch 的全重写

### C.6 Handoff 后端

独特的零 API 成本运行模式：
1. 引擎执行确定性阶段，将每个模型调用记录为待回答的提示
2. 写入 `PROMPTS.md` + `pending.json`
3. 用户在**新鲜上下文**中回答每个提示（防止历史污染 held-out gate）
4. 重新运行时从 `answers/` 目录恢复
5. 通常每晚 3-6 轮交互

---

## 附录 D：完整文件行数 TOP 20

| 排名 | 文件 | 行数 | 功能 |
|---|---|---|---|
| 1 | `tests/test_sleep_engine.py` | 3,680 | Sleep 引擎测试 |
| 2 | `skillopt_sleep/staging.py` | 3,161 | Staging 与采用 |
| 3 | `skillopt_sleep/backend.py` | 2,603 | 统一后端接口 |
| 4 | `skillopt/engine/trainer.py` | 2,535 | 训练循环主控 |
| 5 | `tests/test_sleep_adopt_skill_subset.py` | 2,282 | 子集采用测试 |
| 6 | `skillopt/model/codex_harness.py` | 2,036 | Codex 执行基础设施 |
| 7 | `skillopt_sleep/adapters/superpowers.py` | 1,379 | Superpowers 适配器 |
| 8 | `tests/test_superpowers_scenarios.py` | 1,201 | Superpowers 场景测试 |
| 9 | `tests/test_backend_opencode.py` | 1,198 | OpenCode 后端测试 |
| 10 | `tests/test_harvest_opencode.py` | 1,135 | OpenCode 收割测试 |
| 11 | `skillopt_sleep/cycle.py` | 1,105 | Sleep 周期编排 |
| 12 | `skillopt/envs/spreadsheetbench/rollout.py` | 1,060 | SpreadsheetBench rollout |
| 13 | `skillopt_sleep/__main__.py` | 932 | Sleep CLI |
| 14 | `skillopt/model/azure_openai.py` | 915 | Azure OpenAI 后端 |
| 15 | `scripts/train.py` | 866 | 训练入口 |
| 16 | `tests/test_copilot_exec_backend.py` | 860 | Copilot exec 测试 |
| 17 | `skillopt/model/__init__.py` | 827 | 模型注册表 |
| 18 | `skillopt_webui/app.py` | 814 | WebUI 应用 |
| 19 | `tests/test_codex_config_aliases.py` | 809 | Codex 配置别名测试 |
| 20 | `skillopt_sleep/evalkit.py` | 718 | 配对 A/B 评估 |
