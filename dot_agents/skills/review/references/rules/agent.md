# Agent And Provider Runtime

Load when changed code touches model routing, prompts, tool calls, connectors, skill registries, sandboxed execution, provider wrappers, usage accounting, protocol clients, or model-facing instructions.

**Natural language is not an authority boundary, and a typed response does not prove another provider accepts the same shape.** Model access, cost, protocol errors, and execution permissions need deterministic code-owned truth.

- provider-specific field names, nested shapes, feature subsets, routing tables, pricing, fallbacks, and protocol-shaped success and error bodies against a real payload or a source-owned wrapper; mocks do not prove another provider or protocol client accepts the shape.
- usage, pricing, token count, and cost captured while provider data is still raw, converted once in the owner, never re-derived from lossy parsed text or a generated summary.
- deterministic work before model work: let code own cheap filters, source-side narrowing, schema validation, allowlists, and dedupe, then use the model for the semantic part after the input is reduced.
- sandbox launch: configure stable runtime invariants at creation time, and validate user-controlled runtime settings before launch.
- automation input binding: bind MR state, CI state, logs, generated text, and review comments to the current head, run, or review snapshot before automation acts on them.
- prompt and instruction shape: concrete triggers and positive instructions, model-facing instructions kept separate from human-facing docs, and a helper script with one job rather than fetching and formatting bundled together.

Authority and capability routing, credential lifecycle, client-boundary filtering, and inert imports: [boundaries](../concerns/boundaries.md). Classifying values sent to a sandbox by trust level: [security](../concerns/security.md). Provider field shapes treated as a contract: [contract](../concerns/contract.md). Per-run model fan-out that scales cost: [data-integrity](../concerns/data-integrity.md). Fixtures and mocks that must match a real provider payload: [tests](../concerns/tests.md).
