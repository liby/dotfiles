# Async And Deferred Work

Load when changed code touches jobs, queues, schedulers, retries, waiters, webhooks, callbacks, background sync, durable workflow steps, or worker lifecycle.

**Async work can run zero times, once, many times, late, out of order, or after a durable step result has been memoized.** Draw the lifecycle from creation to terminal state and mark which code reruns on replay.

- duplicated side effects and short-lived authority kept out of replayable sections unless rerun is intentional and idempotent.
- waiters and event ordering: confirm the event cannot fire before the waiter starts, or use a direct trigger, durable subscription, or replayable signal; local debug and production paths must reach the same terminal shape.
- retry, wait, and alerting: finite limits and units, only-future waits, expected transient errors, final failure context, and which errors should alert.
- secondary side effects (notifications, telemetry, audit mirrors) handled and logged at their own boundary, so the primary work is not replayed or marked failed only to retry them.
- durable state payload: store stable identifiers and replay-safe facts in steps, queues, or callbacks; keep short-lived authority and sensitive provider data in the runtime owner that can refresh it.
- runtime lifecycle: when a sandbox, worker, or process must survive pause, retry, resume, or replacement, verify the real lifecycle and ownership of any token, filesystem, or session needed after resume; a successful initial launch proves only the mocked boundary.
- runtime limits: a count checked only before submission is not a concurrency guard when submissions can race.

Durable commit point and distinct terminal states: [failure-states](../concerns/failure-states.md). Idempotency and dedupe identity across retry: [data-integrity](../concerns/data-integrity.md). Credential and runtime handoff across the boundary: [boundaries](../concerns/boundaries.md).
