---
name: write-skill
description: Create, test, improve, or audit agent skills and behavior-bearing reusable instructions, including output styles, AGENTS.md/CLAUDE.md, agent rules or prompts, and examples or explanatory prose within those surfaces. Use for evidence-driven refinement, routing, workflow or wording optimization, validation, structural redesign, and instruction-owner audits. Not for application code, code comments, ordinary project documentation, running an unchanged skill, or deletion without redesign or replacement.
allowed-tools:
  - Bash
  - Agent
  - Read
  - Edit
  - Write
  - WebFetch
  - WebSearch
---

Write skills and reusable instructions that change agent behavior. A line earns its place when it carries what the agent would otherwise get wrong: an environment fact it cannot derive, runtime behavior that is not explicit, a capability boundary, a lesson from a real failure, or a convention the user settled. Test each line by naming the realistic case where omitting it causes a wrong action. Cut competent-agent defaults, restated best practice, intermediate history, and standards or principle lists every reader already accepts; write the concrete check they imply instead.

## Before editing

1. Produce the smallest artifact the request needs. A one-off standard, phrasing, or lesson belongs in your reply as prose, not in a new `SKILL.md`; a reusable instruction goes to its narrowest runtime-visible owner, which need not be a skill; Placement below lists the layers.
2. Resolve the owning source from current environment or repository instructions and edit it, not a deployed copy. When no owner is declared, change only an explicitly named path and do not adopt it into another registry as a side effect. Prefer targeted edits over rewriting the whole file, and re-read right before any full-file rewrite, because a rewrite silently drops any edit made since your last read, including the user's own manual trim.
3. When the request rests on evidence that an existing instruction produced wrong behavior (a user's correction of agent behavior, a failed run, review findings, eval results, or transcripts), load and follow the [evidence-driven improvement loop](references/improvement-loop.md) before judging or proposing a change; a request that only supplies a new fact or a wanted edit is not such evidence. When a candidate change touches model-invocable routing, conditional reference loading, claimed output quality, or material behavior of a global `AGENTS.md`/`CLAUDE.md` that loads in every session (a project-level instruction file is not global), load the [evaluation protocol](references/evaluation.md) before judging or accepting the candidate; it compares the frozen baseline with that candidate, so write a requested edit as the candidate instead of holding it until the evaluation runs.
4. Before adding a rule, search the runtime-visible global instructions and relevant sibling skills for the same trigger. When an owner already covers the trigger, action, or boundary, strengthen or correct its sentence in place instead of appending a new one elsewhere; add a rule only for a failure mode no owner covers.
5. For a non-trivial new skill, inspect 2-4 comparable local or public skills through their actual `SKILL.md` files or current runtime docs, not README claims.

## Placement

Place each instruction at the cheapest layer that reliably reaches the first action it must constrain; a rule that only a later step loads, such as a review-time skill, cannot prevent the initial mistake:

- Always-loaded `AGENTS.md` or `CLAUDE.md`: behavior every relevant task needs before routing or file inspection.
- A runtime-supported path rule: behavior required only when a matching path is touched.
- `SKILL.md`: the common path and gates every activation of that capability needs.
- One-level `references/`: a rare or bulky branch with an observable load condition stated in the parent before the branch's first action.
- A validated script, hook, permission, or test: fragile, repeated, or deterministic enforcement that cannot depend on model recall.

Splitting helps only when common runs avoid the moved material and target runs reliably follow the pointer. A file imported into the startup context is organization, not progressive disclosure. If every activation must read a reference, keep it inline; if the pointer cannot state when to load it, narrowing or deleting the material is safer than hiding it.

Put the gate for a sensitive or irreversible step beside the instruction that performs it, including in references and scripts; a warning in another section does not constrain an agent walking the sequence. Runtimes keep metadata visible but may truncate, reattach, or omit body content under context limits, so keep routing in the description and critical safety or recovery rules near the top of the body.

Split or merge skills only when that improves routing or loaded context. When a step sequence keeps finishing early, sharpen that step's done-condition first; split only when it cannot be sharpened and the rush is observed in real runs, because splitting pays off only across a real context boundary (a `context: fork` skill, a subagent dispatch, or a user `/name` hand-off) and an inline model-invoked skill call leaves the later steps in the same window. When a rename, split, merge, or replacement removes a skill, `rg` sibling skills' `description`, `when_to_use`, and body routing lines and update every pointer; a direct deletion with no replacement follows the repository's normal file-removal workflow.

## Routing

The `description` is the routing surface for model-invocable skills. Write it before the body: name the capability or outcome the skill owns, then the stable user intent, artifact, product, or context that should select it. `Use when` is a useful sentence form, not a required template. For manual-only skills, write a short human-facing menu line instead; see Frontmatter.

- Start from observed prompts, tool history, repository vocabulary, and realistic adjacent tasks. Do not invent quoted user phrases.
- Treat literal phrases, aliases, and cross-language or register variants as candidates, not a checklist. Keep one only when history or a fixed routing evaluation shows that it recovers a real miss or preserves a meaningful boundary.
- Do not patch a failed query by copying its exact wording into the description. Generalize the intent or artifact category, then validate it on held-out prompts.
- Explicit `/name` or `$name` invocation does not need to be repeated in the description to work. Explicit-use history describes user behavior; it does not prove that implicit routing can be disabled.
- Add `Not for...` only when a realistic nearby task would otherwise select the wrong skill. Name the competing task or alternate route.
- For paired or tiered surfaces, name the boundary in the description: lightweight search/read connector vs advanced API connector, read-only browse vs write/manage, local CLI vs remote host, public source vs private workspace.
- Do not exclude a broader user request that can legitimately include this skill as a step, such as using a commit step inside a requested push. Put write, push, delete, or credential safety limits in the body workflow instead.
- Keep it to at most 1024 characters. If that feels hard, split the skill or narrow scope.

## Frontmatter

Target the local Claude Code, Codex and Pi setup in one `SKILL.md`. Add `when_to_use` only when extra routing context is worth a field some clients may ignore. Check execution metadata against each target runtime; accepting a field does not prove that runtime enforces it. Shared behavioral requirements belong in the body. Use the [Agent Skills frontmatter spec](https://agentskills.io/specification#frontmatter) for the portable `SKILL.md` baseline and the [Claude Code frontmatter reference](https://code.claude.com/docs/en/skills#frontmatter-reference) for Claude-specific fields, types, and defaults.

- Prefer a short, easy-to-type `name`/directory slug; drop category nouns the description already carries (a platform word in the name duplicates the description and invites renames).
- Use `disable-model-invocation: true` only when Claude Code should never auto-load the workflow. Side effects, cost, or timing make a skill a candidate for manual invocation, not proof: first verify its actual human and model invocation paths, including sibling loads, because Claude treats a skill-from-skill load as model invocation. Write its `description` as a one-line human-facing `/` menu summary because Claude removes it from model context.
- For Codex manual-only routing, set `policy.allow_implicit_invocation: false` in the skill's `agents/openai.yaml`. Pi uses `disable-model-invocation: true` to hide the skill from its system prompt while retaining `/skill:name`. Verify implicit and explicit invocation in each target runtime rather than assuming their policies are interchangeable.
- Use `user-invocable: false` only when Claude Code users should not invoke the skill: it hides the skill from the `/` menu and stops `/name` from running it, but does not block model invocation.
- Use `context: fork` for explicit long-running tasks, independent review, or research. Do not put passive reference knowledge in a fork-only skill.
- Only add `argument-hint`, `arguments`, `agent`, `paths`, `shell`, `model`, `effort`, or `hooks` when they change invocation or execution. Keep shared skill behavior independent of host-specific argument interpolation; use invocation arguments or the user's accompanying request instead of embedding a runtime placeholder in body text.
- Treat `allowed-tools` as Claude Code prompt-free preapproval, not a deny-list, authorization rule, or cross-runtime capability contract. Match it to the normal contract when prompt-free execution is required: use exact entries only when the command set is exhaustive and stable, otherwise use `Bash(<program>:*)` or bare `Bash`, and validate that missing coverage cannot stop the workflow. Keep authorization requirements in the user request and skill body. Use `disallowed-tools` to remove tools from the model while the skill is active; reserve permission deny rules for blocking a tool globally.

## Writing the body

Organize the instruction around the decisions the agent must make: prerequisites before their dependent actions, the completion condition beside the step it closes, and each section establishing what the next may assume. Review order, transitions and sentence construction across the whole instruction, not sentence by sentence. State the trigger, action, and boundary in established domain terms when those terms preserve the intended trigger and boundary. Use a condition-to-action list when branches differ; keep a dense single-condition sentence when every clause affects behavior. Do not turn a feedback example into a new universal prohibition or add a list of synonyms to make a rule appear comprehensive.

Keep exact identifiers needed for execution, but derive changing counts, paths, and amounts from their owning source rather than copying a current census into prose. Mask private project, personal, host, client, customer, and credential identifiers in reusable skills; keep them only in skills explicitly scoped to that environment. This applies to every line you add, including an identifier copied from existing text or from the real case you are generalizing.

An example must demonstrate an output shape, trigger boundary, failure mode, or quality distinction that the rule alone leaves unclear. It must obey the instruction around it, except for the specific violation a labelled negative example demonstrates. A counterexample should expose a wrong decision rather than merely omit a required phrase.

A conditional output slot needs a legitimate empty form when nothing belongs there; do not force the agent to invent content to fill a template. A missing prerequisite that must stop the workflow, such as authorization for a destructive target, still stops it.

For evaluator, verifier, rubric, PASS/FAIL, or completion-gate rules, state the trigger, evidence, acceptance or manual-observation condition, failure action or stop, and owner: project skill, target repo, user confirmation, or CLI/runtime.

Preserve the operating meaning of instruction prose first; neither conversational style nor outbound-message conventions override a necessary trigger, exception, or stopping condition.

## Independence and portability

Keep reusable skills independently usable, and check commands, defaults, and side effects for policy leakage, not just wording:

- Keep a tool or runtime fact when it changes the command, input, output, or recovery path this skill owns. Put caller policy, source ownership, registry maintenance, adoption, deployment lifecycle, and repository policy in the environment or repository that owns them.
- Describe a prerequisite from another capability as an outcome. A sibling skill may provide it when available, but successful completion must not depend on that sibling being installed unless the dependency is an explicit part of this skill's contract.
- Link bundled files relative to `SKILL.md`, not through a host-specific skill-directory variable or install path, and derive temporary output paths from the runtime, because fixed temp paths fail across sandboxed hosts.
- Keep trace stores, durable session logs, sandbox state, and automatic progress ledgers out of shared skill text unless every target runtime supports the mechanism or the skill branches by runtime.
- Use a one-hop format contract only when its schema must survive across sessions or writers; give it a write trigger and lifecycle, and require loading it before writing the artifact.

## Finish

1. Run a subtraction pass before freezing a candidate for behavioral validation, or before finishing when there is none: merge what you duplicated, delete what went stale, relocate what drifted from its section, and disclose rare detail into a reference. Rewrite existing wording only when the change is a clear win without losing a trigger, boundary, example, or failure mode; leave a dense sentence alone when every clause carries weight. Shorter text and a lower line count are not acceptance criteria.
2. A validated candidate is its exact runtime-visible bytes and loading graph. Wording compression, examples, ordering, metadata, routing, relocation, and cleanup are behavior-relevant unless evidence establishes equivalence; after any such edit, rerun the affected checks before accepting or citing the result.
3. Run the owning repository's validator, package script, test, lint, or marketplace command; do not hand-roll checks it already owns.
4. Read every added line of the diff, not a `--stat` summary, check each private identifier and hardcoded value against the identifier rule in Writing the body, and fix every violation before finishing.
