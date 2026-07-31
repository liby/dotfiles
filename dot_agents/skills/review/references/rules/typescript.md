# TypeScript

Load when changed code touches TypeScript API boundaries, exported identifiers, shared helpers, SDK wrappers, generated types, discriminated unions, serialization, or provider-shaped request and response objects.

- `as`, non-null `!`, and structural widening on external payloads, webhooks, events, or provider responses: narrow to the trusted shape before passing the value deeper.
- discriminated unions and `switch` arms without an exhaustiveness (`never`) guard, so a new variant fails loudly instead of falling through.
- runtime serialization when a value crosses a server/client, worker, queue, provider, database, or sandbox boundary.
