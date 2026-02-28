---
name: skill-creator
description: Create, improve, and evaluate Claude/Codex skills end-to-end. Use whenever the user mentions creating a skill, rewriting SKILL.md, frontmatter fields, slash-command behavior, trigger quality (under-triggering or over-triggering), adding scripts/references/assets for a skill, validating skill structure, benchmarking skill behavior, packaging a .skill artifact, or optimizing a skill description for better triggering accuracy.
argument-hint: "[skill-name or path]"
compatibility: Requires Python 3.9+ for bundled scripts. Trigger evaluation requires `claude` CLI on PATH. Unix/macOS only (eval uses select.select). pyyaml recommended for complex frontmatter validation.
metadata:
  author: "Bryan"
  version: "2.0.0"
  category: "developer-tooling"
---

# Skill Creator

Build production-grade skills with high trigger accuracy, clear scope, and repeatable quality checks.

## Quick Start

Create a working skill in 5 steps:

1. **Scaffold**: `python3 scripts/init_skill.py my-skill --path ~/.claude/skills`
2. **Edit description**: Open `SKILL.md`, write a clear `description` with "Use when ..." phrasing.
3. **Write body**: Add imperative instructions, error handling, and references.
4. **Validate**: `python3 scripts/validate_skill.py ~/.claude/skills/my-skill --strict`
5. **Test**: Invoke with `/my-skill` or type a query that should trigger it.

For trigger quality testing, continue to Steps 8-10 below.

## Core Operating Rules

1. Optimize for user outcomes, not templates.
2. Keep critical, frequently-used information in SKILL.md; move supplementary, rarely-needed details to `references/`. Decide by importance and usage frequency, not content size.
3. Keep triggering intent in frontmatter `description`; avoid burying trigger logic in the body.
4. Validate before benchmarking. Benchmark before packaging.
5. Prefer deterministic scripts for repetitive or fragile steps.
6. Match the user's language and domain terms when drafting examples and trigger phrases.

## End-to-End Workflow

### Step 1: Lock scope with concrete examples

Capture:

1. What the skill should do.
2. When it should trigger.
3. What outputs matter.
4. What should explicitly not trigger the skill.

Use 2-5 realistic prompts in the same language style users naturally write.

### Step 2: Choose skill shape and constraints

Classify the skill:

1. **Reference-heavy knowledge skill** — background context Claude applies to current work. Consider `user-invocable: false` if users should not invoke directly.
2. **Task workflow skill** — step-by-step actions with side effects. Consider `disable-model-invocation: true` to require manual `/invoke`.
3. **Hybrid skill** — knowledge + actions combined.

Decide invocation behavior and safety controls:

1. `disable-model-invocation: true` — prevent Claude from auto-triggering (for deploy, send, publish workflows).
2. `user-invocable: false` — hide from slash menu (for background knowledge skills).
3. `allowed-tools` — restrict tool surface for safety:
   ```yaml
   allowed-tools:
     - Read
     - Grep
     - Glob
     - Bash(python:*)
   ```
4. `context: fork` + `agent` — run in isolated subagent when the skill needs isolation:
   ```yaml
   context: fork
   agent: Explore    # or Plan, general-purpose, or a custom .claude/agents/*.md name
   ```
5. `hooks` — lifecycle automation scoped to this skill:
   ```yaml
   hooks:
     PreToolUse:
       - matcher: "Bash"
         hooks:
           - type: command
             command: "./scripts/lint-check.sh $TOOL_INPUT"
   ```

Common frontmatter combinations by skill shape:

```yaml
# Reference-heavy knowledge skill
name: api-conventions
description: API design patterns for this codebase. Use when ...
user-invocable: false

# Task workflow skill (side effects, user-only)
name: deploy-prod
description: Deploy to production
disable-model-invocation: true
context: fork
agent: general-purpose
allowed-tools: Bash(npm *), Bash(git *), Read

# Read-only analysis skill
name: code-analyzer
description: Analyze code patterns. Use when asking about code quality or architecture.
allowed-tools: Read, Grep, Glob

# Research skill with isolation
name: deep-research
description: Research a topic in the codebase thoroughly. Use when ...
context: fork
agent: Explore
```

### Step 3: Create folder structure

Use this baseline:

```text
skill-name/
├── SKILL.md
├── scripts/        # optional
├── references/     # optional
└── assets/         # optional
```

Do not create `README.md` inside the skill folder. Do not create `agents/` inside the skill folder — subagent definitions belong in `.claude/agents/*.md`.

Preferred scaffold command:

```bash
python3 scripts/init_skill.py <skill-name> --path <skills-root>
```

By default only `SKILL.md` is created. Add `--resources` based on what the skill actually needs:

- `scripts` — if the skill includes automation scripts
- `references` — if the skill needs reference docs, schemas, or patterns
- `assets` — if the skill stores templates, generated files, or binary assets

### Step 4: Draft frontmatter first

Write frontmatter before body instructions.

Minimum production fields:

1. `name` — kebab-case, max 64 chars.
2. `description` — what the skill does + when to use it. Max 1024 chars. Include "Use when ..." phrasing.

Recommended advanced fields:

1. `argument-hint` — shown during autocomplete, e.g. `[issue-number]` or `[filename] [format]`.
2. `compatibility` — runtime requirements.
3. `allowed-tools`, `disable-model-invocation`, `user-invocable`, `context`, `agent`, `hooks` — as needed.

