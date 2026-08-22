---
name: write-skill
description: Create, rewrite, or audit agent skills and reusable agent instructions. Use for skill routing, workflow or wording optimization, validation, and splitting or merging skills. Not for application-code review, running an existing skill without changing it, or deleting a skill without redesign or replacement.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
---

# Write Skill

Write skills that change agent behavior. Use established domain terms when they preserve the intended trigger and boundary. Keep routing, workflow, tool use, validation, examples, and rationale only when they change the next action or choice. Cut explanatory restatements, intermediate history, repeated best practice, and competent-agent defaults.

## Process

1. Classify the request, and produce the smallest artifact it needs (a one-off standard, phrasing, or lesson belongs in your reply as prose, not a new `SKILL.md`):
   - New or rewrite: edit the skill.
   - Trigger audit: report findings first; do not edit until asked.
   - Split or merge: change structure only when it improves routing or loaded context.
   - Distilled lesson: add a rule only if it clears Rule Hygiene.

   When a step sequence keeps finishing early, sharpen that step's done-condition first (local and cheap); split into a separate skill only when the condition cannot be sharpened further and the rush is actually observed in real runs. Splitting pays off only across a real context boundary (a `context: fork` skill, a subagent dispatch, or a user `/name` invocation hand-off): an inline model-invoked skill call leaves the later steps in the same window and clears nothing. When a rename, split, merge, or replacement removes a skill, `rg` sibling skills' `description`, `when_to_use`, and body routing lines and update every pointer. A direct deletion with no redesign or replacement belongs to the repository's normal file-removal workflow.
