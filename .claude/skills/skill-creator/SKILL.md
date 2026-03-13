---
name: skill-creator
description: Create and improve Claude Code skills. Use when user says "/skill-creator" or asks to create, evaluate, or optimize a skill.
version: 3.0.0
disable-model-invocation: true
argument-hint: "[skill-name or path]"
compatibility: Python 3.9+, anthropic SDK, claude CLI on PATH. Unix/macOS.
metadata:
  author: "Bryan"
  category: "developer-tooling"
---

# Skill Creator

A skill for creating new skills and iteratively improving them.

The process of creating a skill goes like this:

- Decide what you want the skill to do and roughly how it should do it
- Write a draft of the skill
- Create a few test prompts and run claude-with-access-to-the-skill on them
- Help the user evaluate the results both qualitatively and quantitatively
  - While the runs happen in the background, draft some quantitative evals if there aren't any. Then explain them to the user
  - Use the `eval-viewer/generate_review.py` script to show the user the results, and also let them look at the quantitative metrics
- Rewrite the skill based on feedback from the user's evaluation of the results
- Repeat until satisfied
- Expand the test set and try again at larger scale

Your job is to figure out where the user is in this process and help them progress. Maybe they want to make a skill from scratch, or maybe they already have a draft and want to jump to eval/iterate.

Be flexible — if the user says "just vibe with me", skip the formal evaluation. After the skill is done, offer to run the description optimizer.

## Communicating with the user

Pay attention to context cues to understand how to phrase your communication. "evaluation" and "benchmark" are borderline but OK. For "JSON" and "assertion", see serious cues from the user before using them without explaining. It's OK to briefly explain terms if in doubt.

---

## Creating a skill

### Capture Intent

Start by understanding the user's intent. The current conversation might already contain a workflow the user wants to capture (e.g., "turn this into a skill"). If so, extract answers from the conversation history first.

1. What should this skill enable Claude to do?
2. When should this skill trigger? (what user phrases/contexts)
3. What's the expected output format?
4. Should we set up test cases to verify the skill works?

### Interview and Research

Proactively ask about edge cases, input/output formats, example files, success criteria, and dependencies. Wait to write test prompts until you've got this part ironed out.

Check available MCPs — if useful for research (searching docs, finding similar skills, looking up best practices), research in parallel via subagents if available, otherwise inline.

### Write the SKILL.md

Based on the user interview, fill in these components:

- **name**: Skill identifier (kebab-case, max 64 chars)
- **description**: When to trigger, what it does. This is the primary triggering mechanism — include both what the skill does AND specific contexts for when to use it. Make descriptions slightly "pushy" to counter Claude's tendency to "undertrigger" skills.
- **compatibility**: Required tools, dependencies (optional, rarely needed)
- **the rest of the skill :)**

Advanced frontmatter fields (`argument-hint`, `allowed-tools`, `disable-model-invocation`, `user-invocable`, `context`, `agent`, `hooks`) — see [references/frontmatter_matrix.md](references/frontmatter_matrix.md) for the complete reference with examples and common combinations.

### Skill Writing Guide

#### Anatomy of a Skill

```
skill-name/
├── SKILL.md (required)
│   ├── YAML frontmatter (name, description required)
│   └── Markdown instructions
└── Bundled Resources (optional)
    ├── scripts/    - Executable code for deterministic/repetitive tasks
    ├── references/ - Docs loaded into context as needed
    └── assets/     - Files used in output (templates, icons, fonts)
```

#### Progressive Disclosure

Skills use a three-level loading system:
1. **Metadata** (name + description) — Always in context (~100 words)
2. **SKILL.md body** — In context whenever skill triggers (<500 lines ideal)
3. **Bundled resources** — As needed (unlimited, scripts can execute without loading)

**Key patterns:**
- Keep SKILL.md under 500 lines; move supplementary content to references/
- Reference files clearly from SKILL.md with guidance on when to read them
- For large reference files (>300 lines), include a table of contents
- Keep critical, frequently-used information in SKILL.md; move supplementary, rarely-needed details to `references/`

#### Writing Patterns

Prefer imperative form. Explain the **why** behind everything rather than heavy-handed MUSTs.

**Defining output formats:**
```markdown
## Report structure
ALWAYS use this exact template:
# [Title]
## Executive summary
## Key findings
## Recommendations
```

**Examples pattern:**
```markdown
## Commit message format
**Example 1:**
Input: Added user authentication with JWT tokens
Output: feat(auth): implement JWT-based authentication
```

### Writing Style

Try to explain to the model why things are important in lieu of heavy-handed MUSTs. Use theory of mind and try to make the skill general, not super-narrow. Start by writing a draft and then look at it with fresh eyes and improve it.

### Scaffold

Generate a new skill folder with the correct structure:

```bash
python3 scripts/init_skill.py <skill-name> --path <skills-root>
```

By default only `SKILL.md` is created. Add `--resources` based on what the skill needs:

