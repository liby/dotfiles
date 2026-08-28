# Agent And Provider Runtime

Load when changed code touches model routing, prompts, tool calls, connectors, skill registries, sandboxed execution, provider wrappers, usage accounting, protocol clients, or model-facing instructions.

- Verify provider-specific fields, nested shapes, feature subsets, routing, fallbacks, and protocol success/error bodies against a real payload or source-owned wrapper; one provider's type or mock does not prove another accepts the shape.
- Capture usage, token count, pricing, and cost while provider data is raw, and convert it once in the owner rather than re-deriving it from parsed text or summaries.
- Bind automated action inputs, including MR state, CI, logs, generated text, and comments, to the current head, run, or review snapshot.
- For every added, changed, or removed model-facing instruction, verify the earliest action it must constrain and the concrete wrong result its omission or wording can cause in a realistic target case. Treat duplicate owners, stale implementation history, irrelevant forbidden-concept priming, and examples that violate their rule as candidate evidence; report them only when they change routing, action, or output in such a case.
