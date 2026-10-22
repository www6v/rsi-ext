#!/bin/bash
# ============================================================================
# Run Evolution with Qwen API (DashScope)
# ============================================================================
#
# 使用阿里云通义千问 (Qwen) API 运行进化优化
# 不修改 hermes-agent-self-evolution-main 的任何代码
#
# 用法:
#   ./run_with_qwen.sh                    # 交互式输入 API key
#   DASHSCOPE_API_KEY=xxx ./run_with_qwen.sh  # 使用环境变量
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DEMO_REPO="$SCRIPT_DIR/demo-hermes-repo"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}Hermes Agent Self-Evolution — 使用 Qwen (通义千问) API${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo ""

# Step 1: 检查 API Key
if [ -z "$DASHSCOPE_API_KEY" ]; then
    echo -e "${YELLOW}⚠  未设置 DASHSCOPE_API_KEY 环境变量${NC}"
    echo ""
    echo "获取 API Key:"
    echo "  1. 访问: https://dashscope.console.aliyun.com/apiKey"
    echo "  2. 创建 API Key"
    echo "  3. 复制 Key (格式: sk-xxx)"
    echo ""
    read -sp "请输入 DashScope API Key: " DASHSCOPE_API_KEY
    echo ""
    export DASHSCOPE_API_KEY
fi

if [ -z "$DASHSCOPE_API_KEY" ]; then
    echo "✗ 未提供 API Key,退出"
    exit 1
fi

echo -e "${GREEN}✓ DashScope API Key 已设置${NC}"

# Step 2: 选择模型
echo ""
echo "可用的 Qwen 模型:"
echo "  1) qwen-turbo      (快速, 便宜, 适合测试)"
echo "  2) qwen-plus       (均衡, 推荐)"
echo "  3) qwen-max        (最强, 较贵)"
echo ""
read -p "选择模型 [1-3, 默认 2]: " model_choice

case ${model_choice:-2} in
    1) QWEN_MODEL="qwen-turbo" ;;
    2) QWEN_MODEL="qwen-plus" ;;
    3) QWEN_MODEL="qwen-max" ;;
    *) QWEN_MODEL="qwen-plus" ;;
esac

echo -e "${GREEN}✓ 使用模型: $QWEN_MODEL${NC}"

# Step 3: 配置 LiteLLM 使用 DashScope 的 OpenAI 兼容端点
# 这样 DSPy 的 openai/ 前缀就能路由到 Qwen
export OPENAI_API_KEY="$DASHSCOPE_API_KEY"
export OPENAI_API_BASE="https://dashscope.aliyuncs.com/compatible-mode/v1"

echo -e "${GREEN}✓ API Base: https://dashscope.aliyuncs.com/compatible-mode/v1${NC}"

# Step 4: 选择运行模式
echo ""
echo "运行模式:"
echo "  1) Dry-run (验证设置, 不消耗 token)"
echo "  2) 实际优化 (消耗 token, 产生费用)"
echo ""
read -p "选择模式 [1-2, 默认 1]: " mode_choice

echo ""
echo -e "${BLUE}================================================================================${NC}"
echo -e "${BLUE}运行配置${NC}"
echo -e "${BLUE}================================================================================${NC}"
echo "API 提供商: 阿里云 DashScope (通义千问)"
echo "模型: $QWEN_MODEL"
echo "技能: demo-skill"
echo "Hermes Repo: $DEMO_REPO"
echo ""

cd "$PROJECT_DIR"

if [ "${mode_choice:-1}" = "2" ]; then
    echo -e "${BLUE}开始实际优化...${NC}"
    echo ""

    python3 -m evolution.skills.evolve_skill \
        --skill demo-skill \
        --hermes-repo "$DEMO_REPO" \
        --iterations 5 \
        --eval-source synthetic \
        --optimizer-model "openai/$QWEN_MODEL" \
        --eval-model "openai/$QWEN_MODEL"

    EXIT_CODE=$?
else
    echo -e "${BLUE}运行 Dry-Run 验证...${NC}"
    echo ""

    python3 -m evolution.skills.evolve_skill \
        --skill demo-skill \
        --hermes-repo "$DEMO_REPO" \
        --iterations 5 \
        --eval-source synthetic \
        --dry-run

    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓ Dry-run 通过! 设置正确。${NC}"
        echo ""
        echo "重新运行并选择模式 2 以执行实际优化。"
        echo ""
        echo "或者直接运行:"
        echo "  DASHSCOPE_API_KEY=xxx OPENAI_API_BASE=https://dashscope.aliyuncs.com/compatible-mode/v1 \\"
        echo "    python3 -m evolution.skills.evolve_skill \\"
        echo "      --skill demo-skill \\"
        echo "      --hermes-repo $DEMO_REPO \\"
        echo "      --iterations 5 \\"
        echo "      --optimizer-model openai/$QWEN_MODEL \\"
        echo "      --eval-model openai/$QWEN_MODEL"
    fi
fi

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ 完成!${NC}"
else
    echo "✗ 失败 (exit code: $EXIT_CODE)"
fi
echo ""