```bash
# With scripts and references directories
python3 scripts/init_skill.py my-skill --path ~/.claude/skills --resources scripts,references
```

Options: `--description`, `--compatibility`, `--resources scripts,references,assets`, `--force`.

### Test Cases

After writing the skill draft, come up with 2-3 realistic test prompts. Share them with the user for confirmation, then run them.

Save test cases to `evals/evals.json`:

```json
{
  "skill_name": "example-skill",
  "evals": [
    {
      "id": 1,
      "prompt": "User's task prompt",
      "expected_output": "Description of expected result",
      "files": []
    }
  ]
}
```

See `references/schemas.md` for the full schema (including the `assertions` field).

## Running and evaluating test cases

This section is one continuous sequence — don't stop partway through.

Put results in `<skill-name>-workspace/` as a sibling to the skill directory. Within the workspace, organize results by iteration (`iteration-1/`, `iteration-2/`, etc.) and within that, each test case gets a directory (`eval-0/`, `eval-1/`, etc.).

### Step 1: Spawn all runs (with-skill AND baseline) in the same turn

For each test case, spawn two subagents in the same turn — one with the skill, one without. Launch everything at once so it all finishes around the same time.

**With-skill run:**
```
Execute this task:
- Skill path: <path-to-skill>
- Task: <eval prompt>
- Input files: <eval files if any, or "none">
- Save outputs to: <workspace>/iteration-<N>/eval-<ID>/with_skill/outputs/
```

**Baseline run** (same prompt, no skill / old skill version). Save to `without_skill/outputs/` or `old_skill/outputs/`.

Write an `eval_metadata.json` for each test case (assertions can be empty for now). Give each eval a descriptive name.

### Step 2: While runs are in progress, draft assertions

Don't just wait — draft quantitative assertions for each test case and explain them to the user. Good assertions are objectively verifiable and have descriptive names.

Update the `eval_metadata.json` files and `evals/evals.json` with the assertions.

### Step 3: As runs complete, capture timing data

When each subagent task completes, you receive `total_tokens` and `duration_ms`. Save immediately to `timing.json` in the run directory. This is the only opportunity to capture this data.

### Step 4: Grade, aggregate, and launch the viewer

Once all runs are done:

1. **Grade each run** — spawn a grader subagent that reads `agents/grader.md` and evaluates each assertion against the outputs. Save to `grading.json`. The grading.json expectations array must use the fields `text`, `passed`, and `evidence`. For assertions that can be checked programmatically, write and run a script rather than eyeballing it.

2. **Aggregate into benchmark**:
   ```bash
   python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name <name>
   ```
   This produces `benchmark.json` and `benchmark.md`.

3. **Do an analyst pass** — read `agents/analyzer.md` ("Analyzing Benchmark Results" section) for what to look for: non-discriminating assertions, high-variance evals, time/token tradeoffs.

4. **Launch the viewer**:
   ```bash
   nohup python <skill-creator-path>/eval-viewer/generate_review.py \
     <workspace>/iteration-N \
     --skill-name "my-skill" \
     --benchmark <workspace>/iteration-N/benchmark.json \
     > /dev/null 2>&1 &
   VIEWER_PID=$!
   ```
   For iteration 2+, also pass `--previous-workspace <workspace>/iteration-<N-1>`.
   For headless environments, use `--static <output_path>` to write standalone HTML.

5. **Tell the user** the results are open in their browser with two tabs — 'Outputs' for feedback and 'Benchmark' for quantitative comparison.

### Step 5: Read the feedback

When the user is done, read `feedback.json`. Empty feedback means the user thought it was fine. Focus improvements on test cases with specific complaints.

Kill the viewer server when done: `kill $VIEWER_PID 2>/dev/null`

---

## Improving the skill

### How to think about improvements

1. **Generalize from the feedback.** Don't overfit to specific examples. Rather than fiddly overfitty changes or oppressively constrictive MUSTs, try different metaphors or recommend different patterns.

2. **Keep the prompt lean.** Remove things that aren't pulling their weight. Read the transcripts, not just the final outputs.

3. **Explain the why.** Try hard to explain the **why** behind everything. If you find yourself writing ALWAYS or NEVER in all caps, reframe and explain the reasoning.

4. **Look for repeated work across test cases.** If all test cases resulted in the subagent writing a similar helper script, bundle that script in `scripts/`.

### The iteration loop

1. Apply improvements to the skill
2. Rerun all test cases into a new `iteration-<N+1>/` directory, including baseline runs
3. Launch the reviewer with `--previous-workspace` pointing at the previous iteration
4. Wait for user review
5. Read the new feedback, improve again, repeat

---

## Advanced: Blind comparison

For situations where you want a more rigorous comparison between two versions of a skill, there's a blind comparison system. Read `agents/comparator.md` and `agents/analyzer.md` for the details. The basic idea is: give two outputs to an independent agent without telling it which is which, and let it judge quality.