2. If a skill path was given, read `SKILL.md` fully before judging; read linked files only when they affect the change. Re-read right before any full-file rewrite, and Read before Edit/Write when resuming after compaction, because an edit since your last read (including the user's own manual trim) is silently lost; prefer targeted edits over rewriting the whole file. When the edit tool rejects a stale or unread file ("File has not been read yet" in Claude Code), read the file once and retry; never repeat the identical edit call.
3. Diagnose across the instruction graph, not just the named file. When observed behavior violates an existing rule, verify that the runtime loaded it, identify its narrowest owner and any higher-priority or conflicting instruction, then fix that load, ownership, priority, or conflict before rewriting the rule. Otherwise check whether one root cause explains the same symptom elsewhere and fix it once.
4. For non-trivial new skills, inspect 2-4 comparable local or public skills. Use actual `SKILL.md` files or current runtime docs, not README claims.
5. Preserve working trigger behavior unless the task is to change it.
6. Ask one question only when the requested behavior still has multiple valid interpretations after reading the relevant files.
7. Before finishing, run a subtraction pass: merge what you duplicated, delete what went stale, relocate what drifted from its section, disclose rare detail into a reference. Rewrite existing wording only when the change is a clear win, shorter without losing information; leave a dense sentence alone when every clause carries weight. The edit should leave the skill net flat or shorter unless it added genuinely new behavior.

## Routing

The `description` is the routing surface for model-invocable skills. Write it before the body. Name the capability or outcome the skill owns, then the stable user intent, artifact, product, or context that should select it. `Use when` is a useful sentence form, not a required template. For manual-only skills, write a short human-facing menu line instead; see Frontmatter.

- Start from observed prompts, tool history, repository vocabulary, and realistic adjacent tasks. Do not invent quoted user phrases.
- Treat literal phrases, aliases, and cross-language or register variants as candidates, not a checklist. Keep one only when history or a fixed routing evaluation shows that it recovers a real miss or preserves a meaningful boundary.
- Do not patch a failed query by copying its exact wording into the description. Generalize the intent or artifact category, then validate it on held-out prompts.
- Explicit `/name` or `$name` invocation does not need to be repeated in the description to work. Explicit-use history describes user behavior; it does not prove that implicit routing can be disabled.
- Add `Not for...` only when a realistic nearby task would otherwise select the wrong skill. Name the competing task or alternate route.
- For paired or tiered surfaces, name the boundary in the description: lightweight search/read connector vs advanced API connector, read-only browse vs write/manage, local CLI vs remote host, public source vs private workspace.
- Do not exclude a broader user request that can legitimately include this skill as a step, such as using a commit step inside a requested push. Put write, push, delete, or credential safety limits in the body workflow instead.
- Keep it under 1024 characters. If that feels hard, split the skill or narrow scope.
- Bad: `Helps with documents.`
- Good: `Extract tables from PDFs and export them as CSV. Use when a user needs tabular data from a PDF. Not for editing PDF page layout.`

## Frontmatter

Target this local Claude Code and Codex setup in one `SKILL.md`. Keep portable discovery fields (`name`, `description`) clear because both runtimes use them to route. Add `when_to_use` only when extra routing context is worth a field some clients may ignore. Treat the other fields as Claude Code-specific execution metadata; behavior required in both runtimes belongs in the body. Use the [Agent Skills frontmatter spec](https://agentskills.io/specification#frontmatter) for the portable `SKILL.md` baseline and the [Claude Code frontmatter reference](https://code.claude.com/docs/en/skills#frontmatter-reference) for Claude-specific fields, types, and defaults.

- Prefer a short, easy-to-type `name`/directory slug; drop category nouns the description already carries (a platform word in the name duplicates the description and invites renames).
- Use `disable-model-invocation: true` only when Claude Code should never auto-load the workflow. Side effects, cost, or timing make a skill a candidate for manual invocation, not proof: first verify its actual callers and sibling-skill loads. Write its `description` as a one-line human-facing `/` menu summary because Claude removes it from model context.
- For Codex manual-only routing, set `policy.allow_implicit_invocation: false` in the skill's `agents/openai.yaml`. Treat the Claude Code and Codex policies independently and verify both intended invocation paths.
- Do not set `disable-model-invocation` on a skill that other skills load: a skill-from-skill load is a model invocation, so the flag also removes the skill from their reach. A shared reference skill loaded by downstream skills stays model-invocable, with a `description` that names that downstream role; content shared between two `/`-only skills can only live in a plain linked file. Before setting the flag, `rg` sibling skills for the skill's name.
- Use `user-invocable: false` only to hide a skill from Claude Code's `/` menu; it does not block model invocation.
- Use `context: fork` for explicit long-running tasks, independent review, or research. Do not put passive reference knowledge in a fork-only skill.
- Only add `argument-hint`, `arguments`, `agent`, `paths`, `shell`, `model`, `effort`, or `hooks` when they change invocation or execution. `$ARGUMENTS` substitution is Claude Code-only (Codex injects the literal token), so never let dual-runtime behavior depend on it; word the instruction to fall back to the user's accompanying message.
- Treat `allowed-tools` as Claude Code pre-approval metadata, not a deny-list. For bash examples, include command-scoped entries that match the fenced commands. Do not name a destructive verb in an entry (`Bash(git push:*)`, `Bash(glab mr merge:*)`): that is a deliberate targeted pre-approval of the exact dangerous command, and a broad wildcard covering it silences the prompt just the same, so gate destructive commands with a body workflow rule (explicit user request) or a permission ask/deny rule, never with allowed-tools scoping. Use `disallowed-tools` to remove tools from the model while the skill is active (cleared when the user sends the next message); reserve permission deny rules for blocking a tool globally.

## Structure

Choose the smallest shape that preserves behavior:

- One durable instruction: frontmatter plus one imperative paragraph.
- Repeated workflow: short `Process` with numbered steps.
- Branching intent: `Mode Picker` before mode details.
- Fragile or repeated command: script with fixed inputs and validation. Reference bundled scripts as relative links from `SKILL.md`, resolved against the skill's own directory: derivable in both runtimes, unlike Claude Code-only `${CLAUDE_SKILL_DIR}` or a hardcoded install path. Keep an overridable env var (`"${VAR:-<default>}"`) only when a script must also run from outside the skill tree. Derive script output paths from the runtime (`tmpdir()`, `$TMPDIR`) instead of hardcoding `/tmp/...`: hosting agents sandbox different temp directories, and a hardcoded path fails with a write denial under one of them.
- Tool-rich API/MCP surface: short lookup workflow that caches or splits the tool schema, reads only the relevant tool docs, then calls the tool.
- Rare or bulky detail: one-level `references/` file. State each link's load condition ("Load when <trigger>", not a bare "see X"); the pointer's wording, not its target, decides whether the file gets read.
- Ephemeral output shape: inline template or short `examples/`.
- Durable cross-session or shared artifact: a one-hop `<NAME>-FORMAT.md` contract carrying a filled template, a when-to-write gate, and lifecycle rules. Link it from `SKILL.md` and load it before writing that artifact, or it becomes dead documentation. Use it only when the schema must hold across writes or sessions or another skill shares it; below that bar keep the shape inline.
- Reusable final artifacts: `assets/`.
- Term-dense or ambiguity-sensitive workflow: a short `Glossary`, with `Avoid` synonyms only when term drift changes routing, artifact schema, or safety.

Use 100 lines as pressure, 200 as a review point. Keep routing, safety, tool choice, validation, and output detail when they justify the length. Past the threshold, diagnose which disease the length is before picking a cure. Stale accumulation gets deleted, not moved into `references/` where the rot keeps living. The same meaning written in several places merges back to a single home. Only when every line is alive and the file is still long is it structural surgery: push material that only some paths need down into `references/`, keep the common path inline; deleting lines cannot cure this one.

Runtimes keep skill metadata broadly visible but may truncate, reattach, or omit body content under context limits. Put routing in the description and keep safety, recovery, and critical workflow rules near the top of the body.

## Writing Rules

- Start with what the loaded skill must do, not why the skill exists.
- Use imperative sentences. One sentence should produce one behavior. When one rule maps several conditions to different actions, write a condition -> action list instead of packing the branches into one sentence: in A/B runs the packed prose form reliably dropped one branch on GPT-5.6 while the list form dropped none, with no regression on either target model. A dense single-condition sentence whose every clause carries weight stays as is.
- Put the common path in `SKILL.md`; move rare branches, long examples, and lookup material out.
- Keep runtime context lean, not just `SKILL.md` itself: narrow reads with filters, time windows, limits, explicit fields, or exact IDs; request structured output when available; save a bulky raw response to a temp file instead of into context; then project only the needed fields as TSV, a small table, or a field summary. If a CLI defaults to a human table, show the machine-readable flags and field selection path.
- Prefer values the runtime or code can derive over counts, paths, or amounts hardcoded into prose. A literal like "the four flags" or an absolute path is a maintenance hazard the moment the underlying value changes; point at the source of truth or how to read it.
- For API, SDK, CLI, platform, or MCP claims, cite current docs, installed help, generated types, source paths, or checked-in examples. If evidence is unavailable, write a research or audit deliverable instead of guessing.
- Do not request hidden reasoning or step-by-step internal thought. Require conclusions plus observable evidence such as paths, quotes, links, and command results instead.
- Keep examples only when they prove output shape, trigger boundaries, a failure mode, or a quality boundary (acceptable vs unacceptable output at the same correctness level). A worked example must obey the skill's own rules: when it conflicts with a stated rule, models copy the example, so fix whichever one is wrong. A labeled negative example is exempt from the one rule it demonstrates breaking.
- Give every conditionally applicable template or output slot a legitimate empty form, such as "same as the minimal proposal; no structural change indicated"; a slot that must always be filled invites invented content. A slot whose absence must stop the workflow, such as a missing approval or an unresolved destructive target, keeps no empty form.
- In every skill edit, mask project names, personal names, hosts, private paths, clients, internal URLs, credential variable names, token variables, repo paths, and customer data; use them only in a skill explicitly scoped to that private environment.

## Rule Hygiene

Before adding a rule, search the runtime-visible global instructions and relevant sibling skills for the same trigger. Merge with the narrowest owner when the trigger, action, or boundary overlaps, replace wrong wording, and add only a failure mode no owner covers.

Keep a rule when it changes agent behavior and names at least three of: trigger, action, boundary, evidence.

Use headings, bold imperatives, and examples only to expose a distinct routing, safety, recovery, completion, or quality boundary. Formatting does not justify duplicate wording. Keep a calibration example when it proves a difference that prose alone does not make testable.

For evaluator, verifier, rubric, PASS/FAIL, or completion-gate rules, require trigger, evidence, an acceptance or manual-observation condition, failure action or stop, and owner: project skill, target repo, user confirmation, or CLI/runtime.

For transcript-derived rules, exclude duplicated forked or replayed material from independent counts, and treat quoted, pasted, or carried-forward material as context rather than independent preference evidence unless the user explicitly adopts it; count the explicit adoption, not the duplicated source. Pair a rejection with the rejected output and an accepted successor when available, separate repeated behavior from artifact-local or one-off corrections, and write the reusable failure mode in its narrowest existing owner without copying raw transcript prose.

Triage each observed failure before editing:

- The skill never stated the rule: add it, gated by this section.
- The rule loaded but was skipped: sharpen wording, placement, or a done-condition; do not restate content.
- The feedback is specific to one codebase or session, and the skill does not own that scope: change nothing there; route the fix to the narrowest owner of that scope, such as the repository's own instructions or a skill that owns it.
- The transcript shows a recurring self-authorization, such as treating the user's report as sufficient evidence to skip a check: counter that pattern at the step it derails, stated abstractly, not in the session's verbatim words.

Treat an approach the user confirmed as a constraint: do not weaken it while fixing something else, and never copy the session's exact failing instance into the skill, or the session stops working as a regression probe.

The completion bar reaches past evaluator rules: in any skill with a Process, end each numbered step on a checkable done-condition, its demand graded to the coverage the step must force ("every changed file accounted for" forces digging; "produce a change list" does not; "understanding reached" is not even checkable). A flat rules-only skill carries one exhaustiveness bar instead, such as "apply every loaded rule to every hunk"; a single-paragraph skill is exempt.

Keep trace stores, durable session logs, sandbox state, and automatic progress ledgers out of shared skill text unless every target runtime supports the mechanism or the skill explicitly branches by runtime.

Delete or merge rules that:

- duplicate another rule without adding a sharper boundary or higher prominence
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

Put the gate for a sensitive or irreversible step adjacent to the instruction that performs it: the same step, table row, or sentence. This includes `references/` files and scripts, because a documented step sequence is an execution plan to the agent walking it; a warning parked in another section does not fire at the step.

## Verification

Run the checks that match the change and target runtime.

1. Use the skill repo's existing validator, package script, test, lint, or marketplace command first. For skills in this tree, run the [skills validator](../scripts/validate-skills.rb) with `ruby` and pass `--smoke`, resolving the link against this skill's own directory, not the cwd; do not hand-roll frontmatter or reference-link checks.
2. Verify YAML frontmatter, local-runtime fields, one-hop file references, and changed scripts.
3. Before changing a model-invocable description or material global `AGENTS.md`/`CLAUDE.md` behavior, freeze the baseline bytes and cases. For a description, use 3 obvious should-trigger prompts, 3 paraphrases, and 3 near misses (8-10 each for important skills), keeping explicit `/name` and `$name` controls separate. For global behavior, use representative target, adjacent no-change, and proportionality cases in every intended runtime. Sanitize history-derived cases.
4. Evaluate baseline and candidate against the same runtime-visible inputs and retain a change only when its target behavior improves with no paired regression; rerun nondeterministic boundaries when cost permits. For a skill that claims to change output quality, also run the same cases with and without the skill: the with/without delta is the skill's value. Exclude assertions that pass in both configurations from the value claim but keep them as regression controls; investigate assertions that fail in both. For routing, capture the complete catalog when confidentiality permits; otherwise disclose exclusions, label the narrower comparison a managed-catalog proxy, and add actual runtime probes for realistic collisions. Count `invoked` only when the client loads the full `SKILL.md`, and label classifier output `selected`.
5. Use evaluation failures to revise the general intent, artifact, or nearby-task boundary; keep a validation split hidden, then try fresh prompts before accepting an important rewrite. When a real run skips a linked file, sharpen the pointer's trigger before inlining the material.
6. For rewrites, state what behavior stayed the same, what changed, and why.
7. Run changed scripts with fixed inputs. Confirm clear stdout, stderr, exit codes, and failing-path messages.
8. For any skill edit, scan the current diff against the masking rule in Writing Rules, plus hardcoded-but-derivable literals.

## Output

For implementation work, report changed files, validation results, and behavior intentionally left unchanged.

For audits, report findings first with `path:line`, quoted evidence, and the exact rewrite direction.
