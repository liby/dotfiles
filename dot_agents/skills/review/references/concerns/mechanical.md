# Mechanical Sweep And Completeness

Load for every changed, deleted, or moved line, and whenever a change applies a cross-cutting concept (a user's identity, locale or timezone, a permission, a currency, a feature flag, an audit policy) to one surface.

**Read every changed line for local defects, then ask which peer surfaces the change should have touched but did not.** The missing surface is usually one the diff never names.

## Inspect each changed line

Check for a wrong condition, off-by-one, missing `await`, wrong variable, a truthy check where `0` is valid, a null dereference before its guard, a stale loop variable, an unescaped user pattern, deleted validation, and moved code whose new caller lacks the old preconditions. For a revert or rollback, trace the causal chain from the reverted change back to the behavior it must restore, and confirm no partial state remains.

## Sweep peers by symbol, then by concept

Symbol-local: grep same-class call sites and old inline implementations; for a schema or enum change, inspect writers, readers, deserialization fallback, serialization defaults, and generated output; for a removal, search known consumers outside the touched file. Concept-level: when a change applies a cross-cutting concept to one surface, enumerate the surfaces that should embody it by searching for the concept itself rather than the changed symbol, and include copied, forked, generated, or downstream code and parallel runtimes (sandboxes, workers, cron) whose behavior depends on it but whose source never names it. Report a surface that should embody the concept but does not as a completeness gap to confirm against intent, not a proven bug.
