# Deploy Directory - Example Scripts

This directory contains scripts and resources for running Hermes Agent Self-Evolution examples.

## 📁 Contents

```
deploy/
├── README.md                    # This file
├── run_example.sh               # Main example runner (comprehensive)
├── quickstart.sh                # Quick start wrapper (simplified)
└── demo-hermes-repo/            # Demo hermes-agent repository
    └── skills/
        └── demo/
            └── demo-skill/
                └── SKILL.md     # Demo skill for testing
```

## 🚀 Quick Start

### Option 1: Dry-Run (Safe, No API Key Required)

```bash
cd deploy
./run_example.sh
```

This validates the setup without running actual optimization. Perfect for testing.

### Option 2: Actual Optimization (Requires API Key)

```bash
# Set your API key
export OPENAI_API_KEY=your-key-here
# or
export OPENROUTER_API_KEY=your-key-here

# Run optimization
./run_example.sh --actual
```

### Option 3: Using Quickstart

```bash
# Dry-run
./quickstart.sh

# Actual optimization
OPENAI_API_KEY=xxx ./quickstart.sh actual
```

## 📋 Prerequisites

1. **Python 3.10+** installed
2. **Dependencies installed**:
   ```bash
   cd hermes-agent-self-evolution-main
   pip install -e . --break-system-packages
   ```
   Or use a virtual environment:
   ```bash
   python3 -m venv venv
   source venv/bin/activate
   pip install -e .
   ```

3. **API Key** (for actual optimization):
   - OpenAI: https://platform.openai.com/api-keys
   - OpenRouter: https://openrouter.ai/keys

## 🎯 What the Example Does

The example runs the evolution pipeline on a demo skill:

1. **Loads the demo skill** from `demo-hermes-repo/skills/demo/demo-skill/SKILL.md`
2. **Generates synthetic evaluation dataset** using an LLM
3. **Runs GEPA optimization** to improve the skill
4. **Evaluates baseline vs evolved** on holdout examples
5. **Saves results** to `output/demo-skill/`

### Expected Output

After running with `--actual`, you'll get:

```
output/
└── demo-skill/
    └── 20261018_123456/
        ├── baseline_skill.md      # Original skill
        ├── evolved_skill.md       # Optimized skill
        └── metrics.json           # Performance metrics
```

## 🔧 Customization

### Use Your Own Skill

1. Create a skill directory in `demo-hermes-repo/skills/your-category/your-skill/`
2. Add a `SKILL.md` file with YAML frontmatter
3. Run:
   ```bash
   ./run_example.sh --actual
   # Then edit the script to change --skill demo-skill to --skill your-skill
   ```

### Use Different Models

Edit `run_example.sh` and change:
```bash
--optimizer-model "openai/gpt-4.1-mini" \
--eval-model "openai/gpt-4.1-mini" \
```

To:
```bash
--optimizer-model "openai/gpt-4.1" \
--eval-model "openai/gpt-4.1" \
```

Or use OpenRouter:
```bash
--optimizer-model "openrouter/google/gemini-2.5-flash" \
--eval-model "openrouter/google/gemini-2.5-flash" \
```

### Change Iterations

More iterations = better optimization but more cost:
```bash
--iterations 10  # Default
--iterations 20  # More thorough
--iterations 5   # Quick test
```

## 📊 Understanding Results

### metrics.json

```json
{
  "skill_name": "demo-skill",
  "baseline_score": 0.391,
  "evolved_score": 0.472,
  "improvement": 0.081,
  "baseline_size": 1234,
  "evolved_size": 1356,
  "elapsed_seconds": 45.2,
  "constraints_passed": true
}
```

Key metrics:
- `improvement`: Positive = better, Negative = worse
- `constraints_passed`: Must be true for deployment
- `elapsed_seconds`: Total optimization time

### Comparing Skills

```bash
# View the diff
diff output/demo-skill/*/baseline_skill.md output/demo-skill/*/evolved_skill.md

# Or use a GUI diff tool
meld output/demo-skill/*/baseline_skill.md output/demo-skill/*/evolved_skill.md
```

## 🐛 Troubleshooting

### "ModuleNotFoundError: No module named 'dspy'"

Install dependencies:
```bash
cd hermes-agent-self-evolution-main
pip install -e . --break-system-packages
```

### "Cannot find hermes-agent repo"

The script sets `--hermes-repo` automatically. If you get this error, check:
```bash
ls -la demo-hermes-repo/skills/demo/demo-skill/SKILL.md
```

### "Skill 'demo-skill' not found"

Check the skill path:
```bash
find demo-hermes-repo -name "SKILL.md"
```

### Optimization is slow or expensive

- Reduce iterations: `--iterations 3`
- Use cheaper models: `--eval-model "openai/gpt-4.1-mini"`
- Use dry-run first to validate setup

### API key errors

Check your environment:
```bash
echo $OPENAI_API_KEY
echo $OPENROUTER_API_KEY
```

Make sure the key is valid:
```bash
curl https://api.openai.com/v1/models -H "Authorization: Bearer $OPENAI_API_KEY"
```

## 📚 Next Steps

1. **Read the full analysis**: `../ANALYSIS.md`
2. **Understand the architecture**: `../ARCHITECTURE.md`
3. **Review code quality**: `../CODE_QUALITY.md`
4. **Try evolving real skills**: Copy skills from hermes-agent repo

## 🎓 Learning Resources

- [DSPy Documentation](https://dspy.ai/)
- [GEPA Paper](https://arxiv.org/abs/2406.11768) (ICLR 2026 Oral)
- [Hermes Agent](https://github.com/NousResearch/hermes-agent)

## 💡 Tips

1. **Always start with dry-run** to validate setup
2. **Use cheaper models** for initial testing
3. **Monitor costs** - check OpenAI/OpenRouter dashboard
4. **Save good results** - copy evolved skills before next run
5. **Iterate** - try different models, iterations, eval sources

## 🆘 Support

- Check the main analysis: `../ANALYSIS.md`
- Review the original docs: `../../hermes-agent-self-evolution-main/README.md`
- Read the plan: `../../hermes-agent-self-evolution-main/PLAN.md`

---

**Last Updated:** 2026-10-18  
**Maintainer:** Claude Opus 5  
**Status:** ✅ Ready to Run
