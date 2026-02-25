# Eval and Grading JSON Schemas

Complete reference for all JSON formats used by the bundled scripts.

## Trigger Eval Input (`eval_description.py`)

### Format A: Array of Objects

```json
[
  {"query": "Create a skill for PDF extraction", "should_trigger": true},
  {"query": "What's the weather tomorrow?", "should_trigger": false}
]
```

### Format B: Object with `evals` Key

```json
{
  "evals": [
    {"prompt": "Improve this SKILL.md description", "should_trigger": true},
    {"prompt": "Write a fibonacci function", "should_trigger": false}
  ]
}
```

### Field Rules

| Field | Type | Required | Notes |
|---|---|---|---|
| `query` or `prompt` | string | Yes | Non-empty. Either key name is accepted. |
| `should_trigger` | boolean | Yes | `true` = skill should trigger, `false` = should not |

### Eval Set Design Guidelines

Recommended minimum: 10 queries (5 positive, 5 negative).

**Positive cases** should cover:

- Exact intent matches ("Create a new skill")
- Paraphrased intent ("Help me build a slash command")
- Partial intent with context ("I want to make my deployment process a reusable command")
- Different verbosity levels (short: "new skill", long: detailed paragraph)

**Negative cases** (near-miss) should cover:

- Related but out-of-scope queries ("Write a Python script" for a skill-creator)
- Queries with shared keywords ("What skills do I need for this job interview?")
- Generic requests that share surface patterns ("Create a new file")
- Requests for other skills that might compete

### Example Eval Set for skill-creator

```json
[
  {"query": "Create a skill for code review", "should_trigger": true},
  {"query": "Help me write SKILL.md for my deploy tool", "should_trigger": true},
  {"query": "My skill isn't triggering, can you fix the description?", "should_trigger": true},
  {"query": "Package my skill for distribution", "should_trigger": true},
  {"query": "Evaluate my skill's trigger quality", "should_trigger": true},
  {"query": "What's the weather in Tokyo?", "should_trigger": false},
  {"query": "Write a Python function to sort a list", "should_trigger": false},
  {"query": "Help me debug this test failure", "should_trigger": false},
  {"query": "What skills should I learn for web development?", "should_trigger": false},
  {"query": "Create a new React component", "should_trigger": false}
]
```

## Trigger Eval Output (`eval_description.py`)

```json
{
  "skill_name": "skill-creator",
  "description": "Create, improve, and evaluate...",
  "summary": {
    "passed": 8,
    "failed": 2,
    "total": 10,
    "threshold": 0.5
  },
  "results": [
    {
      "query": "Create a new skill for release notes",
      "should_trigger": true,
      "triggers": 3,
      "runs": 3,
      "errors": 0,
      "trigger_rate": 1.0,
      "pass": true
    },
    {
      "query": "Write a Python function",
      "should_trigger": false,
      "triggers": 1,
      "runs": 3,
      "errors": 0,
      "trigger_rate": 0.3333,
      "pass": true
    }
  ]
}
```

### Summary Fields

| Field | Type | Description |
|---|---|---|
| `passed` | int | Number of queries meeting threshold |
| `failed` | int | Number of queries not meeting threshold |
| `total` | int | Total unique queries |
| `threshold` | float | Trigger rate threshold (default 0.5) |

### Result Fields

| Field | Type | Description |
|---|---|---|
| `query` | string | The test query |
| `should_trigger` | bool | Whether the skill should trigger |
| `triggers` | int | Number of runs where skill triggered |
| `runs` | int | Total runs for this query |
| `errors` | int | Number of runs that errored |
| `trigger_rate` | float | `triggers / runs` |
| `pass` | bool | For positives: `trigger_rate >= threshold`. For negatives: `trigger_rate < threshold`. |

## Improvement History (`improve_description.py --history`)

```json
[
  {
    "round": 1,
    "timestamp": "2025-01-15T10:30:00+00:00",
    "description": "Create and evaluate skills...",
    "pass_rate": "8/10",
    "under_triggers": 1,
    "over_triggers": 1
  },
  {
    "round": 2,
    "timestamp": "2025-01-15T10:35:00+00:00",
    "description": "Create, improve, and evaluate skills...",
    "pass_rate": "9/10",
    "under_triggers": 0,
    "over_triggers": 1
  }
]
```

## Loop Summary (`run_loop.py --output-dir`)

```json
{
  "skill_name": "skill-creator",
  "original_description": "...",
  "iterations": [
    {
      "round": 1,
      "description": "...",
      "full_pass_rate": 0.8,
      "train_pass_rate": 0.8333,
      "test_pass_rate": 0.75,
      "train_passed": 5,
      "train_total": 6,
      "test_passed": 3,
      "test_total": 4,
      "timestamp": "2025-01-15T10:30:00+00:00"
    }
  ],
  "best_iteration": { "...same fields as above..." },
  "final_description": "...",
  "total_rounds": 3
}
```

