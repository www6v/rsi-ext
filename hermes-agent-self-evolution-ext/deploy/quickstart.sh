#!/bin/bash
# ============================================================================
# Quick Start - Run evolution example in one command
# ============================================================================
#
# This is a simplified wrapper that runs the example with sensible defaults.
#
# Usage:
#   ./quickstart.sh          # Run dry-run (safe, no API needed)
#   OPENAI_API_KEY=xxx ./quickstart.sh actual    # Run actual optimization
#
# ============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-dry-run}"

cd "$SCRIPT_DIR"

if [ "$MODE" = "actual" ]; then
    echo "Running actual optimization..."
    ./run_example.sh --actual
else
    echo "Running dry-run validation..."
    ./run_example.sh
fi
