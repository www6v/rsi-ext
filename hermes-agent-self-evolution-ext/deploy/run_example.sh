#!/bin/bash
# ============================================================================
# Hermes Agent Self-Evolution - Example Run Script
# ============================================================================
#
# This script demonstrates how to run the evolution pipeline on a demo skill.
# It performs a dry-run first to validate the setup, then optionally runs
# the actual optimization.
#
# Usage:
#   ./run_example.sh              # Run dry-run (default, safe)
#   ./run_example.sh --actual     # Run actual optimization (requires API keys)
#   ./run_example.sh --help       # Show help
#
# ============================================================================

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEMO_REPO="${SCRIPT_DIR}/demo-hermes-repo"

# ============================================================================
# Helper functions
# ============================================================================

print_header() {
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

show_help() {
    cat << 'EOF'
Hermes Agent Self-Evolution - Example Runner

Usage:
  ./run_example.sh [OPTIONS]

Options:
  --actual        Run actual optimization (requires API keys)
  --help          Show this help message

Examples:
  ./run_example.sh              # Safe dry-run to validate setup
  ./run_example.sh --actual     # Run actual optimization

What this script does:
  1. Checks Python environment and dependencies
  2. Validates demo hermes-agent repo structure
  3. Runs dry-run or actual optimization on demo-skill
  4. Reports results

For actual optimization, you need:
  - OpenAI API key or OpenRouter API key
  - Set OPENAI_API_KEY or OPENROUTER_API_KEY environment variable

EOF
}

# ============================================================================
# Main script
# ============================================================================

# Parse arguments
RUN_ACTUAL=false
for arg in "$@"; do
    case $arg in
        --actual)
            RUN_ACTUAL=true
            shift
            ;;
        --help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $arg"
            show_help
            exit 1
            ;;
    esac
done

print_header "Hermes Agent Self-Evolution - Example Runner"
echo ""

# Step 1: Check Python environment
print_info "Step 1: Checking Python environment..."
if ! command -v python3 &> /dev/null; then
    print_error "Python3 not found. Please install Python 3.10+"
    exit 1
fi

PYTHON_VERSION=$(python3 --version | awk '{print $2}')
print_success "Python version: $PYTHON_VERSION"

# Check if required packages are installed
if ! python3 -c "import dspy" 2>/dev/null; then
    print_error "DSPy not installed. Run: pip install -e ."
    exit 1
fi
print_success "DSPy installed"

if ! python3 -c "import click, rich, yaml" 2>/dev/null; then
    print_error "Required packages not installed. Run: pip install -e ."
    exit 1
fi
print_success "All dependencies installed"
echo ""

# Step 2: Validate demo repo
print_info "Step 2: Validating demo hermes-agent repo..."
if [ ! -d "$DEMO_REPO" ]; then
    print_error "Demo repo not found: $DEMO_REPO"
    exit 1
fi
print_success "Demo repo exists"

if [ ! -f "$DEMO_REPO/skills/demo/demo-skill/SKILL.md" ]; then
    print_error "Demo skill not found: $DEMO_REPO/skills/demo/demo-skill/SKILL.md"
    exit 1
fi
print_success "Demo skill exists"

SKILL_SIZE=$(wc -c < "$DEMO_REPO/skills/demo/demo-skill/SKILL.md")
print_success "Skill size: $SKILL_SIZE bytes"
echo ""

# Step 3: Run evolution
cd "${SCRIPT_DIR}/.."  # Go to hermes-agent-self-evolution-main

if [ "$RUN_ACTUAL" = true ]; then
    print_header "Running Actual Optimization"
    echo ""

    # Check for API keys
    if [ -z "$OPENAI_API_KEY" ] && [ -z "$OPENROUTER_API_KEY" ]; then
        print_warning "No API key found. Set OPENAI_API_KEY or OPENROUTER_API_KEY"
        print_info "You can get an OpenRouter key at: https://openrouter.ai/keys"
        echo ""
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Aborted. Set API key and try again."
            exit 0
        fi
    fi

    print_info "Running evolution on demo-skill..."
    print_info "This will:"
    print_info "  - Generate synthetic evaluation dataset"
    print_info "  - Run GEPA optimization (5 iterations)"
    print_info "  - Evaluate baseline vs evolved skill"
    print_info "  - Save results to output/"
    echo ""

    python3 -m evolution.skills.evolve_skill \
        --skill demo-skill \
        --hermes-repo "$DEMO_REPO" \
        --iterations 5 \
        --eval-source synthetic \
        --optimizer-model "openai/gpt-4.1-mini" \
        --eval-model "openai/gpt-4.1-mini" \
        --dry-run=false

    EXIT_CODE=$?

    if [ $EXIT_CODE -eq 0 ]; then
        echo ""
        print_success "Optimization completed successfully!"
        print_info "Check output/demo-skill/ for results"
    else
        echo ""
        print_error "Optimization failed with exit code: $EXIT_CODE"
        exit $EXIT_CODE
    fi

else
    print_header "Running Dry-Run Validation"
    echo ""
    print_info "This will validate the setup without running actual optimization."
    print_info "No API keys required."
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
        print_success "Dry-run completed successfully!"
        print_info "Setup is valid. You can now run with --actual to perform optimization."
    else
        echo ""
        print_error "Dry-run failed with exit code: $EXIT_CODE"
        exit $EXIT_CODE
    fi
fi

echo ""
print_header "Summary"
echo ""
print_success "Demo skill: $DEMO_REPO/skills/demo/demo-skill/SKILL.md"
print_success "Hermes repo: $DEMO_REPO"

if [ "$RUN_ACTUAL" = true ]; then
    print_success "Output directory: output/demo-skill/"
    print_info "Next steps:"
    print_info "  1. Review evolved skill: cat output/demo-skill/*/evolved_skill.md"
    print_info "  2. Compare with baseline: diff output/demo-skill/*/baseline_skill.md output/demo-skill/*/evolved_skill.md"
    print_info "  3. Check metrics: cat output/demo-skill/*/metrics.json"
else
    print_info "Next steps:"
    print_info "  1. Set API key: export OPENAI_API_KEY=your-key"
    print_info "  2. Run actual optimization: ./run_example.sh --actual"
fi

echo ""
print_success "Done!"
echo ""
