# Boundaries And Ownership

Load when a change crosses or defines an ownership or authority boundary (shared wrapper, gateway, repository, auth layer, route handler, protocol client, runtime, deployment), adds a guard, fallback, or abstraction, or moves data toward a client.

**Authority lives in one owner.** Trace the source-owned policy, trusted principal, direct entrypoints, and final mutator. Prompts, documentation, cookies, UI flags, and confirmation dialogs do not grant authority; a higher-level caller closes a headless-path concern only when it owns authorization and the lower layer is not independently exposed.

Before reporting a missing or unnecessary guard, fallback, compatibility path, cache, dependency, helper, or abstraction, identify a current caller, exposed input or adversarial class, load shape, or source-owned contract that makes it behaviorally relevant. Report only a reachable contract, authority, failure-state, or resource consequence.

When persistence and business decisions cross layers, verify that one owner enforces visibility, deletion, foreign-key, and state-transition constraints. Direct DB or schema use is reportable only when it creates a reachable bypass or inconsistent state.

Filter restricted or model-only fields before they cross a server-to-client boundary. Client-side hiding is not isolation when raw values remain reachable through props, responses, caches, logs, tool messages, or model-visible output; authorization and filtering belong at the server boundary.

Report credential or client lifecycle only when authority can cross request, tenant, sandbox, or resource scope, remain usable after expiry, or trigger an external side effect during import.
