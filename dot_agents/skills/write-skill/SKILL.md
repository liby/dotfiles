---
name: write-skill
description: Write or improve agent skills with clear triggers, executable workflows, progressive disclosure, and validation. Use when creating a new skill, rewriting an existing skill, auditing skill trigger behavior, or turning repeated agent behavior into reusable instructions.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# Write Skill

Write skills that change agent behavior. Keep mechanism, workflow, routing, validation, and examples that change what the agent does.

## First Move

1. Classify the task: new skill, rewrite, audit, split, merge, or distilled lesson.
2. If a skill path was given, read `SKILL.md` fully before judging. Read linked files only when they affect the requested change.
3. For non-trivial new skills, inspect 2-4 comparable local or public skills. Record what to adopt, adapt, and reject. Verify actual `SKILL.md` or source, not README claims.
4. If the task is still ambiguous, ask one question tied to what you found. Do not run a setup interview by default.
5. State the deliverable before editing: skill folder, patch, audit findings, extraction plan, or verification plan.

## Trigger

The `description` is the routing surface. Write it before the body.

Shape:

```yaml
description: <capability>. Use when <specific triggers>. Not for <nearby tasks>.
```

Rules:

- Include task verbs, artifact types, file extensions, user phrases, or contexts that should trigger the skill.
- Add `Not for...` when a nearby skill or generic model behavior should handle the task instead.
- Keep it under 1024 characters. If that feels hard, split the skill or narrow scope.
- Bad: `Helps with documents.`
- Good: `Extract tables from PDFs and export them as CSV or XLSX. Use when the user gives a PDF and asks for table extraction, spreadsheet conversion, or tabular cleanup.`

## Invocation

Choose the loading mode before adding body rules:

- Auto-invoked: safe, common task with clear triggers.
- Manual-only: side effects, explicit arguments, expensive work, or risky empty-input behavior. Use the target runtime's manual-invocation field when available.
- Background knowledge: facts or policy that should inform other skills but is not user-invoked. Use the target runtime's background or non-invocable field when available.
- Forked or isolated context: long research, independent review, or work that should not pollute the parent context.

Treat `name` and `description` as the cross-platform minimum. Add fields such as `allowed-tools`, `argument-hint`, `user-invocable`, `disable-model-invocation`, `context`, `license`, or `metadata` only after checking that the target runtime consumes them.

Describe `allowed-tools` as runtime capability metadata. Treat it as a safety boundary only after verifying that the runtime enforces it.

## Shape

Choose the smallest shape that preserves behavior.

- One durable instruction: frontmatter plus one imperative paragraph.
- Repeated workflow: short `Process` with numbered steps.
- Branching intent: `Mode Picker` before mode details.
- Fragile or repeated command: script with fixed inputs and validation.
- Rare or bulky detail: one-level `references/` file.
- Output quality needs examples: short `examples/` or reference sample.
- Reusable output files: `assets/` or template files.
- Output template copied often: inline it.

Use 100 lines as pressure, 200 as a strong warning, and 500 as a hard review point. Keep routing, safety, tool choice, validation, and output detail even when they push the file longer.

Use tables only for stable matrices: mode pickers, option maps, CLI/env maps, or fixed-column output. Use numbered steps for workflows, bullets for one-to-one rules, and fenced formats for headless or machine-readable output.

## Resources

- `references/`: large facts, API docs, schemas, policy, pattern catalogs, or rare branches. Keep references one hop from `SKILL.md`; add a top summary when a file gets long.
- `scripts/`: deterministic, repeated, fragile, or error-prone operations. The skill should usually execute scripts, not paste their source into context.
- `examples/`: short samples that teach output shape, trigger boundaries, or before/after behavior.
- `assets/`: files used in the final artifact, such as templates, icons, fonts, starter files, or boilerplate.

For API, SDK, CLI, platform, or MCP skills, lock behavior claims to a current docs URL, package name, installed version, generated type, source path, or official command. If that evidence is unavailable, write a research or audit deliverable instead of guessing APIs.

## Draft

- Start with what the loaded skill must do, not why the skill exists.
- Use imperative sentences. One sentence should produce one behavior.
- Put the common path in `SKILL.md`; move variants, long examples, and lookup material out.
- For self-describing tools such as CLIs, teach the default path and non-obvious local constraints. Let the agent load option details with `<cmd> --help` or nearby source; if one command affects several places, name only the place that changes the next action.
- Prefer positive action rules: `Read SKILL.md fully, then preserve working triggers while changing only the requested behavior.`
- Keep examples close to the rule they prove. Delete examples that merely decorate the rule.
- Mask project names, hosts, private paths, clients, internal URLs, and customer data in public skills.
- For an existing skill, preserve working trigger behavior unless the task is to change it.

