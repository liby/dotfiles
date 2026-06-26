# TypeScript

Load when changed code touches TypeScript API boundaries, exported identifiers, shared helpers, SDK wrappers, generated types, discriminated unions, serialization, or provider-shaped request and response objects.

**Types prove local shape, not runtime ownership.** A type checks at compile time; it does not validate what a process, provider, framework, or storage boundary actually sent. Review where a typed value crosses such a boundary.

- `as`, non-null `!`, and structural widening on external payloads, webhooks, events, or provider responses: narrow to the trusted shape before passing the value deeper.
- discriminated unions and `switch` arms without an exhaustiveness (`never`) guard, so a new variant fails loudly instead of falling through.
- optional chaining, `null`/`undefined` widening, and fallback values against the observed dirty-data source, not an imagined one.
- runtime serialization when a value crosses a server/client, worker, queue, provider, database, or sandbox boundary.

Generated types, naming, and consumers of a changed exported identifier: [contract](../concerns/contract.md). Who owns the value across the boundary, and one-off wrappers that only rename a caller: [boundaries](../concerns/boundaries.md). Provider field shapes: [agent](agent.md). Fixtures and proof claims: [tests](../concerns/tests.md).
