# Responsibility Checks

Load a section only when the diff changes that responsibility.

## Deferred Or Retried Work

Use for jobs, queues, schedulers, retries, waiters, webhooks, callbacks, background sync, and long-running work.

Deferred work can run zero times, once, many times, late, or out of order. Review idempotency, durable progress, and observable terminal states.

Check:

- durable commit point
- external side effects inside retry-aware or idempotent boundaries
- events that can fire before a waiter starts
- lookback windows, cursors, retry intervals, source delay, and pagination
- success markers after all required durable writes and external effects

## Cross-Boundary UI State

Use for server-rendered UI, client state, cached UI state, streaming output, optimistic updates, and enabled or disabled controls.

UI state often has competing truths: server truth, client truth, network state, and user interaction timing.

Check:

- first paint, pre-hydration interaction, post-hydration interaction, and server response
- source of the value at each step
- interaction gates without hiding correct visible state
- client-visible code importing server-only authority, secrets, or config
- time to first useful response for streaming or progressive UI

## Data Movement And Derived Models

Use for imports, exports, sync jobs, cursor logic, backfills, reports, materialized views, schema tests, and permission grants.

Pipelines split ownership of raw facts, derived facts, and operational permissions. A layer should not own a fact it cannot validate.

Check:

- owner of each key, cursor, and derived field
- create, update, delete, move, replay, and backfill paths
- idempotent reruns with the same input
- permission ownership across application code, data tooling, and infrastructure
- records vs pages vs batches vs transactions before changing yield or write granularity

Flag tests that assert empirically present fields without a contract guarantee. Prefer coverage that proves contract-forbidden values are rejected.

## Model, Tool, And Agent Boundaries

Use for model routing, prompts, tool calls, sandboxed execution, provider wrappers, usage accounting, and protocol clients.

Natural language is not an authority boundary. Model access, tool access, cost, protocol errors, and execution permissions need deterministic code-owned truth.

Check:

- who decides model access, tool access, and execution permissions
- cost where provider usage data is still raw and trustworthy
- prompts with concrete triggers and positive instructions
- no broad "any mention" rules or long negative lists
- model-facing instructions separate from human-facing docs
- sandboxed or model-controlled code cannot read credentials or privileged remotes
- protocol-shaped errors for protocol clients

## Runtime Configuration And Permission Boundaries

Use for auth, route matchers, env vars, public config, service identities, deployment config, analytics or logging sinks, network policy, and infrastructure as code.

Configuration is an authority surface. Wrong config can look like valid behavior once it crosses an environment or permission boundary.

Check:

- each config value from definition to runtime consumer
- public, server-only, secret, environment-specific, or permission-bearing classification
- allow and deny rules with at least one negative case
- functional role instead of service-account name as permission model
- first shared read/write sink and first environment or permission boundary crossed
- telemetry, logs, and analytics cannot merge test, staging, and production facts when that affects decisions

## Review Narrative And Generated Output

Use for large mixed-purpose changes, stale descriptions, rollback claims, generated files, reviewer disagreement, and mechanical churn around semantic edits.

Check:

- current diff against description, discussion, and tests
- each description or discussion requirement maps to a diff change; report missing or partial implementation, and unrequested behavior beyond the description, as separate findings so one axis does not mask the other
- semantic changes separated from renames, formatting, generated output, and unrelated cleanup
- rollback or revert causal chain from reverted change to fixed behavior
- generated source input and regeneration command before hand-reviewing output
- reviewer or delegate agreement verified against cited code before forwarding
