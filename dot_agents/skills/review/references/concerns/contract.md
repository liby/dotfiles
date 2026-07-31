# Contract And Naming

Load when changed code defines or changes a contract other code depends on: types, schemas, enums, discriminated unions, event names, storage keys, exported identifiers, numeric policy, units, or generated artifacts.

**Judge the implementation against the source owner.** Find where a value becomes authoritative: an upstream schema, generated type, wrapper, or documented rationale.

Do not map ambiguous requirement language to a field, role, team, or state unless a requirement owner, authoritative contract, established repository semantics, or direct clarification establishes the mapping. If the mapping changes the verdict, report the unresolved requirement; still report behavior that violates every plausible mapping or an explicit default-deny contract. When prose conflicts with a source-owned schema or observed data, report the owning requirement as wrong or unresolved instead of preserving the mismatch in a local code comment.

For a changed name, state, or enum, search writers and readers. Report only disagreement about meaning, a hidden reachable side effect or transition, or generated/user output that misstates an actionable contract.

For a threshold, rate, or conversion, verify unit and direction against the source owner. Stale prose is reportable only when authoritative or able to cause an operational or migration error.

Before deleting, renaming, disabling, or narrowing a supported contract, verify current consumers and migration. For generated files, review the source input and regeneration command.
