# Failure States

Load when changed code handles failure or terminal status: `catch`/`.catch`, ignored exit status, unchecked SDK result, `Promise.allSettled`, retry or timeout config, placeholder returns, `status`/`state`/`outcome` values, or `done`/`healthy`/`configured`/`cached`/`skip` markers.

**Expected absence, business rejection, retryable failure, waiting, logic error, partial work, and success must stay observably distinct.** Collapsing any two into one value or message hides a real outcome behind a plausible one.

## Let errors propagate to the boundary that recovers

Let errors propagate until the boundary that can recover or notify them. Add a guard only after observing the failure mode it covers; a guard that returns `null`, `undefined`, `false`, or `[]` hides the failure. For value-level statuses such as `state`, `status`, and `outcome`, check an explicit success allowlist rather than treating not-error as success.

## A final marker means every durable effect completed

Before a flow records `done`, `success`, `healthy`, `configured`, or any final marker, confirm every required durable write and external side effect has completed. A successful first attempt is not proof of retry behavior, a retryable intermediate state is not a terminal failure, and the final exhausted state must keep enough context for an operator to act.

Queue, retry, and waiter mechanics live in [async](../rules/async.md). Asserting these branches in tests: [tests](tests.md).
