# 🚀 立即运行 - 快速指南

## 当前状态

✅ 环境已验证 (dry-run 通过)  
⚠️  API 密钥未设置

## 立即运行 (3 步)

### 步骤 1: 获取 API 密钥

**选项 A: OpenAI (推荐)**
1. 访问: https://platform.openai.com/api-keys
2. 创建新密钥
3. 复制密钥 (格式: `sk-xxx`)

**选项 B: OpenRouter**
1. 访问: https://openrouter.ai/keys
2. 创建新密钥
3. 复制密钥

### 步骤 2: 设置密钥并运行

**方式 1: 命令行设置 (推荐)**
```bash
cd /home/wangwei/wei/workspacePy/rsi/hermes-agent-self-evolution-ext/deploy

# 设置密钥 (替换为你的密钥)
export OPENAI_API_KEY=sk-your-key-here

# 运行优化
./run_example.sh --actual
```

**方式 2: 单行命令**
```bash
OPENAI_API_KEY=sk-your-key-here ./run_example.sh --actual
```

**方式 3: 使用 OpenRouter**
```bash
export OPENROUTER_API_KEY=your-key-here
./run_example.sh --actual
```

**方式 4: 交互式运行**
```bash
./run_interactive.sh
# 然后按提示输入密钥
```

### 步骤 3: 查看结果

```bash
# 查看最新结果
ls -lt output/demo-skill/ | head -5

# 查看性能指标
cat output/demo-skill/*/metrics.json | python3 -m json.tool

# 查看优化后的技能
cat output/demo-skill/*/evolved_skill.md

# 比较差异
diff output/demo-skill/*/baseline_skill.md output/demo-skill/*/evolved_skill.md
```

## 预期输出

运行成功后,你会看到类似这样的输出:

```
🧬 Hermes Agent Self-Evolution — Evolving skill: demo-skill

  Loaded: skills/demo/demo-skill/SKILL.md
  Name: demo-skill
  Size: 889 chars
  
Building evaluation dataset (source: synthetic)
  Generated 20 synthetic examples
  Saved to datasets/skills/demo-skill/
  Split: 10 train / 5 val / 5 holdout

Configuring optimizer
  Optimizer: GEPA (5 iterations)
  Optimizer model: openai/gpt-4.1-mini
  Eval model: openai/gpt-4.1-mini

Running GEPA optimization (5 iterations)...

  Optimization completed in 45.2s

Validating evolved skill
  ✓ size_limit: Size OK: 956/15000 chars
  ✓ growth_limit: Growth OK: +7.5% (max +20.0%)
  ✓ non_empty: Artifact is non-empty
  ✓ skill_structure: Skill has valid frontmatter

Evaluating on holdout set (5 examples)

┌──────────────────┬──────────┬─────────┬─────────┐
│ Metric           │ Baseline │ Evolved │ Change  │
├──────────────────┼──────────┼─────────┼─────────┤
│ Holdout Score    │ 0.391    │ 0.472   │ +0.081  │
│ Skill Size       │ 889      │ 956     │ +67     │
│ Time             │          │ 45.2s   │         │
│ Iterations       │          │ 5       │         │
└──────────────────┴──────────┴─────────┴─────────┘

✓ Evolution improved skill by +0.081 (+20.7%)
  Output saved to output/demo-skill/20261018_123456/
```

## 成本估算

| 模式 | 成本 | 时间 |
|------|------|------|
| Dry-run | $0 | < 5 秒 |
| Actual (5 迭代) | ~$0.50 | < 60 秒 |

## 故障排除

### "API key not valid"
```bash
# 验证密钥
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"
```

### "Insufficient quota"
检查 OpenAI 账户余额: https://platform.openai.com/account/billing

### 运行太慢
使用更便宜的模型:
```bash
./run_example.sh --actual
# 编辑脚本,将 gpt-4.1-mini 改为 gpt-3.5-turbo
```

## 下一步

运行成功后:
1. 查看 `output/demo-skill/*/metrics.json` 了解性能
2. 查看 `output/demo-skill/*/evolved_skill.md` 了解改进
3. 尝试优化自己的技能
4. 阅读 `../ANALYSIS.md` 了解更多

---

**准备好了吗?** 复制下面的命令并运行:

```bash
cd /home/wangwei/wei/workspacePy/rsi/hermes-agent-self-evolution-ext/deploy
export OPENAI_API_KEY=sk-your-key-here
./run_example.sh --actual
```
