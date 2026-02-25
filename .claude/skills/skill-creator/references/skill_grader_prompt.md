# Skill Grader Prompt Template

Use this prompt template with `claude -p` to evaluate skill behavior quality. Pass the skill output transcript and assertions as context.

## Usage

```bash
claude -p "$(cat <<'PROMPT'
You are evaluating the output quality of a Claude Code skill execution.

## Skill Under Test
Name: <SKILL_NAME>
Purpose: <SKILL_DESCRIPTION>

## Execution Transcript
<TRANSCRIPT>

## Assertions to Check

<ASSERTIONS_LIST>

## Grading Instructions

For each assertion:
1. Determine if it PASSED or FAILED based on the transcript evidence.
2. Quote the specific evidence from the transcript (exact text or behavior).
3. If FAILED, explain what was expected vs what actually happened.

Then evaluate these additional dimensions (1-5 scale each):

1. **Task Completion**: Did the skill accomplish what it was asked to do?
2. **Output Structure**: Is the output well-organized and in the expected format?
3. **Error Handling**: Did the skill handle edge cases or errors gracefully?
4. **Efficiency**: Did it avoid unnecessary steps or tool calls?

## Output Format

Respond with ONLY this JSON (no other text):

{
  "assertions": [
    {"text": "assertion text", "passed": true, "evidence": "quoted evidence from transcript"}
  ],
  "dimensions": {
    "task_completion": {"score": 4, "notes": "..."},
    "output_structure": {"score": 5, "notes": "..."},
    "error_handling": {"score": 3, "notes": "..."},
    "efficiency": {"score": 4, "notes": "..."}
  },
  "overall_score": 4.0,
  "summary": "One-sentence assessment of skill quality",
  "weak_assertions": ["assertions that always pass and don't test anything meaningful"],
  "missing_coverage": ["important outcomes that no assertion checks"]
}
PROMPT
)"
```

## Assertion Format

Provide assertions as a numbered list:

```text
1. Output includes a valid YAML frontmatter block
2. Description is under 1024 characters
3. Body contains imperative instructions (not passive voice)
4. Error handling section exists
5. No README.md was created
```

## Batch Grading

For comparing with-skill vs baseline runs, run the grader twice (once per transcript) and compare the `overall_score` and per-assertion pass rates. A skill should consistently score higher than baseline on task-relevant assertions.

## Integration with run_loop.py

After each eval → improve iteration, optionally run the grader on a sample of full executions to catch regressions in behavior quality that trigger-only evaluation misses.