This is optional and most users won't need it.

---

## Validation

Validate structure and frontmatter before benchmarking or packaging:

```bash
python3 scripts/validate_skill.py <path-to-skill>
```

Use strict mode for release checks:

```bash
python3 scripts/validate_skill.py <path-to-skill> --strict
```

The validator checks: frontmatter format, required fields, name conventions, description constraints, allowed-tools syntax, hook structure, context/agent consistency, body length, and link targets. Supports `--json` output.

---

## Description Optimization

The description field in SKILL.md frontmatter is the primary mechanism that determines whether Claude invokes a skill.

### Step 1: Generate trigger eval queries

Create 20 eval queries — a mix of should-trigger and should-not-trigger. Save as JSON:

```json
[
  {"query": "the user prompt", "should_trigger": true},
  {"query": "another prompt", "should_trigger": false}
]
```

Queries must be realistic and detailed — include file paths, personal context, column names, abbreviations, typos, casual speech. Focus on edge cases rather than clear-cut examples.

For should-trigger (8-10): different phrasings of the same intent. For should-not-trigger (8-10): near-misses that share keywords but need something different.

### Step 2: Review with user

Present the eval set using the HTML template:

1. Read `assets/eval_review.html`
2. Replace `__EVAL_DATA_PLACEHOLDER__`, `__SKILL_NAME_PLACEHOLDER__`, `__SKILL_DESCRIPTION_PLACEHOLDER__`
3. Write to a temp file and `open` it
4. User edits queries, toggles triggers, clicks "Export Eval Set"
5. Read the exported file from `~/Downloads/eval_set.json`

### Step 3: Run the optimization loop

```bash
python -m scripts.run_loop \
  --eval-set <path-to-trigger-eval.json> \
  --skill-path <path-to-skill> \
  --model <model-id-powering-this-session> \
  --max-iterations 5 \
  --verbose
```

This handles the full optimization loop automatically: splits 60% train / 40% test, evaluates the current description (3 runs per query), calls Claude with extended thinking to propose improvements, iterates up to 5 times, selects best by test score.

### Step 4: Apply the result

Take `best_description` from the JSON output and update the skill's SKILL.md frontmatter. Show the user before/after and report the scores.

---

## Package and Distribute

```bash
python3 scripts/package_skill.py <path-to-skill>
```

This validates and packages into a `.skill` archive, excluding `__pycache__`, `node_modules`, `evals/`, `benchmarks/`, and transient files.

Options: `--output-dir`, `--strict`, `--no-validate`.

**Distribution options:**
- **Personal**: Place in `~/.claude/skills/` for all your projects
- **Project**: Place in `.claude/skills/` and commit to version control
- **Plugin**: Create a `skills/` directory in your plugin
- **Enterprise**: Deploy via managed settings

---

## Fast Command Reference

```bash
# Scaffold a new skill
python3 scripts/init_skill.py my-skill --path ~/.claude/skills --resources scripts,references

# Validate
python3 scripts/validate_skill.py ./my-skill
python3 scripts/validate_skill.py ./my-skill --strict   # release check

# Trigger eval (single run)
python -m scripts.run_eval \
  --eval-set ./eval_set.json \
  --skill-path ./my-skill \
  --runs-per-query 3

# Auto-improve description loop
python -m scripts.run_loop \
  --eval-set ./eval_set.json \
  --skill-path ./my-skill \
  --model <model-id> \
  --max-iterations 5 --verbose

# Single description improvement
python -m scripts.improve_description \
  --eval-results ./eval_results.json \
  --skill-path ./my-skill \
  --model <model-id>

# HTML report from loop output
python -m scripts.generate_report ./results.json -o report.html

# Benchmark aggregation
python -m scripts.aggregate_benchmark <workspace>/iteration-N --skill-name my-skill

# Launch eval viewer
python eval-viewer/generate_review.py <workspace>/iteration-N --skill-name my-skill

# Package
python3 scripts/package_skill.py ./my-skill --output-dir ./dist
```

---

## Reference Files

### Agent definitions (for subagent prompts)

- `agents/grader.md` — How to evaluate assertions against outputs
- `agents/comparator.md` — How to do blind A/B comparison between two outputs
- `agents/analyzer.md` — How to analyze why one version beat another, and how to analyze benchmark results

### Reference documents

- `references/schemas.md` — JSON schemas: evals.json, grading.json, benchmark.json, comparison.json, etc.
- `references/frontmatter_matrix.md` — Complete frontmatter field reference with examples and common combinations
- `references/advanced_patterns.md` — `$ARGUMENTS`, `$0`/`$1` substitution, shell command expansion, hooks, context fork
- `references/token_efficiency.md` — Token optimization patterns: compact output formats, lazy-loaded references, field selection
- `references/workflow_checklist.md` — Full build/review/release checklist with 7 phases
- `references/schema.yaml` — Frontmatter field definitions (used by validate_skill.py)
