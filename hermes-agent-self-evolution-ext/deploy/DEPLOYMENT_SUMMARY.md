# ✅ Example Successfully Deployed

## 目标完成

已成功在 `hermes-agent-self-evolution-ext/deploy` 中创建并测试了一个完整的示例运行环境。

## 📦 部署内容

```
deploy/
├── README.md                          # 详细使用文档
├── run_example.sh                     # 主运行脚本 (综合版)
├── quickstart.sh                      # 快速启动脚本 (简化版)
└── demo-hermes-repo/                  # 演示用 hermes-agent 仓库
    └── skills/
        └── demo/
            └── demo-skill/
                └── SKILL.md           # 演示技能文件
```

## 🎯 测试结果

### ✅ Dry-Run 测试通过

```
✓ Python version: 3.12.3
✓ DSPy installed
✓ All dependencies installed
✓ Demo repo exists
✓ Demo skill exists
✓ Skill size: 889 bytes
✓ Dry-run completed successfully!
```

**状态:** 所有验证通过,可以运行实际优化

## 🚀 快速开始

### 方式 1: 安全测试 (推荐先运行)

```bash
cd /home/wangwei/wei/workspacePy/rsi/hermes-agent-self-evolution-ext/deploy
./run_example.sh
```

**输出:**
- 验证 Python 环境
- 检查依赖安装
- 验证 demo 仓库结构
- 测试 CLI 命令
- **不需要 API 密钥**

### 方式 2: 实际优化

```bash
# 设置 API 密钥
export OPENAI_API_KEY=your-key-here

# 运行优化
./run_example.sh --actual
```

**输出:**
- 生成合成评估数据集
- 运行 GEPA 优化 (5 次迭代)
- 评估基线 vs 进化后技能
- 保存结果到 `output/demo-skill/`

### 方式 3: 使用快速启动

```bash
# 干运行
./quickstart.sh

# 实际优化
OPENAI_API_KEY=xxx ./quickstart.sh actual
```

## 📋 演示技能

创建了一个简单的演示技能用于测试:

**位置:** `deploy/demo-hermes-repo/skills/demo/demo-skill/SKILL.md`

**内容:**
- YAML frontmatter (name, description, version)
- 使用说明
- 操作步骤
- 示例
- 注意事项

**大小:** 889 字节

## 🔧 脚本功能

### run_example.sh

**特性:**
- ✅ 彩色输出,易于阅读
- ✅ 详细的步骤提示
- ✅ 自动检查依赖
- ✅ 验证仓库结构
- ✅ 支持 dry-run 和 actual 模式
- ✅ 错误处理和提示
- ✅ 结果汇总

**命令:**
```bash
./run_example.sh              # 干运行
./run_example.sh --actual     # 实际优化
./run_example.sh --help       # 显示帮助
```

### quickstart.sh

**特性:**
- 简化版包装器
- 一行命令运行
- 适合快速测试

**命令:**
```bash
./quickstart.sh                    # 干运行
./quickstart.sh actual             # 实际优化
```

## 📊 预期输出

### Dry-Run 输出

```
✓ Dry-run completed successfully!
Setup is valid. You can now run with --actual to perform optimization.
```

### Actual 优化输出

```
output/
└── demo-skill/
    └── 20261018_123456/
        ├── baseline_skill.md      # 原始技能
        ├── evolved_skill.md       # 优化后技能
        └── metrics.json           # 性能指标
```

**metrics.json 示例:**
```json
{
  "skill_name": "demo-skill",
  "baseline_score": 0.391,
  "evolved_score": 0.472,
  "improvement": 0.081,
  "elapsed_seconds": 45.2,
  "constraints_passed": true
}
```

## 💰 成本估算

| 模式 | 迭代次数 | 估计成本 | 时间 |
|------|---------|---------|------|
| Dry-run | N/A | $0 | < 5 秒 |
| Actual (快速) | 5 | ~$0.50 | < 60 秒 |
| Actual (标准) | 10 | ~$2-5 | 2-5 分钟 |
| Actual (彻底) | 20 | ~$5-10 | 5-10 分钟 |

## 🎓 学习路径

1. **先运行 dry-run** 验证环境
   ```bash
   ./run_example.sh
   ```

2. **阅读脚本** 理解工作流程
   ```bash
   cat run_example.sh
   ```

3. **查看演示技能** 理解格式
   ```bash
   cat demo-hermes-repo/skills/demo/demo-skill/SKILL.md
   ```

4. **运行实际优化** (需要 API 密钥)
   ```bash
   export OPENAI_API_KEY=xxx
   ./run_example.sh --actual
   ```

5. **分析结果**
   ```bash
   cat output/demo-skill/*/metrics.json
   diff output/demo-skill/*/baseline_skill.md output/demo-skill/*/evolved_skill.md
   ```

## 🔍 自定义

### 使用自己的技能

1. 在 `demo-hermes-repo/skills/` 创建新技能目录
2. 添加 `SKILL.md` 文件
3. 修改脚本中的 `--skill demo-skill` 为你的技能名

### 更改模型

编辑 `run_example.sh`:
```bash
--optimizer-model "openai/gpt-4.1" \      # 更强的优化器
--eval-model "openai/gpt-4.1-mini" \      # 便宜的评估器
```

### 调整迭代次数

```bash
--iterations 3   # 快速测试
--iterations 10  # 标准
--iterations 20  # 彻底优化
```

## 🐛 故障排除

### 问题: "ModuleNotFoundError: No module named 'dspy'"

**解决:**
```bash
cd /home/wangwei/wei/workspacePy/rsi/hermes-agent-self-evolution-main
pip install -e . --break-system-packages
```

### 问题: "Cannot find hermes-agent repo"

**解决:**
脚本自动设置 `--hermes-repo`,检查:
```bash
ls -la demo-hermes-repo/skills/demo/demo-skill/SKILL.md
```

### 问题: API 密钥错误

**解决:**
```bash
# 检查环境变量
echo $OPENAI_API_KEY

# 设置密钥
export OPENAI_API_KEY=sk-xxx

# 验证密钥
curl https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY"
```

## 📚 相关文档

- **完整分析:** `../ANALYSIS.md`
- **架构图:** `../ARCHITECTURE.md`
- **代码质量:** `../CODE_QUALITY.md`
- **快速摘要:** `../SUMMARY.md`
- **部署文档:** `./README.md`

## ✨ 关键成就

✅ **完整运行环境** - 包含演示仓库、技能、脚本  
✅ **详细文档** - README、注释、故障排除  
✅ **测试验证** - Dry-run 测试通过  
✅ **易于使用** - 一键运行,彩色输出  
✅ **灵活配置** - 支持多种模型和参数  
✅ **成本透明** - 清晰的费用估算  

## 🎯 下一步

1. **运行 dry-run** 确认一切正常
   ```bash
   ./run_example.sh
   ```

2. **获取 API 密钥** 从 OpenAI 或 OpenRouter

3. **运行实际优化**
   ```bash
   export OPENAI_API_KEY=xxx
   ./run_example.sh --actual
   ```

4. **分析结果** 查看优化效果

5. **尝试自己的技能** 修改演示技能或添加新的

---

**部署日期:** 2026-10-18  
**测试状态:** ✅ Dry-run 通过  
**准备就绪:** ✅ 可以运行实际优化  
**维护者:** Claude Opus 5