### Step 5: Write SKILL.md body

Use imperative instructions. The body supports these dynamic features:

See [references/advanced_patterns.md](references/advanced_patterns.md) for argument substitution (`$ARGUMENTS`, `$0`/`$1`) and dynamic context injection (shell command expansion) syntax and examples. Those examples are kept in references to avoid the skill loader executing them.

**Body structure**:

1. Quick-start actions for common cases.
2. Step-by-step workflow.
3. Error handling and recovery.
4. Clear references to supporting files.

Keep body under 500 lines when possible.

### Step 6: Add reusable resources

Add only what improves repeatability:

1. `scripts/` for deterministic transformations or checks.
2. `references/` for supplementary docs, schemas, edge cases, and advanced patterns.
3. `assets/` for templates and output resources.

**What stays in SKILL.md vs goes to references/**:

- SKILL.md: core workflow, frequently-used examples, essential configuration patterns, information needed on every execution.
- references/: detailed field specs, rare edge cases, JSON schemas, grader prompts, content that is only consulted in specific scenarios.
- Decision criterion: **importance and usage frequency first, content size second**. A 50-line block that is critical every time belongs in SKILL.md. A 30-line block only needed for debugging belongs in references.

Avoid duplicating the same guidance in both SKILL.md and references.

### Step 7: Validate structure and frontmatter

Run:

```bash
python3 scripts/validate_skill.py <path-to-skill>
```

Use strict mode for release checks:

```bash
python3 scripts/validate_skill.py <path-to-skill> --strict
```

### Step 8: Evaluate trigger quality

Create a query set with both positive and negative cases, then run:

```bash
python3 scripts/eval_description.py \
  --skill-path <path-to-skill> \
  --eval-set <path-to-eval-set.json> \
  --runs-per-query 3
```

Generate an HTML report of results:

```bash
python3 scripts/generate_report.py eval_results.json --open
```

If under-triggering:

1. Add intent language, not just keywords.
2. Add adjacent phrasings users actually type.

If over-triggering:

1. Add scope boundaries in description.
2. Add near-miss negatives to eval set.

### Step 9: Auto-improve description

Instead of manually tuning, use the improvement loop:

```bash
python3 scripts/run_loop.py \
  --skill-path <path-to-skill> \
  --eval-set <path-to-eval-set.json> \
  --max-iterations 5 \
  --target-pass-rate 0.9 \
  --holdout 0.4 \
  --output-dir ./eval-output
```

This runs eval → improve → re-eval cycles with train/test split to prevent overfitting. View the optimization report:

```bash
python3 scripts/generate_report.py ./eval-output/loop_summary.json --open
```

Or improve a single iteration manually:

```bash
python3 scripts/improve_description.py \
  --eval-results <eval-results.json> \
  --skill-path <path-to-skill> \
  --history <history.json> \
  --apply
```

### Step 10: Evaluate behavior quality

For functional quality beyond trigger accuracy, use the grader prompt template:

1. Run the skill on a representative task.
2. Capture the execution transcript.
3. Define assertions (expected outcomes).
4. Run the grader: see [references/skill_grader_prompt.md](references/skill_grader_prompt.md) for the prompt template.

Compare with-skill runs against baseline (without skill or prior version). Measure task completion, failure consistency, and token efficiency.

### Step 11: Iterate without overfitting

For each iteration:

1. Generalize from failures instead of patching single prompts.
2. Remove instructions that consume context but do not improve outcomes.
3. Keep assertions discriminative, not superficial.
4. Use the train/test split in `run_loop.py` to detect overfitting.

### Step 12: Package for delivery

Run:

```bash
python3 scripts/package_skill.py <path-to-skill>
```

This produces a `.skill` artifact while excluding transient files.

## Fast Command Reference

```bash
# Scaffold a new skill
python3 scripts/init_skill.py my-skill --path ~/.claude/skills

# Validate
python3 scripts/validate_skill.py ./my-skill

# Validate strictly (for release)
python3 scripts/validate_skill.py ./my-skill --strict

# Trigger eval
python3 scripts/eval_description.py \
  --skill-path ./my-skill \
  --eval-set ./eval_set.json \
  --runs-per-query 3 --workers 6

# Auto-improve loop
python3 scripts/run_loop.py \
  --skill-path ./my-skill \
  --eval-set ./eval_set.json \
  --max-iterations 5 --target-pass-rate 0.9

# Single improvement
python3 scripts/improve_description.py \
  --eval-results ./eval_results.json \
  --skill-path ./my-skill --apply

# HTML report from eval or loop output
python3 scripts/generate_report.py ./results.json --open

# Package
python3 scripts/package_skill.py ./my-skill --output-dir ./dist
```

## Additional References

- For frontmatter policy and field compatibility: [references/frontmatter_matrix.md](references/frontmatter_matrix.md)
- For full build/review checklist: [references/workflow_checklist.md](references/workflow_checklist.md)
- For eval and grading JSON formats: [references/eval_schema.md](references/eval_schema.md)
- For advanced patterns ($ARGUMENTS, dynamic injection, hooks, fork): [references/advanced_patterns.md](references/advanced_patterns.md)
- For behavior quality grading: [references/skill_grader_prompt.md](references/skill_grader_prompt.md)
