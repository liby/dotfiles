---
name: write-skill
description: Write or improve agent skills with clear triggers, executable workflows, progressive disclosure, and validation. Use when creating a new skill, rewriting an existing skill, auditing skill trigger behavior, splitting or merging skills, or turning repeated agent behavior into reusable instructions. Not for reviewing application code or executing an already-selected skill without changing its instructions.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# Write Skill

Write skills that change agent behavior. Keep routing, workflow, tool use, validation, and examples that affect the next action. Cut anything that only explains skills, repeats best practice, restates a heading, or states what a competent agent already knows.

## Process

1. Classify the request, and produce the smallest artifact it needs (a one-off standard, phrasing, or lesson belongs in your reply as prose, not a new `SKILL.md`):
   - New or rewrite: edit the skill.
   - Trigger audit: report findings first; do not edit until asked.
   - Split or merge: change structure only when it improves routing or loaded context.
   - Distilled lesson: add a rule only if it clears Rule Hygiene.
2. If a skill path was given, read `SKILL.md` fully before judging; read linked files only when they affect the change. Re-read right before any full-file rewrite, and Read before Edit/Write when resuming after compaction, because an edit since your last read (including the user's own manual trim) is silently lost; prefer targeted edits over rewriting the whole file. When the edit tool rejects a stale or unread file ("File has not been read yet" in Claude Code), read the file once and retry; never repeat the identical edit call.
3. Diagnose at the whole-skill altitude, not just where the request points: when one symptom is reported, check whether the same root cause sits elsewhere and fix it once. Before adding, scan the existing wording for a vague or overlapping rule to sharpen or merge; a new rule is the last resort (Rule Hygiene).
4. For non-trivial new skills, inspect 2-4 comparable local or public skills. Use actual `SKILL.md` files or current runtime docs, not README claims.
5. Preserve working trigger behavior unless the task is to change it.
6. Ask one question only when the requested behavior still has multiple valid interpretations after reading the relevant files.
7. Before finishing, run a subtraction pass: merge what you duplicated, relocate what drifted from its section, move rare detail to a reference. Rewrite existing wording only when the change is a clear win, shorter without losing information; leave a dense sentence alone when every clause carries weight. The edit should leave the skill net flat or shorter unless it added genuinely new behavior.

## Routing

The `description` is the routing surface for model-invocable skills. Write it before the body. For `/`-only skills (`disable-model-invocation: true`) it is a human-facing menu line, not a router trigger, so the trigger guidance below does not apply; see Frontmatter for how to word it.

```yaml
description: <capability>. Use when <specific triggers>.
```

- Include task verbs, artifact types, file extensions, user phrases, or contexts that should trigger the skill.
- Add `Not for...` only when a realistic nearby task would otherwise select the wrong skill. Name the competing task or alternate route.
- For paired or tiered surfaces, name the boundary in the description: lightweight search/read connector vs advanced API connector, read-only browse vs write/manage, local CLI vs remote host, public source vs private workspace.
- Do not exclude a broader user request that can legitimately include this skill as a step, such as using a commit step inside a requested push. Put write, push, delete, or credential safety limits in the body workflow instead.
- Keep it under 1024 characters. If that feels hard, split the skill or narrow scope.
- Bad: `Helps with documents.`
- Good: `Extract tables from PDFs and export them as CSV or XLSX. Use when the user gives a PDF and asks for table extraction, spreadsheet conversion, or tabular cleanup.`

## Frontmatter

Target this local Claude Code and Codex setup in one `SKILL.md`. Keep portable discovery fields (`name`, `description`) clear because both runtimes use them to route. Add `when_to_use` only when extra routing context is worth a field some clients may ignore. Treat the other fields as Claude Code-specific execution metadata; behavior required in both runtimes belongs in the body. Use the [Agent Skills frontmatter spec](https://agentskills.io/specification#frontmatter) for the portable `SKILL.md` baseline and the [Claude Code frontmatter reference](https://code.claude.com/docs/en/skills#frontmatter-reference) for Claude-specific fields, types, and defaults.

- Prefer a short, easy-to-type `name`/directory slug; drop category nouns the description already carries (a platform word in the name duplicates the description and invites renames).
- Use `disable-model-invocation: true` to stop Claude from auto-loading the skill. Use it for workflows that should run only when the user invokes `/name`, such as deploys, commits, external messages, or other side effects.
- For a command-like skill (`disable-model-invocation: true`), write its `description` as a one-line human-facing `/` menu summary, not a `Use when...` trigger list. Auto-loading is off, so triggers there are dead text; keep rich triggers on model-invocable skills, where they drive selection.
- Use `user-invocable: false` only to hide a skill from Claude Code's `/` menu; it does not block model invocation.
- Use `context: fork` for explicit long-running tasks, independent review, or research. Do not put passive reference knowledge in a fork-only skill.
- Only add `argument-hint`, `arguments`, `agent`, `paths`, `shell`, `model`, `effort`, or `hooks` when they change invocation or execution. `$ARGUMENTS` substitution is Claude Code-only (Codex injects the literal token), so never let dual-runtime behavior depend on it; word the instruction to fall back to the user's accompanying message.
- Treat `allowed-tools` as Claude Code pre-approval metadata, not a deny-list. For bash examples, include command-scoped entries that match the fenced commands. Use `disallowed-tools` to remove tools from the model while the skill is active (cleared when the user sends the next message); reserve permission deny rules for blocking a tool globally.

## Structure

Choose the smallest shape that preserves behavior:

- One durable instruction: frontmatter plus one imperative paragraph.
- Repeated workflow: short `Process` with numbered steps.
- Branching intent: `Mode Picker` before mode details.
- Fragile or repeated command: script with fixed inputs and validation. Reference bundled scripts as relative links from `SKILL.md`, resolved against the skill's own directory: derivable in both runtimes, unlike Claude Code-only `${CLAUDE_SKILL_DIR}` or a hardcoded install path. Keep an overridable env var (`"${VAR:-<default>}"`) only when a script must also run from outside the skill tree.
- Tool-rich API/MCP surface: short lookup workflow that caches or splits the tool schema, reads only the relevant tool docs, then calls the tool.
- Rare or bulky detail: one-level `references/` file.
- Ephemeral output shape: inline template or short `examples/`.
- Durable cross-session or shared artifact: a one-hop `<NAME>-FORMAT.md` contract carrying a filled template, a when-to-write gate, and lifecycle rules. Link it from `SKILL.md` and load it before writing that artifact, or it becomes dead documentation. Use it only when the schema must hold across writes or sessions or another skill shares it; below that bar keep the shape inline.
- Reusable final artifacts: `assets/`.
- Term-dense or ambiguity-sensitive workflow: a short `Glossary`, with `Avoid` synonyms only when term drift changes routing, artifact schema, or safety.

Use 100 lines as pressure, 200 as a review point. Keep routing, safety, tool choice, validation, and output detail when they justify the length. After compaction Claude Code re-attaches only the first ~5,000 tokens per skill (25,000 combined) and Codex drops the body entirely, so put routing, safety, and critical rules near the top of the file.

## Writing Rules

- Start with what the loaded skill must do, not why the skill exists.
- Use imperative sentences. One sentence should produce one behavior.
- Put the common path in `SKILL.md`; move rare branches, long examples, and lookup material out.
- Keep runtime context lean, not just `SKILL.md` itself: narrow reads with filters, time windows, limits, explicit fields, or exact IDs; request structured output when available; save a bulky raw response to a temp file instead of into context; then project only the needed fields as TSV, a small table, or a field summary. If a CLI defaults to a human table, show the machine-readable flags and field selection path.
- Prefer values the runtime or code can derive over counts, paths, or amounts hardcoded into prose. A literal like "the four flags" or an absolute path is a maintenance hazard the moment the underlying value changes; point at the source of truth or how to read it.
- For API, SDK, CLI, platform, or MCP claims, cite current docs, installed help, generated types, source paths, or checked-in examples. If evidence is unavailable, write a research or audit deliverable instead of guessing.
- Don't instruct the agent to echo, transcribe, or explain its internal reasoning in response text ("show your thinking", "explain your reasoning step by step"). Claude Fable-class models refuse these with the `reasoning_extraction` category and fall back to a weaker model; require conclusions plus evidence (paths, quotes, links) instead.
- Keep examples only when they prove output shape, trigger boundaries, a failure mode, or a quality boundary (acceptable vs unacceptable output at the same correctness level).
- In every skill edit, mask project names, personal names, hosts, private paths, clients, internal URLs, credential variable names, token variables, repo paths, and customer data; use them only in a skill explicitly scoped to that private environment.

## Rule Hygiene

Before adding a rule, find the closest existing rule. Merge when the trigger, action, or boundary overlaps; replace when the old wording is wrong. When several problems share one root cause, write one rule that covers them all rather than one per problem. Add a standalone rule only when no existing rule covers the failure mode.

Keep a rule when it changes agent behavior and names at least three of: trigger, action, boundary, evidence.

**Formatting carries behavioral weight.** A standalone heading, a bolded imperative, or a calibration example gives a rule higher priority in the agent's reading. Merging a heading-level rule into a bullet, unbolding an imperative, or deleting a before/after example downgrades it, so a rule that restates a nearby one at higher prominence is reinforcement, not redundancy: merge the text but keep the prominence. Before downgrading, confirm the weight does not depend on the prominence.

For evaluator, verifier, rubric, PASS/FAIL, completion-gate, or transcript-derived rules, require the trigger, evidence, PASS/FAIL or manual-observation condition, action to take on failure or stop, and owner. The owner must be the project skill, target repo, user confirmation, or CLI/runtime. Keep trace stores, durable session logs, sandbox state, and automatic progress ledgers out of shared skill text unless every target runtime supports the mechanism or the skill explicitly branches by runtime. For transcript-derived rules, cite bounded evidence internally, distill the reusable failure mode, and do not copy raw transcript prose into public skills.

Delete or merge rules that:

- duplicate another rule without adding a sharper boundary or higher prominence (redundancy).
- say to be careful, robust, high quality, concise, or thoughtful without a check
- explain agent skills, progressive disclosure, or repo background without changing the next action
- assume a tool, account, server, path, model, runtime, or workflow without saying how to verify it
- copy a project-specific incident, user correction, or a rule that only fits the example skills you studied, instead of extracting the reusable pattern
- state what a competent agent would already do unprompted (filler). Test each line: if cutting it doesn't change the next action, cut it (e.g. a security skill explaining that leaked credentials are dangerous).

## Negative Wording

Use negative wording only when it improves routing, safety, or recovery:

- `Never`: irreversible actions, credential exposure, public leakage, destructive git, money movement, or production writes.
- `Do not`: common high-cost failures with a specific trigger.
- `Not for`: description-level routing boundary.
- `Avoid`: style pressure or rewrite direction, not a safety boundary.

Give each negative rule a recovery path: what to do instead, when to stop, or where to route.

## Verification

Run the checks that match the change and target runtime.

1. Use the skill repo's existing validator, package script, test, lint, or marketplace command first. For skills in this tree, run the [skills validator](../scripts/validate-skills.rb) with `ruby`, resolving the link against this skill's own directory, not the cwd (see `--help` for smoke and deployed-file flags); do not hand-roll frontmatter or reference-link checks.
2. Verify YAML frontmatter, local-runtime fields, one-hop file references, and changed scripts.
3. For model-invocable skills, exercise triggers: 3 obvious should-trigger prompts, 3 paraphrases, and 3 near-miss should-not-trigger prompts. For important skills, use 8-10 each. Skip this for `disable-model-invocation` skills the model never auto-loads.
4. If the skill under-triggers, add user phrases, artifact types, or task verbs to `description`. If it over-triggers, narrow the trigger, add one specific `Not for...`, or split the skill.
5. For rewrites, state what behavior stayed the same, what changed, and why.
6. Run changed scripts with fixed inputs. Confirm clear stdout, stderr, exit codes, and failing-path messages.
7. For any skill edit, scan the current diff for private repo names, personal names, machine paths, hostnames, clients, credentials, internal URLs, and hardcoded-but-derivable literals.

## Output

For implementation work, report changed files, validation results, and behavior intentionally left unchanged.

For audits, report findings first with `path:line`, quoted evidence, and the exact rewrite direction.
