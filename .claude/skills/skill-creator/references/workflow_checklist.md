# Workflow Checklist

Complete checklist for building, testing, and releasing a skill. Each phase includes detailed guidance and common pitfalls.

## Phase 1: Scope and Intent

- [ ] Capture 2-5 concrete user prompts that should trigger the skill.
- [ ] Capture 2-5 prompts that should NOT trigger (near-miss negatives).
- [ ] Define what should trigger and should not trigger.
- [ ] Define output quality criteria (what "good" looks like).
- [ ] Identify the skill category: reference, task workflow, or hybrid.

**Common pitfalls**:

- Defining scope too broadly ("handles all code tasks") leads to over-triggering.
- Not including near-miss negatives means you cannot detect over-triggering early.
- Forgetting to define "what good output looks like" makes quality evaluation subjective.

## Phase 2: Structure and Configuration

- [ ] Choose folder structure (`scripts/`, `references/`, `assets/` as needed).
- [ ] Keep SKILL.md procedural and compact (under 500 lines).
- [ ] Add deterministic helpers to `scripts/` when repetition exists.
- [ ] Do NOT create `README.md` inside the skill folder.
- [ ] Do NOT create `agents/` inside the skill folder.

**Invocation and safety configuration**:

- [ ] Decide if `disable-model-invocation: true` is needed (for side-effect workflows).
- [ ] Decide if `user-invocable: false` is needed (for background knowledge).
- [ ] Set `allowed-tools` if the skill should have restricted tool access.
- [ ] Set `context: fork` + `agent` if isolation is needed.
- [ ] Configure `hooks` if lifecycle automation is required.
- [ ] Add `argument-hint` if the skill accepts arguments.

**Progressive disclosure — what stays in SKILL.md vs references/**:

- **Stays in SKILL.md**: core workflow steps, frequently-used examples, essential configuration patterns, information needed on every execution.
- **Goes to references/**: detailed field specs, rare edge cases, JSON schemas, advanced patterns only needed in specific scenarios, grader prompts.
- Decision criterion: **importance and usage frequency first, content size second**. A short but critical block belongs in SKILL.md; a long but rarely-needed reference belongs in references/.
- Keep references one level deep (SKILL.md → reference files, not deeper).

## Phase 3: Frontmatter Quality

- [ ] `name` is kebab-case and ≤ 64 chars.
- [ ] `name` matches the folder name.
- [ ] `name` does not start with `claude` or `anthropic`.
- [ ] `description` states capability + trigger contexts.
- [ ] `description` includes "Use when ..." or "Use whenever ..." phrasing.
- [ ] `description` is ≤ 1024 chars and has no angle brackets.
- [ ] `description` includes boundary language to reduce over-triggering.
- [ ] `compatibility` documents runtime assumptions (Python version, CLI tools, OS).
- [ ] `argument-hint` is set if skill accepts arguments.
- [ ] All invocation/tool/safety fields are set intentionally.

**Description optimization tips**:

- Start slightly aggressive (cover more triggers) and narrow down with eval.
- Include natural user phrasings, not just technical keywords.
- Run `improve_description.py` to auto-optimize after initial eval.

## Phase 4: Body Quality

- [ ] Instructions are imperative and executable ("Run X", "Create Y").
- [ ] Quick Start section exists for the most common 80% use case.
- [ ] Step-by-step workflow covers the full process.
- [ ] Error handling paths are explicit.
- [ ] Links point directly to referenced files (not deep nested paths).
- [ ] SKILL.md stays below 500 lines when practical.
- [ ] `$ARGUMENTS` is used if the skill accepts input.
- [ ] `` !`command` `` is used for dynamic context where needed.
- [ ] Command output uses compact format (`@tsv`/`@csv`) instead of raw JSON where applicable.
- [ ] API calls request only needed fields (where the API supports field selection).
- [ ] Reference files use lazy loading ("READ when needed") instead of inline content.
- [ ] jq transforms include error guards (`if .errorMessages then . else <transform> end`).

**Common body pitfalls**:

- Passive voice ("the file should be read") — use imperative ("Read the file").
- Burying trigger logic in the body instead of the description.
- Not documenting error recovery (what to do when a step fails).
- Missing references to supporting files.
- Using JSON output when TSV/CSV suffices (wastes 60-80% tokens).
- Inlining all reference content instead of lazy loading with "READ when needed".

## Phase 5: Validation and Evaluation

### Structure Validation

- [ ] Run `python3 scripts/validate_skill.py <skill-path>`.
- [ ] Run strict validation for release: `python3 scripts/validate_skill.py <skill-path> --strict`.
- [ ] All errors resolved, warnings reviewed.

### Trigger Evaluation

- [ ] Build eval set with 10+ queries (mix of positive and negative).
- [ ] Run `eval_description.py --runs-per-query 3`.
- [ ] Generate HTML report: `generate_report.py results.json --open`.
- [ ] Pass rate meets target (recommended: ≥ 80% for initial, ≥ 90% for release).
- [ ] If under target, run `run_loop.py` with train/test split.
- [ ] Verify test set performance to detect overfitting.

### Behavior Evaluation

- [ ] Run skill on 2-3 representative tasks.
- [ ] Compare with-skill output against baseline (no-skill) output.
- [ ] Use grader prompt template for structured scoring.
- [ ] Verify skill consistently improves over baseline.

**Eval set design tips**:

- Include at least 3 positive triggers and 3 negative (near-miss) queries.
- Near-miss negatives should be plausible queries that are close but should not trigger.
- Include queries in different phrasings and verbosity levels.
- Include edge cases: very short queries, multi-part requests, different languages.

## Phase 6: Iteration Discipline

- [ ] Fix root causes, not only prompt-specific artifacts.
- [ ] Remove low-value instructions that add token load without improving outcomes.
- [ ] Keep assertions discriminative (test for content correctness, not superficial checks).
- [ ] Track iteration history with `--history` flag in `improve_description.py`.
- [ ] Use `run_loop.py --holdout 0.4` to prevent overfitting.
- [ ] Review and approve each description change before applying.

**Signs of overfitting**:

- Train pass rate is 100% but test pass rate drops below 70%.
- Description contains specific query phrasings from the eval set.
- Description has grown beyond 800 characters with overly specific language.

## Phase 7: Packaging and Distribution

- [ ] Run `python3 scripts/package_skill.py <skill-path>`.
- [ ] Verify resulting `.skill` includes required files and excludes transient artifacts.
- [ ] Confirm `.skill` size is reasonable (no accidentally included large files).

**Distribution options**:

- **Personal**: Place in `~/.claude/skills/` for all your projects.
- **Project**: Place in `.claude/skills/` and commit to version control.
- **Plugin**: Create a `skills/` directory in your plugin.
- **Enterprise**: Deploy via managed settings.

**Priority order**: Enterprise > Personal > Project > Plugin.
