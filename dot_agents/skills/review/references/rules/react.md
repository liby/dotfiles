# React

Load when changed code touches React components, hooks, client state, streaming or optimistic UI, enabled or disabled controls, or user-facing messages.

**React state is not automatically the system truth.** Review which value the user sees, which value the server owns, and which later update can overwrite the visible state.

- first paint, pre-hydration interaction, post-hydration interaction, browser back or forward, and session-expiry behavior, naming the source of the value at each step.
- optimistic updates, streaming chunks, loading states, and error states against the durable server result, and the time to first useful response.
- effects that create timers, listeners, observers, subscriptions, or external-store reads, with their cleanup, server snapshot, and hydration behavior.
- keyboard, paste, drop, and submit shortcuts against IME composition, focus, disabled, readonly, and pending states.
- shared component API changes, design tokens, and arbitrary styling values when the repository already has a semantic component or token contract.

Data hidden in UI but still exposed through props, network, logs, or cached state: [boundaries](../concerns/boundaries.md). Loading, error, and empty states kept distinct: [failure-states](../concerns/failure-states.md). Session and auth source: [security](../concerns/security.md), [next.js](next.js.md). Runtime evidence for hydration or browser claims: [SKILL](../../SKILL.md).