## Rule Test

Keep a rule when it names at least three:

- Trigger: when the rule applies.
- Action: what the agent should do.
- Boundary: when to stop, ask, refuse, or switch modes.
- Evidence: command, file, output, source, or check that proves compliance.

If a rule has no trigger, it is probably generic advice. If it has no action, it is commentary. If a risky rule has no evidence, it is a preference pretending to be a gate.

## Negative Language

Use negative wording only when it improves routing, safety, or recovery.

- `Never`: irreversible actions, credential exposure, public leakage, destructive git, money movement, production writes.
- `Do not`: common high-cost failures with a specific trigger, such as overwriting user files, inventing paths, broadening scope, or skipping validation.
- `Not for`: description-level routing boundary.
- `Avoid`: style pressure or rewrite direction, not a safety boundary.

Every negative rule needs a recovery path: what to do instead, when to stop, or where to route.

Pattern:

- Weak: `Do not rewrite the whole skill.`
- Strong: `Preserve working triggers, then change only the requested behavior and its direct validation.`
- Keep negative when needed: `Never print secrets. Tell the user where to inspect or rotate them instead.`

## Compression Test

For every paragraph, ask: would an agent act differently because this exists?

Delete it when it:

- Explains agent skills, progressive disclosure, or repo background without changing the next action.
- Repeats the description or heading.
- Says to be careful, thoughtful, robust, elegant, or high quality without a check.
- Lists broad best practices that apply to every task.
- Copies a project-specific incident instead of extracting the reusable failure mode.
- Assumes a tool, account, server, path, model, runtime, or workflow exists without telling the agent how to verify it.

Keep it when it:

- Changes trigger routing or excludes a nearby skill.
- Prevents unsafe writes, overwrites, public leakage, or hidden state changes.
- Names a command, file shape, output contract, or validation gate.
- Captures a non-obvious failure mode as a rule, check, or script.
- Distinguishes similar modes that would otherwise collide.

## Verification

Run the checks that match the change and target runtime.

1. Use the skill repo's existing validator, package script, test, lint, or marketplace command first.
2. Verify `SKILL.md` has YAML frontmatter with `name` and `description`. If no validator exists, use any available YAML parser without installing packages.
3. Verify referenced files are reachable in one hop from `SKILL.md`.
4. Exercise triggers: 3 obvious should-trigger prompts, 3 paraphrases, and 3 near-miss should-not-trigger prompts. For important skills, use 8-10 should-trigger and 8-10 near-miss prompts.
5. If the skill does not trigger, add user phrases, artifact types, or task verbs to `description`. If it over-triggers, add `Not for...`, narrow scope, or split the skill.
6. Run changed scripts with fixed inputs. Confirm clear stdout, stderr, exit codes, and failing-path messages.
7. For public skills, scan for private repo names, machine paths, hostnames, clients, credentials, and internal URLs.
8. For rewrites, report what behavior stayed the same, what changed, and why.
9. For important skills, compare one realistic task with and without the skill. The skill should reduce correction, uncertainty, tool misuse, or output drift.

Use the target repo's validator first. Name `uv`, `bun` or another runtime only when the target repo already depends on it or the command is explicitly local-only.

## Gotchas

- Short but vague skill: add trigger examples, output contract, or validation before deleting more.
- Long but useful skill: split rare detail to `references/`; keep the common path loaded.
- Description over-triggers: add `Not for...`, narrow scope, or split the skill.
- Agent keeps asking setup questions: add a short read-only grounding step and one-question limit.
- Rule sounds right but changes nothing: convert it into a command, check, output shape, or delete it.
- Example names one project too closely: replace it with a pattern example or move it to a private journal.
- Multiple modes compete: add a mode picker or split the skill.
- Deterministic step is rewritten each run: move it to `scripts/`.
- Community skill has rich metadata: keep only fields consumed by the target runtime.
- Public examples disagree: prefer official spec for format, current runtime docs for behavior, and current local conventions for style.
- Skill auto-installs, posts, pushes, deletes, or writes outside the target folder: require explicit user request and a safety boundary.

## Output

For implementation work, report changed files, validation results, and behavior intentionally left unchanged.

For audits, report findings first with `path:line`, quoted evidence, and the exact rewrite direction.
