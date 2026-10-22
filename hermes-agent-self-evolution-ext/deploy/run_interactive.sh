#!/bin/bash
# ============================================================================
# Interactive Runner - 交互式运行示例
# ============================================================================
#
# 这个脚本会引导你设置 API 密钥并运行优化
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "================================================================================"
echo "Hermes Agent Self-Evolution - 交互式运行器"
echo "================================================================================"
echo ""

# 检查 API 密钥
if [ -z "$OPENAI_API_KEY" ] && [ -z "$OPENROUTER_API_KEY" ]; then
    echo "⚠  未检测到 API 密钥"
    echo ""
    echo "请选择 API 提供商:"
    echo "  1) OpenAI (https://platform.openai.com/api-keys)"
    echo "  2) OpenRouter (https://openrouter.ai/keys)"
    echo "  3) 跳过,仅运行 dry-run"
    echo ""
    read -p "请选择 [1-3]: " choice

    case $choice in
        1)
            echo ""
            read -sp "请输入 OpenAI API 密钥: " OPENAI_API_KEY
            echo ""
            export OPENAI_API_KEY
            PROVIDER="OpenAI"
            MODEL="openai/gpt-4.1-mini"
            ;;
        2)
            echo ""
            read -sp "请输入 OpenRouter API 密钥: " OPENROUTER_API_KEY
            echo ""
            export OPENROUTER_API_KEY
            PROVIDER="OpenRouter"
            MODEL="openrouter/google/gemini-2.5-flash"
            ;;
        3)
            echo ""
            echo "ℹ  运行 dry-run 模式..."
            ./run_example.sh
            exit 0
            ;;
        *)
            echo "✗ 无效选择"
            exit 1
            ;;
    esac
else
    if [ -n "$OPENAI_API_KEY" ]; then
        PROVIDER="OpenAI"
        MODEL="openai/gpt-4.1-mini"
        echo "✓ 使用 OpenAI API"
    else
        PROVIDER="OpenRouter"
        MODEL="openrouter/google/gemini-2.5-flash"
        echo "✓ 使用 OpenRouter API"
    fi
fi

echo ""
echo "================================================================================"
echo "运行配置"
echo "================================================================================"
echo "API 提供商: $PROVIDER"
echo "模型: $MODEL"
echo "迭代次数: 5"
echo "评估来源: synthetic"
echo ""

read -p "是否继续运行实际优化? [y/N]: " confirm
if [[ ! $confirm =~ ^[Yy]$ ]]; then
    echo "ℹ  已取消"
    exit 0
fi

echo ""
echo "================================================================================"
echo "开始优化"
echo "================================================================================"
echo ""

# 运行优化
python3 -m evolution.skills.evolve_skill \
    --skill demo-skill \
    --hermes-repo "$SCRIPT_DIR/demo-hermes-repo" \
    --iterations 5 \
    --eval-source synthetic \
    --optimizer-model "$MODEL" \
    --eval-model "$MODEL"

EXIT_CODE=$?

echo ""
echo "================================================================================"
echo "优化完成"
echo "================================================================================"

if [ $EXIT_CODE -eq 0 ]; then
    echo "✓ 优化成功完成!"
    echo ""
    echo "结果位置: output/demo-skill/"
    echo ""

    # 查找最新的结果目录
    LATEST_DIR=$(ls -t output/demo-skill/ 2>/dev/null | head -1)
    if [ -n "$LATEST_DIR" ]; then
        echo "最新结果: output/demo-skill/$LATEST_DIR/"
        echo ""

        if [ -f "output/demo-skill/$LATEST_DIR/metrics.json" ]; then
            echo "性能指标:"
            cat "output/demo-skill/$LATEST_DIR/metrics.json" | python3 -m json.tool
            echo ""
        fi

        echo "查看 evolved skill:"
        echo "  cat output/demo-skill/$LATEST_DIR/evolved_skill.md"
        echo ""
        echo "比较差异:"
        echo "  diff output/demo-skill/$LATEST_DIR/baseline_skill.md output/demo-skill/$LATEST_DIR/evolved_skill.md"
    fi
else
    echo "✗ 优化失败 (exit code: $EXIT_CODE)"
    exit $EXIT_CODE
fi

echo ""
echo "✓ 完成!"
echo ""
