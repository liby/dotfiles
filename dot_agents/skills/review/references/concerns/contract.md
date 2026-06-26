# Contract And Naming

Load when changed code defines or changes a contract other code depends on: types, schemas, enums, discriminated unions, event names, storage keys, exported identifiers, numeric policy, units, or generated artifacts.

**Judge the implementation against the source-owned contract, not the reverse.** Find where a value becomes authoritative (upstream schema, generated type, wrapper, documented rationale), and review the change against that owner before judging local behavior. Prefer existing wrappers, generated types, and source-owned values over local re-derivation.

## Names carry downstream meaning

A name states what a value means at its layer and whose perspective owns that meaning, not the step that produced it. Flag `is`/`has`/`check`/`validate`/`get` names that hide mutation, notification, scheduling, or a side effect; identifiers that encode a mutable threshold, fixture constant, or temporary implementation fact; and generated or user-facing output with no clear audience, trigger, or next action. For a changed name, state, or enum, grep the writers and the readers and confirm they still agree on the meaning.

## Numeric policy states unit and direction

For a threshold, rate, or conversion, the change should state unit and direction in one sentence. When a threshold moves, flag the comments and docs that now mislead.

## A changed contract reaches every consumer

When a contract changes, verify its current consumers and the migration path before deleting, renaming, disabling, or narrowing a supported API, model, route, output, or generated contract, rather than relying on age or preferred cleanup. When the diff includes generated files, find the source input and regeneration command and review those, not the generated output by hand. Keep a constant or helper local until a second owner needs it, and prefer a source-owned return or schema-derived type over a duplicate custom shape that can drift.

Enumerating peer surfaces that should share a changed concept: [mechanical](mechanical.md). Who owns the value across a process or provider boundary: [boundaries](boundaries.md).