### Interpreting Loop Results

- **full_pass_rate**: Overall performance on the complete eval set.
- **train_pass_rate**: Performance on the training subset (used for improvement).
- **test_pass_rate**: Performance on held-out test subset (overfitting detector).
- **best_iteration**: The iteration with highest test_pass_rate (or full if no holdout).

**Warning signs**:

- `train_pass_rate` increasing but `test_pass_rate` decreasing → overfitting.
- `full_pass_rate` not improving across iterations → description plateau.
- `errors` count increasing → infrastructure issues, not description quality.

## Behavior Grading Output (Grader Prompt Template)

```json
{
  "assertions": [
    {
      "text": "Output includes valid YAML frontmatter",
      "passed": true,
      "evidence": "Found '---' delimiters with valid name and description fields"
    },
    {
      "text": "Description under 1024 characters",
      "passed": true,
      "evidence": "Description is 312 characters"
    }
  ],
  "dimensions": {
    "task_completion": {"score": 4, "notes": "Completed main task but missed edge case"},
    "output_structure": {"score": 5, "notes": "Well-organized with clear sections"},
    "error_handling": {"score": 3, "notes": "No explicit error recovery documented"},
    "efficiency": {"score": 4, "notes": "Reasonable tool usage, one unnecessary Read call"}
  },
  "overall_score": 4.0,
  "summary": "Skill produced correct output with good structure but could improve error handling",
  "weak_assertions": ["Description under 1024 characters"],
  "missing_coverage": ["Error handling behavior when input is malformed"]
}
```

### Dimension Scoring Guide

| Score | Meaning |
|---|---|
| 1 | Completely failed |
| 2 | Major issues, partially functional |
| 3 | Adequate but notable gaps |
| 4 | Good with minor issues |
| 5 | Excellent, no significant issues |

## Validation Output (`validate_skill.py --json`)

```json
{
  "skill_path": "/path/to/skill",
  "valid": true,
  "errors": [],
  "warnings": [
    {
      "level": "warning",
      "code": "DESCRIPTION_TRIGGER_HINT",
      "message": "description should usually include explicit trigger language like 'Use when ...'"
    }
  ],
  "summary": {
    "error_count": 0,
    "warning_count": 1
  }
}
```

### Error Codes Reference

| Code | Level | Description |
|---|---|---|
| `SKILL_DIR_MISSING` | error | Skill directory does not exist |
| `SKILL_PATH_NOT_DIR` | error | Path is not a directory |
| `SKILL_MD_MISSING` | error | Missing SKILL.md |
| `FRONTMATTER_PARSE` | error | Cannot parse frontmatter |
| `FRONTMATTER_INVALID` | error | Frontmatter is not a valid YAML mapping |
| `UNKNOWN_KEYS` | warning/error | Unrecognized frontmatter keys |
| `MISSING_RECOMMENDED_KEY` | warning/error | Missing name or description |
| `NAME_TYPE` | error | name is not a string |
| `NAME_EMPTY` | error | name is empty |
| `NAME_TOO_LONG` | error | name exceeds 64 characters |
| `NAME_FORMAT` | error | name is not kebab-case |
| `NAME_RESERVED_PREFIX` | error | name starts with reserved prefix |
| `NAME_FOLDER_MISMATCH` | warning | name doesn't match folder name |
| `DESCRIPTION_TYPE` | error | description is not a string |
| `DESCRIPTION_EMPTY` | error | description is empty |
| `DESCRIPTION_TOO_LONG` | error | description exceeds 1024 characters |
| `DESCRIPTION_ANGLE_BRACKETS` | error | description contains `<` or `>` |
| `DESCRIPTION_TRIGGER_HINT` | warning | Missing "Use when..." language |
| `COMPATIBILITY_TYPE` | error | compatibility is not a string |
| `COMPATIBILITY_TOO_LONG` | error | compatibility exceeds 500 characters |
| `ALLOWED_TOOLS_TYPE` | error | allowed-tools is not string or list |
| `ALLOWED_TOOLS_ITEM_TYPE` | error | allowed-tools list item is not a string |
| `MODEL_TYPE` | error | model is not a string |
| `HOOKS_TYPE` | error | hooks is not a mapping |
| `CONTEXT_FORK_NO_AGENT` | warning | context: fork but no agent set |
| `AGENT_WITHOUT_FORK` | warning | agent set but context is not fork |
| `SKILL_MD_TOO_LONG` | warning | SKILL.md exceeds 500 lines |
| `WHEN_TO_USE_IN_BODY` | warning | Trigger guidance should be in description |
| `DEEP_LINK_TARGET` | warning | Link escapes skill directory |
| `README_PRESENT` | warning/error | README.md found in skill folder |
