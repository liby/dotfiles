# Boundaries And Ownership

Load when a change crosses or defines an ownership or authority boundary (shared wrapper, gateway, repository, auth layer, route handler, protocol client, runtime, deployment), adds a guard, fallback, or abstraction, or moves data toward a client.

**Authority lives in one owner; everything else routes to it.** Trace ownership and authority through wrappers, services, repositories, routes, generated contracts, protocol clients, runtimes, and deployment boundaries. A prompt, README, cookie, or UI flag can route or display, but it cannot grant authority.

## Guards need an observed caller

Every guard, fallback, compatibility path, cache, switch, dependency, helper, or new abstraction needs an observed caller, input, load shape, or contract that requires it. If absence is impossible, make the type strict or throw at the boundary; if dirty data is real, name the source and test that source. Flag redundant `try`/`catch`, optional `undefined` widening, placeholder returns, magic waits, and abstractions that only rename one caller.

## Persistence and ownership stay with the data owner

When a handler, route, job, resolver, or connector imports the DB client or schema, or mixes persistence with business decisions, ownership checks, or response shaping, push query construction and state transitions back to the repository's data owner. Enforce owner, visibility, soft-delete, and foreign-key constraints inside the service or query owner, not by caller discipline; an unscoped system entrypoint must be a trusted callback, reconciliation, migration, or maintenance path. Reuse the current user, owner, token, or request facts already present in authoritative context, and re-read only when freshness, revocation, authorization, or replay requires it.

## A value that reached the client is already exposed

Filter non-displayable, restricted, or model-only fields before they cross the server-to-client boundary, and verify the raw payload is not reachable through props, network responses, cached state, logs, tool messages, or model-visible output. Client-side hiding, collapsed UI, or redacted rendering is not data isolation once the raw value has crossed; isolation requires server-side filtering, and access requires server-side authorization (see [security](security.md)).

## Credentials and runtimes are constructed lazily, scoped tightly

Scope credential caches and clients to the smallest stable retrieval function and resource owner (process, request, transaction, sandbox, tenant), and verify expiration, refresh invalidation, reconnect or cleanup, and per-resource isolation. Imports and registries must be inert: credentials, network calls, filesystem reads, sandbox launches, and long-lived clients are created lazily at the owner that can scope, memoize, and handle failure, never as a side effect of import.

Boundary-specific detail lives in the surfaces: [agent](../rules/agent.md), [react](../rules/react.md), [next.js](../rules/next.js.md), [async](../rules/async.md).
