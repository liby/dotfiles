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

Write skills that change agent behavior. Keep routing, workflow, tool use, validation, and examples that affect the next action. Delete documentation that only explains skills, repeats best practices, or restates the heading.

## Process

1. Classify the request:
   - New or rewrite: edit the skill.
   - Trigger audit: report findings first; do not edit until asked.
   - Split or merge: change structure only when it improves routing or loaded context.
   - Distilled lesson: add a rule only when it has a trigger, action, boundary, and evidence.
2. If a skill path was given, read `SKILL.md` fully before judging. Read linked files only when they affect the requested change.
3. For non-trivial new skills, inspect 2-4 comparable local or public skills. Use actual `SKILL.md` files or current runtime docs, not README claims.
4. Preserve working trigger behavior unless the task is to change it.
5. Ask one question only when the requested behavior still has multiple valid interpretations after reading the relevant files.

## Routing

The `description` is the routing surface. Write it before the body.

```yaml
description: <capability>. Use when <specific triggers>.
```

- Include task verbs, artifact types, file extensions, user phrases, or contexts that should trigger the skill.
- Add `Not for...` only when a realistic nearby task would otherwise select the wrong skill. Name the competing task or alternate route.
- Do not exclude a broader user request that can legitimately include this skill as a step, such as using a commit step inside a requested push. Put write, push, delete, or credential safety limits in the body workflow instead.
- Keep it under 1024 characters. If that feels hard, split the skill or narrow scope.
- Bad: `Helps with documents.`
- Good: `Extract tables from PDFs and export them as CSV or XLSX. Use when the user gives a PDF and asks for table extraction, spreadsheet conversion, or tabular cleanup.`

## Frontmatter

Target this local Claude Code and Codex setup in one `SKILL.md`. Keep portable discovery fields (`name`, `description`) clear because both runtimes use them to route. Add `when_to_use` only when extra routing context is worth a field some clients may ignore. Treat the other fields as Claude Code-specific execution metadata; behavior required in both runtimes belongs in the body. Use the [Agent Skills frontmatter spec](https://agentskills.io/specification#frontmatter) for the portable `SKILL.md` baseline and the [Claude Code frontmatter reference](https://code.claude.com/docs/en/skills#frontmatter-reference) for Claude-specific fields, types, and defaults.

- Use `disable-model-invocation: true` to stop Claude from auto-loading the skill. Use it for workflows that should run only when the user invokes `/name`, such as deploys, commits, external messages, or other side effects.
- Use `user-invocable: false` only to hide a skill from Claude Code's `/` menu; it does not block model invocation.
- Use `context: fork` for explicit long-running tasks, independent review, or research. Do not put passive reference knowledge in a fork-only skill.
- Only add `argument-hint`, `arguments`, `agent`, `paths`, `shell`, `model`, `effort`, or `hooks` when they change invocation or execution.
- Treat `allowed-tools` as Claude Code pre-approval metadata, not a deny-list. For bash examples, include command-scoped entries that match the fenced commands. Use deny rules, not `allowed-tools`, to block tools.

## Structure

Choose the smallest shape that preserves behavior:

- One durable instruction: frontmatter plus one imperative paragraph.
- Repeated workflow: short `Process` with numbered steps.
- Branching intent: `Mode Picker` before mode details.
- Fragile or repeated command: script with fixed inputs and validation.
- Rare or bulky detail: one-level `references/` file.
- Output shape: inline template or short `examples/`.
- Reusable final artifacts: `assets/`.

Use 100 lines as pressure, 200 as a review point. Keep routing, safety, tool choice, validation, and output detail when they justify the length.

## Writing Rules

- Start with what the loaded skill must do, not why the skill exists.
- Use imperative sentences. One sentence should produce one behavior.
- Put the common path in `SKILL.md`; move rare branches, long examples, and lookup material out.
- For CLIs, teach the default path and non-obvious local constraints. Let the agent load option details with `<cmd> --help` or nearby source.
- For API, SDK, CLI, platform, or MCP claims, cite current docs, installed help, generated types, source paths, or checked-in examples. If evidence is unavailable, write a research or audit deliverable instead of guessing.
- Keep examples only when they prove output shape, trigger boundaries, or a failure mode.
- Mask project names, hosts, private paths, clients, internal URLs, and customer data in public skills.

## Rule Hygiene

Before adding a rule, find the closest existing rule. Merge when the trigger, action, or boundary overlaps; replace when the old wording is wrong. Add a standalone rule only when no existing rule covers the failure mode.

Keep a rule when it changes agent behavior and names at least three of: trigger, action, boundary, evidence.

Delete or merge rules that:

- repeat the description, heading, official docs, or a nearby rule
- say to be careful, robust, high quality, concise, or thoughtful without a check
- explain agent skills, progressive disclosure, or repo background without changing the next action
- assume a tool, account, server, path, model, runtime, or workflow without saying how to verify it
- copy a project-specific incident or user correction instead of extracting the reusable failure mode

## Negative Wording

Use negative wording only when it improves routing, safety, or recovery:

- `Never`: irreversible actions, credential exposure, public leakage, destructive git, money movement, or production writes.
- `Do not`: common high-cost failures with a specific trigger.
- `Not for`: description-level routing boundary.
- `Avoid`: style pressure or rewrite direction, not a safety boundary.

Give each negative rule a recovery path: what to do instead, when to stop, or where to route.

## Verification

Run the checks that match the change and target runtime.

1. Use the skill repo's existing validator, package script, test, lint, or marketplace command first.
2. Verify YAML frontmatter, local-runtime fields, one-hop file references, and changed scripts.
3. Exercise triggers: 3 obvious should-trigger prompts, 3 paraphrases, and 3 near-miss should-not-trigger prompts. For important skills, use 8-10 each.
4. If the skill under-triggers, add user phrases, artifact types, or task verbs to `description`. If it over-triggers, narrow the trigger, add one specific `Not for...`, or split the skill.
5. For rewrites, state what behavior stayed the same, what changed, and why.
6. Run changed scripts with fixed inputs. Confirm clear stdout, stderr, exit codes, and failing-path messages.
7. For public skills, scan for private repo names, machine paths, hostnames, clients, credentials, and internal URLs.

## Output

For implementation work, report changed files, validation results, and behavior intentionally left unchanged.

For audits, report findings first with `path:line`, quoted evidence, and the exact rewrite direction.
